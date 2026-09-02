// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import Darwin
import MachO

/// How far a metric is from "everything's fine" — the shared traffic-light
/// scale every gauge in the Performance tab reports against.
enum LoadRisk: Int, Comparable {
    case ok = 0
    case warning = 1
    case critical = 2

    static func < (lhs: LoadRisk, rhs: LoadRisk) -> Bool { lhs.rawValue < rhs.rawValue }
}

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

    /// Clean, canonical human-readable application name (e.g. groups Chrome helpers into Google Chrome).
    var canonicalAppName: String {
        if let parent = parentAppName { return parent }
        let raw = name
        if raw.contains("Google Chrome") { return "Google Chrome" }
        if raw.contains("Figma") { return "Figma" }
        if raw.contains("Slack") { return "Slack" }
        if raw.contains("Discord") { return "Discord" }
        if raw.contains("Code Helper") { return "Visual Studio Code" }
        if raw.contains("Arc Helper") || raw.contains("Arc") { return "Arc Browser" }
        if raw.contains("Brave") { return "Brave Browser" }
        if raw.contains("Microsoft Edge") { return "Microsoft Edge" }
        if raw.contains("Safari") { return "Safari" }
        return raw
    }

    /// Identifies internal macOS operating system daemons that are normal and shouldn't be blamed.
    var isSystemDaemon: Bool {
        let systemDaemons: Set<String> = [
            "WindowServer", "coreaudiod", "kernel_task", "launchd", "mds", "mds_stores",
            "fseventsd", "diagnosticd", "syspolicyd", "logd", "opendirectoryd", "powerd",
            "diskarbitrationd", "bluetoothd", "airportd", "identityservicesd", "trustd",
            "securityd", "containermanagerd", "taskgated", "runningboardd", "symptomsd",
            "mediaremoted", "ControlCenter", "Dock", "Finder", "SystemUIServer"
        ]
        return systemDaemons.contains(name) || fullCommand.hasPrefix("/System/Library") || fullCommand.hasPrefix("/usr/libexec")
    }

    var isKnownHeavy: Bool { HeavyAppCatalog.matches(fullCommand) }
    var isResourceHeavy: Bool {
        let threshold = max(1_000_000_000, Int64(Double(ProcessInfo.processInfo.physicalMemory) * 0.10))
        return cpuPercent >= 40 || memoryBytes >= threshold
    }
}

/// Curated list of apps known to run sustained CPU/GPU/RAM loads.
enum HeavyAppCatalog {
    private static let patterns: [String] = [
        "docker", "xcode", "android studio", "qemu", "coresimulator",
        "parallels", "vmware fusion", "final cut", "davinci resolve",
        "obs", "zoom.us", "unity", "blender", "adobe premiere",
        "adobe photoshop", "after effects", "handbrake", "logic pro",
        "cinema 4d", "maya", "houdini", "unreal", "electron", "chrome",
        "figma", "slack"
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
        case .nominal: return "Cool"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Throttled"
        @unknown default: return "Unknown"
        }
    }
}

/// Reads live system load: memory, swap, CPU, thermal state, and the
/// heaviest current processes via native Mach kernel calls (0 subprocess overhead).
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
            case ..<0.82: return .ok
            case ..<0.94: return .warning
            default: return .critical
            }
        }

        var cpuRisk: LoadRisk {
            switch cpuPercent {
            case ..<70: return .ok
            case ..<90: return .warning
            default: return .critical
            }
        }

        var swapRisk: LoadRisk {
            let totalRAM = max(Int64(memory.totalBytes), 8_000_000_000)
            let swapRatio = Double(swap.usedBytes) / Double(totalRAM)
            switch swapRatio {
            case ..<0.25: return .ok        // Swap is < 25% of this Mac's RAM (e.g. < 2GB on 8GB Mac, < 4GB on 16GB, < 8GB on 32GB)
            case ..<0.60: return .warning   // Swap is 25%–60% of this Mac's RAM
            default: return .critical       // Swap exceeds 60% of physical RAM
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
            case .some(let value) where value < 75: return .ok
            case .some(let value) where value < 92: return .warning
            default: return .critical
            }
        }

        /// Balanced, non-alarmist system health rating.
        /// Proportional to each Mac's hardware capacity.
        var overallRisk: LoadRisk {
            if thermalRisk == .critical {
                return .critical // True hardware thermal throttling
            }
            if memoryRisk == .critical && swapRisk >= .warning {
                return .critical // Severe physical RAM saturation
            }
            if cpuRisk == .critical && memoryRisk >= .warning {
                return .critical // Dual CPU + RAM saturation
            }
            if memoryRisk == .warning || cpuRisk == .warning || swapRisk >= .warning || gpuRisk == .warning || thermalRisk == .warning {
                return .warning
            }
            return .ok
        }

        var overallStatusLabel: String {
            switch overallRisk {
            case .ok:
                return "Optimal"
            case .warning:
                return "Busy"
            case .critical:
                return thermalRisk == .critical ? "Throttled" : "Heavy Load"
            }
        }

        var heavyAppsRunning: [ProcessStats] {
            topProcesses.filter(\.isKnownHeavy)
        }

        var heaviestProcess: ProcessStats? {
            topProcesses.first { !$0.isSystemDaemon } ?? topProcesses.max { $0.cpuPercent < $1.cpuPercent }
        }

        var heaviestByMemory: ProcessStats? {
            topProcessesByMemory.first { !$0.isSystemDaemon } ?? topProcesses.max { $0.memoryBytes < $1.memoryBytes }
        }

        var notableMemoryThreshold: Int64 {
            max(500_000_000, Int64(Double(memory.totalBytes) * 0.08)) // 8% of this Mac's RAM or 500MB
        }

        var memoryAdvice: String? {
            guard memoryRisk >= .warning else { return nil }
            if let heaviest = heaviestByMemory, heaviest.memoryBytes >= notableMemoryThreshold {
                return "\(heaviest.canonicalAppName) is using \(ByteFormat.string(heaviest.memoryBytes)) RAM. Quitting unused apps will free up physical memory."
            }
            return "Close unused applications or heavy browser tabs to relieve memory pressure."
        }

        var cpuAdvice: String? {
            guard cpuRisk >= .warning else { return nil }
            if let heaviest = heaviestProcess, heaviest.cpuPercent >= 20 {
                return "\(heaviest.canonicalAppName) is taking \(Int(heaviest.cpuPercent))% CPU load. Normal during intensive tasks."
            }
            return "Elevated CPU activity detected from active background tasks."
        }

        var swapAdvice: String? {
            guard swapRisk >= .warning else { return nil }
            let nonSystemHeavy = heavyAppsRunning.filter { !$0.isSystemDaemon }
            let heavyNames = Array(Set(nonSystemHeavy.map(\.canonicalAppName))).sorted()
            if !heavyNames.isEmpty {
                if heavyNames.count == 1 {
                    return "macOS is paging \(ByteFormat.string(swap.usedBytes)) inactive data to SSD. Your Mac is safe. Closing \(heavyNames[0]) will free up physical RAM."
                } else {
                    return "macOS is paging \(ByteFormat.string(swap.usedBytes)) inactive data to SSD. Your Mac is safe. Closing \(heavyNames.joined(separator: ", ")) will free up physical RAM."
                }
            }
            if let heaviest = heaviestByMemory, !heaviest.isSystemDaemon, heaviest.memoryBytes >= notableMemoryThreshold {
                return "macOS is paging \(ByteFormat.string(swap.usedBytes)) to SSD. Quitting \(heaviest.canonicalAppName) (\(ByteFormat.string(heaviest.memoryBytes))) will free up physical RAM."
            }
            return "macOS is paging inactive data to SSD. Close inactive apps if you experience responsiveness lag."
        }

        var gpuAdvice: String? {
            guard gpuRisk >= .warning else { return nil }
            return "GPU accelerator is active with graphics, video, or rendering workloads."
        }

        var thermalAdvice: String? {
            guard thermalRisk >= .warning else { return nil }
            let modelID = PerformanceMonitor.sysctlString("hw.model")
            let isFanless = modelID.lowercased().contains("macbookair")

            switch thermalState {
            case .critical:
                if isFanless {
                    return "Thermal regulation active. Fanless MacBook Air automatically throttles clock speeds to keep chassis temperatures safe."
                } else {
                    return "Thermal throttling active. Cooling fans are at maximum; ensure table airflow and air vents are unobstructed."
                }
            default:
                if isFanless {
                    return "Elevated chassis temperature under heavy load. Expected and safe on fanless Mac laptops."
                } else {
                    return "Elevated system temperature under active workload. Cooling fans are actively managing heat dissipation."
                }
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

    private static var previousCPUTicks: (user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32)?

    /// Captures a live snapshot using Mach kernel APIs and a single-pass process inspection.
    static func capture(processLimit: Int = 25) -> Snapshot {
        let allProcesses = fetchAllProcesses()
        let byCPU = Array(allProcesses.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(processLimit))
        let byMem = Array(allProcesses.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(processLimit))

        return Snapshot(
            memory: memorySnapshot(),
            swap: swapSnapshot(),
            cpuPercent: systemCPUPercent(),
            gpuPercent: systemGPUPercent(),
            thermalState: ProcessInfo.processInfo.thermalState,
            topProcesses: byCPU,
            topProcessesByMemory: byMem
        )
    }

    static func terminateProcess(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        let result = kill(pid, SIGTERM)
        return result == 0
    }

    // MARK: - Native Mach Kernel Telemetry (0 Subprocess Overhead)

    /// Reads Memory usage directly from Mach kernel `host_statistics64` (HOST_VM_INFO64).
    private static func memorySnapshot() -> MemorySnapshot {
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return MemorySnapshot(totalBytes: total, usedBytes: 0)
        }

        let pageSize = Int64(vm_kernel_page_size)
        let active = Int64(vmStats.active_count)
        let wired = Int64(vmStats.wire_count)
        let compressorOccupied = Int64(vmStats.compressor_page_count)
        let used = (active + wired + compressorOccupied) * pageSize

        return MemorySnapshot(totalBytes: total, usedBytes: min(used, total))
    }

    /// Reads string properties via C `sysctlbyname`.
    static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    /// Reads Swap usage directly via C `sysctlbyname("vm.swapusage")`.
    private static func swapSnapshot() -> SwapSnapshot {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        guard result == 0 else {
            return SwapSnapshot(totalBytes: 0, usedBytes: 0)
        }
        return SwapSnapshot(totalBytes: Int64(swap.xsu_total), usedBytes: Int64(swap.xsu_used))
    }

    /// Reads CPU load directly from Mach kernel `host_statistics` (HOST_CPU_LOAD_INFO).
    private static func systemCPUPercent() -> Double {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }

        let user = cpuLoadInfo.cpu_ticks.0
        let sys = cpuLoadInfo.cpu_ticks.1
        let idle = cpuLoadInfo.cpu_ticks.2
        let nice = cpuLoadInfo.cpu_ticks.3

        defer {
            previousCPUTicks = (user, sys, idle, nice)
        }

        guard let prev = previousCPUTicks else {
            return 0
        }

        let userDiff = Double(user.subtractingReportingOverflow(prev.user).partialValue)
        let sysDiff = Double(sys.subtractingReportingOverflow(prev.sys).partialValue)
        let idleDiff = Double(idle.subtractingReportingOverflow(prev.idle).partialValue)
        let niceDiff = Double(nice.subtractingReportingOverflow(prev.nice).partialValue)

        let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }

        let activeDiff = userDiff + sysDiff + niceDiff
        return min(max((activeDiff / totalDiff) * 100.0, 0), 100.0)
    }

    /// Single-pass process list fetch via `ps` (only 1 lightweight process execution per tick).
    private static func fetchAllProcesses() -> [ProcessStats] {
        let output = Shell.run("/bin/ps", ["-Aro", "pid=,pcpu=,rss=,comm="])
        var results: [ProcessStats] = []

        for line in output.split(separator: "\n").prefix(35) {
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4,
                  let pid = Int32(fields[0]),
                  let cpu = Double(fields[1]),
                  let rssKB = Int64(fields[2]) else { continue }
            results.append(
                ProcessStats(
                    pid: pid,
                    fullCommand: String(fields[3]),
                    cpuPercent: cpu,
                    memoryBytes: rssKB * 1024
                )
            )
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
