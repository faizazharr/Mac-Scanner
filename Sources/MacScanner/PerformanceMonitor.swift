// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// How far a metric is from "everything's fine" — the shared traffic-light
/// scale every gauge in the Performance tab reports against.
enum LoadRisk: Int, Comparable {
    case ok = 0
    case warning = 1
    case critical = 2

    static func < (lhs: LoadRisk, rhs: LoadRisk) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Which order the Top Processes list is ranked in.
enum ProcessSortMode: String, CaseIterable {
    case cpu = "CPU"
    case memory = "RAM"
}

/// A single running process, as reported by `ps`.
struct ProcessStats: Identifiable {
    let id = UUID()
    let pid: Int32
    /// Full executable path, e.g. `/Applications/Docker.app/Contents/MacOS/Docker`.
    let fullCommand: String
    let cpuPercent: Double
    let memoryBytes: Int64

    /// Last path component without extension — what a human calls this process.
    var name: String {
        URL(fileURLWithPath: fullCommand).deletingPathExtension().lastPathComponent
    }

    /// The `.app` bundle this process actually belongs to, if any.
    var parentAppName: String? {
        let components = fullCommand.split(separator: "/")
        guard let appComponent = components.first(where: { $0.hasSuffix(".app") }) else { return nil }
        let ownName = URL(fileURLWithPath: fullCommand).deletingPathExtension().lastPathComponent
        let appName = String(appComponent.dropLast(4))
        return appName == ownName ? nil : appName
    }

    var isKnownHeavy: Bool { HeavyAppCatalog.matches(fullCommand) }
    var isResourceHeavy: Bool { cpuPercent >= 40 || memoryBytes >= 1_500_000_000 }
}

/// Curated list of apps known to run sustained CPU/GPU/RAM loads.
enum HeavyAppCatalog {
    private static let patterns: [String] = [
        "docker", "xcode", "android studio", "qemu", "coresimulator",
        "parallels", "vmware fusion", "final cut", "davinci resolve",
        "obs", "zoom.us", "unity", "blender", "adobe premiere",
        "adobe photoshop", "after effects", "handbrake", "logic pro",
        "cinema 4d", "maya", "houdini", "unreal", "electron", "chrome"
    ]

    static func matches(_ command: String) -> Bool {
        let lower = command.lowercased()
        return patterns.contains { lower.contains($0) }
    }
}

/// One row of the Performance tab's stable Recommendations section.
struct PerformanceRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let risk: LoadRisk
    let statusLabel: String
    let advice: String
}

/// Data point for live historical sparkline charts.
struct PerformanceHistoryPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuPercent: Double
    let memoryPercent: Double
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "Nominal (Cool)"
        case .fair: return "Fair (Warm)"
        case .serious: return "Serious (Hot)"
        case .critical: return "Critical (Throttled)"
        @unknown default: return "Unknown"
        }
    }
}

/// Reads live system load: memory, swap, CPU, thermal state, and the
/// heaviest current processes.
enum PerformanceMonitor {

    struct MemorySnapshot {
        let totalBytes: Int64
        let usedBytes: Int64
        var freeBytes: Int64 { max(0, totalBytes - usedBytes) }
        var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    }

    struct SwapSnapshot {
        let totalBytes: Int64
        let usedBytes: Int64
    }

    struct Snapshot {
        let memory: MemorySnapshot
        let swap: SwapSnapshot
        let cpuPercent: Double
        let gpuPercent: Double?
        let thermalState: ProcessInfo.ThermalState
        let topProcesses: [ProcessStats]
        let topProcessesByMemory: [ProcessStats]

        var memoryRisk: LoadRisk {
            switch memory.usedFraction {
            case ..<0.75: return .ok
            case ..<0.90: return .warning
            default: return .critical
            }
        }

        var cpuRisk: LoadRisk {
            switch cpuPercent {
            case ..<60: return .ok
            case ..<85: return .warning
            default: return .critical
            }
        }

        var swapRisk: LoadRisk {
            switch swap.usedBytes {
            case ..<1_000_000_000: return .ok        // < 1 GB
            case ..<4_000_000_000: return .warning    // 1–4 GB
            default: return .critical                  // 4 GB+
            }
        }

        var thermalRisk: LoadRisk {
            switch thermalState {
            case .nominal, .fair: return .ok
            case .serious: return .warning
            case .critical: return .critical
            @unknown default: return .ok
            }
        }

        var gpuRisk: LoadRisk {
            switch gpuPercent {
            case nil: return .ok
            case .some(let value) where value < 70: return .ok
            case .some(let value) where value < 90: return .warning
            default: return .critical
            }
        }

        var overallRisk: LoadRisk {
            max(max(memoryRisk, cpuRisk), max(swapRisk, max(thermalRisk, gpuRisk)))
        }

        var heavyAppsRunning: [ProcessStats] {
            topProcesses.filter(\.isKnownHeavy)
        }

        var heaviestProcess: ProcessStats? {
            topProcesses.max { $0.cpuPercent < $1.cpuPercent }
        }

        var heaviestByMemory: ProcessStats? {
            topProcesses.max { $0.memoryBytes < $1.memoryBytes }
        }

        private static let notableMemoryThreshold: Int64 = 500_000_000 // 500 MB

        var memoryAdvice: String? {
            guard memoryRisk >= .warning else { return nil }
            if let heaviest = heaviestByMemory, heaviest.memoryBytes >= Self.notableMemoryThreshold {
                return "\(heaviest.name) is consuming \(ByteFormat.string(heaviest.memoryBytes)) RAM. Quit it if not in use."
            }
            return "Close unused applications or heavy browser tabs to relieve memory pressure."
        }

        var cpuAdvice: String? {
            guard cpuRisk >= .warning else { return nil }
            if let heaviest = heaviestProcess, heaviest.cpuPercent >= 20 {
                return "\(heaviest.name) is taking \(Int(heaviest.cpuPercent))% CPU load. Consider quitting or pausing its work."
            }
            return "High CPU utilization detected. Check Top Processes below to inspect heavy tasks."
        }

        var swapAdvice: String? {
            guard swapRisk >= .warning else { return nil }
            let heavyNames = Set(heavyAppsRunning.map(\.name)).sorted()
            if !heavyNames.isEmpty {
                return "Mac is swapping to disk. Closing \(heavyNames.joined(separator: ", ")) will help restore peak speed."
            }
            if let heaviest = heaviestByMemory, heaviest.memoryBytes >= Self.notableMemoryThreshold {
                return "Mac is swapping to disk. Quitting \(heaviest.name) (\(ByteFormat.string(heaviest.memoryBytes))) will free up physical memory."
            }
            return "Swap file under pressure. Close inactive apps to prevent disk I/O thrashing."
        }

        var gpuAdvice: String? {
            guard gpuRisk >= .warning else { return nil }
            return "GPU accelerator is busy. High load from rendering, video export, or graphics-heavy apps."
        }

        var thermalAdvice: String? {
            guard thermalRisk >= .warning else { return nil }
            switch thermalState {
            case .critical:
                return "Thermal throttling active. Let your Mac cool down and check that fan vents are unobstructed."
            default:
                return "Elevated system temperature. Avoid launching new heavy jobs until temperature stabilizes."
            }
        }

        var recommendations: [PerformanceRecommendation] {
            var list = [
                PerformanceRecommendation(
                    title: "Memory", icon: "memorychip", risk: memoryRisk,
                    statusLabel: "\(Int(memory.usedFraction * 100))% used",
                    advice: memoryAdvice ?? "RAM usage is optimal — zero pressure."
                ),
                PerformanceRecommendation(
                    title: "CPU", icon: "cpu", risk: cpuRisk,
                    statusLabel: "\(Int(cpuPercent))% busy",
                    advice: cpuAdvice ?? "CPU load is optimal — responsive."
                )
            ]
            if let gpuPercent {
                list.append(PerformanceRecommendation(
                    title: "GPU", icon: "gearshape.2", risk: gpuRisk,
                    statusLabel: "\(Int(gpuPercent))% busy",
                    advice: gpuAdvice ?? "GPU accelerator load is normal."
                ))
            }
            list.append(PerformanceRecommendation(
                title: "Swap", icon: "arrow.left.arrow.right", risk: swapRisk,
                statusLabel: "\(ByteFormat.string(swap.usedBytes)) used",
                advice: swapAdvice ?? "No disk swap pressure."
            ))
            list.append(PerformanceRecommendation(
                title: "Thermal", icon: "thermometer.medium", risk: thermalRisk,
                statusLabel: thermalState.label,
                advice: thermalAdvice ?? "Temperature is cool and comfortable."
            ))
            return list
        }
    }

    /// Takes a snapshot. Each metric is its own subprocess spawn (`vm_stat`,
    /// `sysctl`, `top`, `ioreg`, `ps`), and they're independent of each
    /// other, so they run concurrently rather than one after another — on a
    /// 3-second polling loop, serializing 5-6 process spawns adds up to a
    /// real, measurable CPU cost for no benefit.
    ///
    /// `includeMemorySortedProcesses` gates the second, separate `ps` scan
    /// (sorted by RSS) — it's a full process-table walk just like the CPU
    /// one, so it's only worth paying for while the user is actually
    /// looking at the RAM-sorted list. Otherwise `topProcessesByMemory` is
    /// derived for free by re-sorting the CPU-ranked list already fetched
    /// (an approximation outside the top-CPU set, but that's fine since it
    /// isn't shown until the user switches to it, at which point the next
    /// tick fetches the real thing).
    static func capture(processLimit: Int = 16, includeMemorySortedProcesses: Bool = false) -> Snapshot {
        var memory = MemorySnapshot(totalBytes: totalPhysicalMemory(), usedBytes: 0)
        var swap = SwapSnapshot(totalBytes: 0, usedBytes: 0)
        var cpuPercent: Double = 0
        var gpuPercent: Double?
        var byCPU: [ProcessStats] = []
        var byMemory: [ProcessStats]?

        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        group.enter(); queue.async { memory = memorySnapshot(); group.leave() }
        group.enter(); queue.async { swap = swapSnapshot(); group.leave() }
        group.enter(); queue.async { cpuPercent = systemCPUPercent(); group.leave() }
        group.enter(); queue.async { gpuPercent = systemGPUPercent(); group.leave() }
        group.enter(); queue.async { byCPU = processes(sortFlag: "-r", limit: processLimit); group.leave() }
        if includeMemorySortedProcesses {
            group.enter(); queue.async { byMemory = processes(sortFlag: "-m", limit: processLimit); group.leave() }
        }
        group.wait()

        return Snapshot(
            memory: memory,
            swap: swap,
            cpuPercent: cpuPercent,
            gpuPercent: gpuPercent,
            thermalState: ProcessInfo.processInfo.thermalState,
            topProcesses: byCPU,
            topProcessesByMemory: byMemory ?? byCPU.sorted { $0.memoryBytes > $1.memoryBytes }
        )
    }

    static func terminateProcess(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        let result = kill(pid, SIGTERM)
        return result == 0
    }

    // MARK: - Private

    private static func totalPhysicalMemory() -> Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    private static func memorySnapshot() -> MemorySnapshot {
        let total = totalPhysicalMemory()
        let output = Shell.run("/usr/bin/vm_stat")

        var pageSize: Int64 = 16384
        if let match = output.range(of: #"page size of (\d+) bytes"#, options: .regularExpression) {
            let digits = output[match].filter(\.isNumber)
            pageSize = Int64(digits) ?? pageSize
        }

        var pages: [String: Int64] = [:]
        for line in output.split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let label = line[line.startIndex..<colon]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let digits = line[line.index(after: colon)...].filter(\.isNumber)
            pages[label] = Int64(digits)
        }

        let active = pages["pages active"] ?? 0
        let wired = pages["pages wired down"] ?? 0
        let compressorOccupied = pages["pages occupied by compressor"] ?? 0
        let used = (active + wired + compressorOccupied) * pageSize

        return MemorySnapshot(totalBytes: total, usedBytes: used)
    }

    private static func swapSnapshot() -> SwapSnapshot {
        let output = Shell.run("/usr/sbin/sysctl", ["vm.swapusage"])

        func bytes(after key: String) -> Int64 {
            guard let range = output.range(of: "\(key) = ") else { return 0 }
            let rest = output[range.upperBound...]
            let token = rest.prefix { !$0.isWhitespace }
            return parseSize(String(token))
        }

        return SwapSnapshot(totalBytes: bytes(after: "total"), usedBytes: bytes(after: "used"))
    }

    private static func parseSize(_ token: String) -> Int64 {
        guard let unit = token.last, unit.isLetter else { return 0 }
        let numberPart = token.dropLast()
        guard let value = Double(numberPart) else { return 0 }
        let multiplier: Double
        switch unit {
        case "K": multiplier = 1_024
        case "M": multiplier = 1_024 * 1_024
        case "G": multiplier = 1_024 * 1_024 * 1_024
        default: multiplier = 1
        }
        return Int64(value * multiplier)
    }

    private static func systemCPUPercent() -> Double {
        let output = Shell.run("/usr/bin/top", ["-l", "1", "-n", "0"])
        guard let line = output.split(separator: "\n").first(where: { $0.contains("CPU usage") }) else {
            return 0
        }
        let numbers = line
            .split(separator: " ")
            .compactMap { token -> Double? in
                guard token.hasSuffix("%") else { return nil }
                return Double(token.dropLast())
            }
        return numbers.dropLast().reduce(0, +)
    }

    private static func processes(sortFlag: String, limit: Int) -> [ProcessStats] {
        let output = Shell.run("/bin/ps", ["-Ao", "pid=,pcpu=,rss=,comm=", sortFlag])
        var results: [ProcessStats] = []

        for line in output.split(separator: "\n").prefix(limit) {
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let rssKB = Int64(fields[2]) else { continue }
            results.append(ProcessStats(pid: pid, fullCommand: String(fields[3]), cpuPercent: cpu, memoryBytes: rssKB * 1024))
        }
        return results
    }

    private static func systemGPUPercent() -> Double? {
        let output = Shell.run("/usr/sbin/ioreg", ["-r", "-c", "IOAccelerator", "-d", "1"])
        guard let match = output.range(of: #""Device Utilization %"=(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let digits = output[match].filter(\.isNumber)
        return digits.isEmpty ? nil : Double(digits)
    }
}
