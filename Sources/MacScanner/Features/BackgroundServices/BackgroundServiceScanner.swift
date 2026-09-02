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

        var plistMap: [String: (url: URL, type: ServiceType, isThirdParty: Bool)] = [:]
        collectPlists(from: agentDirs,       type: .launchAgent,  isThirdParty: true,  into: &plistMap)
        collectPlists(from: daemonDirs,      type: .launchDaemon, isThirdParty: true,  into: &plistMap)
        collectPlists(from: systemDaemonDirs, type: .system,      isThirdParty: false, into: &plistMap)

        var results: [BackgroundService] = []

        for entry in launchctlEntries {
            let pidOpt = entry.pid
            let plistInfo = plistMap[entry.label]
            let processStats = pidOpt.flatMap { processMap[$0] }

            let status: ServiceStatus
            if let pid = pidOpt, pid > 0 {
                status = .running(pid: pid)
            } else if entry.label.contains("demand") {
                status = .onDemand
            } else {
                status = .idle
            }

            let type_: ServiceType = plistInfo?.type ?? (entry.label.hasPrefix("com.apple") ? .system : .launchAgent)
            let isThirdParty = plistInfo?.isThirdParty ?? !entry.label.hasPrefix("com.apple")

            results.append(BackgroundService(
                id: UUID(),
                label: entry.label,
                displayName: friendlyName(for: entry.label),
                ownerApp: ownerApp(for: entry.label),
                type: type_,
                status: status,
                cpuPercent: processStats?.cpu ?? 0,
                memoryBytes: processStats?.memBytes ?? 0,
                plistURL: plistInfo?.url,
                isThirdParty: isThirdParty
            ))
        }

        return results.sorted { $0.cpuPercent > $1.cpuPercent }
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
        into map: inout [String: (url: URL, type: ServiceType, isThirdParty: Bool)]
    ) {
        let fm = FileManager.default
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where url.pathExtension == "plist" {
                let label = url.deletingPathExtension().lastPathComponent
                map[label] = (url, type, isThirdParty)
            }
        }
    }

    // MARK: - Friendly Name Derivation

    private static func friendlyName(for label: String) -> String {
        let knownNames: [String: String] = [
            "com.apple.coreduetd": "Core Duet Daemon",
            "com.apple.coreanalyticsd": "Core Analytics",
            "com.apple.softwareupdated": "Software Update Daemon",
            "com.apple.backgroundtaskmanagementagent": "Background Task Agent",
            "com.apple.mdworker_shared": "Spotlight Worker",
            "com.apple.mds": "Spotlight Indexer",
            "com.apple.trustd": "Trust Policy Daemon",
            "com.apple.logd": "Log Daemon",
            "com.apple.WindowServer": "Window Server",
            "com.apple.UserEventAgent": "User Event Agent",
            "com.adobe.adobeupdatedaemon": "Adobe Update Daemon",
            "com.adobe.GC.AGM": "Adobe Creative Cloud AGM",
            "com.docker.dockerd": "Docker Engine",
            "com.spotify.webhelper": "Spotify Web Helper",
            "com.google.keystone.agent": "Google Update Agent",
            "com.microsoft.autoupdate.helper": "Microsoft AutoUpdate",
            "com.jetbrains.toolbox.shims": "JetBrains Toolbox",
            "com.dropbox.client": "Dropbox",
            "com.figma.agent": "Figma Agent",
        ]

        if let known = knownNames[label] { return known }

        // Derive from last component: com.adobe.adobeupdatedaemon → Adobeupdatedaemon
        let parts = label.split(separator: ".")
        if let last = parts.last {
            return last.split(separator: "-")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }

        return label
    }

    private static func ownerApp(for label: String) -> String? {
        let ownerMap: [String: String] = [
            "com.adobe":           "Adobe Creative Cloud",
            "com.docker":          "Docker Desktop",
            "com.spotify":         "Spotify",
            "com.google.keystone": "Google Software Updater",
            "com.microsoft":       "Microsoft Office",
            "com.jetbrains":       "JetBrains Toolbox",
            "com.dropbox":         "Dropbox",
            "com.figma":           "Figma",
        ]

        for (prefix, app) in ownerMap {
            if label.hasPrefix(prefix) { return app }
        }
        if label.hasPrefix("com.apple") { return nil }
        return nil
    }
}
