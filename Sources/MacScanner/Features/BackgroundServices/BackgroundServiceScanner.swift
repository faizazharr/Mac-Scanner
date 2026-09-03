// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AppKit

/// Type classification for a background service entry.
enum ServiceType: String {
    case launchAgent  = "Agent"
    case launchDaemon = "Daemon"
    case xpcService   = "XPC"
    case system       = "System"
}

/// Runtime status of a background service.
enum ServiceStatus: Equatable {
    case running(pid: Int32)
    case idle
    case onDemand

    var label: String {
        switch self {
        case .running(let pid): return "Running  ·  PID \(pid)"
        case .idle:             return "Idle"
        case .onDemand:         return "On-Demand"
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// A single background service entry with resource telemetry.
struct BackgroundService: Identifiable, Equatable {
    let id: UUID
    let label: String          // e.g. com.adobe.adobeupdatedaemon
    let displayName: String    // e.g. Adobe Update Daemon
    let ownerApp: String?      // e.g. Adobe Creative Cloud
    let ownerIcon: NSImage?    // Icon pulled from the owning .app bundle
    let type: ServiceType
    let status: ServiceStatus
    let cpuPercent: Double
    let memoryBytes: Int64
    let plistURL: URL?
    let isThirdParty: Bool

    var risk: LoadRisk {
        if cpuPercent >= 30 || memoryBytes >= 500_000_000 { return .critical }
        if cpuPercent >= 10 || memoryBytes >= 150_000_000 { return .warning }
        return .ok
    }

    static func == (lhs: BackgroundService, rhs: BackgroundService) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.cpuPercent == rhs.cpuPercent &&
        lhs.memoryBytes == rhs.memoryBytes
    }
}

/// High-performance scanner that combines launchctl, ps, and plist folder inspection
/// to produce a unified list of all background services running on the system.
///
/// Owner app names and display names are resolved **dynamically** from:
///   1. `ProgramArguments`/`Program` in the service plist → .app bundle → Info.plist
///   2. `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` via bundle ID prefix
///   3. Derivation from the service label string itself (no hardcoded names)
enum BackgroundServiceScanner {

    // MARK: - Plist Directories

    private static let agentDirs: [URL] = [
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
        URL(fileURLWithPath: "/Library/LaunchAgents")
    ]

    private static let daemonDirs: [URL] = [
        URL(fileURLWithPath: "/Library/LaunchDaemons")
    ]

    private static let systemDaemonDirs: [URL] = [
        URL(fileURLWithPath: "/System/Library/LaunchDaemons"),
        URL(fileURLWithPath: "/System/Library/LaunchAgents")
    ]

    // MARK: - Public API

    /// Performs a full scan and returns sorted BackgroundService list.
    static func scan() -> [BackgroundService] {
        let launchctlEntries = parseLaunchctlList()
        let processMap = buildProcessMap()

        // plistMap: label → (url, type, isThirdParty, plistDict)
        var plistMap: [String: PlistInfo] = [:]
        collectPlists(from: agentDirs,        type: .launchAgent,  isThirdParty: true,  into: &plistMap)
        collectPlists(from: daemonDirs,       type: .launchDaemon, isThirdParty: true,  into: &plistMap)
        collectPlists(from: systemDaemonDirs, type: .system,       isThirdParty: false, into: &plistMap)

        var results: [BackgroundService] = []

        for entry in launchctlEntries {
            let pidOpt = entry.pid
            let info = plistMap[entry.label]
            let processStats = pidOpt.flatMap { processMap[$0] }

            let status: ServiceStatus
            if let pid = pidOpt, pid > 0 {
                status = .running(pid: pid)
            } else if entry.label.lowercased().contains("demand") {
                status = .onDemand
            } else {
                status = .idle
            }

            let type_: ServiceType = info?.type ?? (entry.label.hasPrefix("com.apple") ? .system : .launchAgent)
            let isThirdParty = info?.isThirdParty ?? !entry.label.hasPrefix("com.apple")

            // Dynamic owner resolution — no hardcoded names
            let resolved = resolveOwner(for: entry.label, plistInfo: info)

            results.append(BackgroundService(
                id: UUID(),
                label: entry.label,
                displayName: resolved.displayName,
                ownerApp: resolved.ownerApp,
                ownerIcon: resolved.icon,
                type: type_,
                status: status,
                cpuPercent: processStats?.cpu ?? 0,
                memoryBytes: processStats?.memBytes ?? 0,
                plistURL: info?.url,
                isThirdParty: isThirdParty
            ))
        }

        return results.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    // MARK: - Plist Info

    private struct PlistInfo {
        let url: URL
        let type: ServiceType
        let isThirdParty: Bool
        let dict: [String: Any]
    }

    // MARK: - launchctl list Parser

    private struct LaunchctlEntry {
        let pid: Int32?
        let status: Int?
        let label: String
    }

    private static func parseLaunchctlList() -> [LaunchctlEntry] {
        let output = Shell.runNiced("/bin/launchctl", ["list"], niceLevel: 5)
        var entries: [LaunchctlEntry] = []

        for line in output.split(separator: "\n").dropFirst() {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3 else { continue }
            let label = String(fields[2]).trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty, !label.hasPrefix("-") else { continue }
            let pid = Int32(fields[0].trimmingCharacters(in: .whitespaces))
            let status = Int(fields[1].trimmingCharacters(in: .whitespaces))
            entries.append(LaunchctlEntry(pid: pid, status: status, label: label))
        }

        return entries
    }

    // MARK: - Process Map (PID → CPU/RAM)

    private struct ProcessTelemetry {
        let cpu: Double
        let memBytes: Int64
    }

    private static func buildProcessMap() -> [Int32: ProcessTelemetry] {
        let output = Shell.run("/bin/ps", ["-Aro", "pid=,pcpu=,rss="])
        var map: [Int32: ProcessTelemetry] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rss = Int64(parts[2]) else { continue }
            map[pid] = ProcessTelemetry(cpu: cpu, memBytes: rss * 1024)
        }

        return map
    }

    // MARK: - Plist Folder Scanner

    private static func collectPlists(
        from dirs: [URL],
        type: ServiceType,
        isThirdParty: Bool,
        into map: inout [String: PlistInfo]
    ) {
        let fm = FileManager.default
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where url.pathExtension == "plist" {
                let label = url.deletingPathExtension().lastPathComponent
                let dict = (NSDictionary(contentsOf: url) as? [String: Any]) ?? [:]
                map[label] = PlistInfo(url: url, type: type, isThirdParty: isThirdParty, dict: dict)
            }
        }
    }

    // MARK: - Dynamic Owner Resolution

    private struct ResolvedOwner {
        let displayName: String
        let ownerApp: String?
        let icon: NSImage?
    }

    /// Resolves the display name and owning application for a service **without any hardcoded names**.
    ///
    /// Resolution order:
    /// 1. Parse `Program` / `ProgramArguments[0]` from the plist → walk up the path
    ///    tree to find an `.app` bundle → read `CFBundleDisplayName` / `CFBundleName`
    ///    and the app icon from the bundle's `Info.plist`.
    /// 2. Try `NSWorkspace.urlForApplication(withBundleIdentifier:)` using the service
    ///    label as a bundle identifier (works when the label == the app's bundle ID).
    /// 3. Derive a human-readable name from the service label itself by splitting on
    ///    dots and capitalising each component word (pure string transform, no lookup table).
    private static func resolveOwner(for label: String, plistInfo: PlistInfo?) -> ResolvedOwner {

        // ── Strategy 1: extract executable path from plist ──────────────────
        if let dict = plistInfo?.dict {
            let execPath: String? = {
                if let prog = dict["Program"] as? String { return prog }
                if let args = dict["ProgramArguments"] as? [String], let first = args.first { return first }
                return nil
            }()

            if let execPath, let appBundle = appBundle(containingExecutable: URL(fileURLWithPath: execPath)) {
                let name = bundleDisplayName(at: appBundle)
                let icon = bundleHasCustomIcon(at: appBundle) ? AppIconCache.shared.icon(for: appBundle.path) : nil
                return ResolvedOwner(
                    displayName: serviceDisplayName(from: label),
                    ownerApp: name,
                    icon: icon
                )
            }
        }

        // ── Strategy 2: label as bundle ID → NSWorkspace lookup ─────────────
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: label) {
            let name = bundleDisplayName(at: appURL)
            let icon = bundleHasCustomIcon(at: appURL) ? AppIconCache.shared.icon(for: appURL.path) : nil
            return ResolvedOwner(displayName: serviceDisplayName(from: label), ownerApp: name, icon: icon)
        }

        // Try trimming last component: com.apple.mdworker_shared → com.apple.mdworker
        let parentID = label.components(separatedBy: ".").dropLast().joined(separator: ".")
        if parentID.count > 4,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: parentID) {
            let name = bundleDisplayName(at: appURL)
            let icon = bundleHasCustomIcon(at: appURL) ? AppIconCache.shared.icon(for: appURL.path) : nil
            return ResolvedOwner(displayName: serviceDisplayName(from: label), ownerApp: name, icon: icon)
        }

        // ── Strategy 3: pure string derivation ──────────────────────────────
        return ResolvedOwner(
            displayName: serviceDisplayName(from: label),
            ownerApp: nil,
            icon: nil
        )
    }

    /// Walks up the directory tree from `executableURL` to find the nearest `.app` bundle.
    private static func appBundle(containingExecutable url: URL) -> URL? {
        var current = url.deletingLastPathComponent()
        for _ in 0..<8 {
            if current.pathExtension == "app" { return current }
            let parent = current.deletingLastPathComponent()
            if parent == current { break }
            current = parent
        }
        return nil
    }

    /// Many system-owned helper bundles (WindowManager.app, NotificationCenter.app,
    /// etc.) have no `CFBundleIconFile`/`CFBundleIconName` at all. `NSWorkspace.icon(forFile:)`
    /// still returns *something* for them — macOS's generic blank-document icon — which
    /// rendered as an empty white box in the row instead of the intended gearshape
    /// fallback. Checking for a declared icon key first lets those cases fall through
    /// to `icon: nil` so the row's existing fallback kicks in consistently.
    private static func bundleHasCustomIcon(at bundleURL: URL) -> Bool {
        let infoPlist = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] else { return false }
        if let file = dict["CFBundleIconFile"] as? String, !file.isEmpty { return true }
        if let name = dict["CFBundleIconName"] as? String, !name.isEmpty { return true }
        return false
    }

    /// Reads `CFBundleDisplayName` → `CFBundleName` → last path component from a bundle URL.
    private static func bundleDisplayName(at url: URL) -> String {
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] {
            if let name = dict["CFBundleDisplayName"] as? String, !name.isEmpty { return name }
            if let name = dict["CFBundleName"] as? String, !name.isEmpty { return name }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Derives a human-readable service display name from its reverse-DNS label.
    ///
    /// Examples:
    ///   `com.apple.coreanalyticsd`  →  "Coreanalyticsd"
    ///   `com.docker.dockerd`        →  "Dockerd"
    ///   `com.spotify.webhelper`     →  "Web Helper"
    private static func serviceDisplayName(from label: String) -> String {
        guard let lastPart = label.split(separator: ".").last.map(String.init) else { return label }
        // Split on hyphens/underscores, capitalise each word
        let words = lastPart
            .components(separatedBy: .init(charactersIn: "-_"))
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.joined(separator: " ")
    }
}
