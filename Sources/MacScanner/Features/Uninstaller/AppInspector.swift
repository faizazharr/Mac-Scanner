// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Detailed anatomical breakdown of an application's resource consumption:
/// separating tab/worker renderers, GPU processes, extensions, and disk caches.
struct AppInspectionDetail: Identifiable {
    let id = UUID()
    let appName: String
    let icon: String
    let color: Color
    let totalRAMBytes: Int64
    let totalCPUPercent: Double
    let totalProcessesCount: Int
    let rendererProcesses: [ProcessStats]
    let gpuProcess: ProcessStats?
    let mainProcess: ProcessStats?
    let heaviestWorker: ProcessStats?
    let diskCacheBytes: Int64
    let diskCacheURL: URL?
    let extensions: [BrowserExtensionInfo]
    let extensionsURL: URL?
    let rootCauseSummary: String
    let primaryActionSuggestion: String

    var rendererRAMBytes: Int64 {
        rendererProcesses.reduce(0) { $0 + $1.memoryBytes }
    }

    var gpuRAMBytes: Int64 {
        gpuProcess?.memoryBytes ?? 0
    }

    var baseAppRAMBytes: Int64 {
        max(0, totalRAMBytes - rendererRAMBytes - gpuRAMBytes)
    }
}

enum AppInspector {

    /// Performs deep anatomical inspection of an app's processes, extensions, and disk caches.
    static func inspect(appName: String, allProcesses: [ProcessStats]) -> AppInspectionDetail {
        let canonical = canonicalName(for: appName)
        let matching = allProcesses.filter { proc in
            proc.canonicalAppName.lowercased() == canonical.lowercased() ||
            proc.name.localizedCaseInsensitiveContains(canonical) ||
            (proc.parentAppName?.localizedCaseInsensitiveContains(canonical) ?? false)
        }

        let totalRAM = matching.reduce(0) { $0 + $1.memoryBytes }
        let totalCPU = matching.reduce(0) { $0 + $1.cpuPercent }

        // Categorize sub-processes
        var renderers: [ProcessStats] = []
        var gpuProc: ProcessStats?
        var mainProc: ProcessStats?

        for proc in matching {
            let lower = proc.fullCommand.lowercased()
            let lowerName = proc.name.lowercased()
            if lower.contains("gpu") || lowerName.contains("gpu") {
                gpuProc = proc
            } else if lower.contains("renderer") || lower.contains("helper") || lower.contains("worker") || lower.contains("webcontent") {
                renderers.append(proc)
            } else if mainProc == nil {
                mainProc = proc
            } else {
                renderers.append(proc)
            }
        }

        renderers.sort { $0.memoryBytes > $1.memoryBytes }
        let heaviest = renderers.first ?? matching.max { $0.memoryBytes < $1.memoryBytes }

        // Find disk cache & extensions if applicable
        let (cacheBytes, cacheURL, extURL) = findAppDiskCacheAndExtensions(appName: canonical)
        var extensions: [BrowserExtensionInfo] = []
        if let extURL = extURL {
            extensions = DesignerBrowserScanner.candidateDesignCaches().isEmpty ? [] : []
            // Parse Chromium extensions if browser
            let fm = FileManager.default
            if fm.fileExists(atPath: extURL.path) {
                extensions = parseExtensions(at: extURL, browserName: canonical)
            }
        }

        // Formulate Root Cause Summary & Action
        var causeParts: [String] = []
        if !renderers.isEmpty {
            causeParts.append("\(renderers.count) tab/worker renderers (\(ByteFormat.string(renderers.reduce(0) { $0 + $1.memoryBytes })))")
        }
        if !extensions.isEmpty {
            causeParts.append("\(extensions.count) browser extensions")
        }
        if let gpu = gpuProc, gpu.memoryBytes > 200 * 1024 * 1024 {
            causeParts.append("GPU accelerator (\(ByteFormat.string(gpu.memoryBytes)))")
        }
        if cacheBytes > 500 * 1024 * 1024 {
            causeParts.append("\(ByteFormat.string(cacheBytes)) web/media cache on disk")
        }

        let summary = causeParts.isEmpty
            ? "\(matching.count) active processes consuming \(ByteFormat.string(totalRAM)) RAM"
            : causeParts.joined(separator: " • ")

        let actionSuggestion: String
        if let h = heaviest, h.memoryBytes > 600 * 1024 * 1024 {
            actionSuggestion = "Tab/Worker (PID \(h.pid)) is consuming \(ByteFormat.string(h.memoryBytes)). Closing this inactive tab will restore memory immediately."
        } else if cacheBytes > 2 * 1024 * 1024 * 1024 {
            actionSuggestion = "Disk cache has grown to \(ByteFormat.string(cacheBytes)). Clearing it will free up substantial disk space."
        } else if !extensions.isEmpty && extensions.count >= 6 {
            actionSuggestion = "\(extensions.count) extensions are running in every tab. Disabling unused screen recorders or ad-blockers will reduce memory pressure."
        } else {
            actionSuggestion = "App is running normally. Quit the application if not actively working in it."
        }

        return AppInspectionDetail(
            appName: canonical,
            icon: icon(for: canonical),
            color: color(for: canonical),
            totalRAMBytes: totalRAM,
            totalCPUPercent: totalCPU,
            totalProcessesCount: matching.count,
            rendererProcesses: renderers,
            gpuProcess: gpuProc,
            mainProcess: mainProc,
            heaviestWorker: heaviest,
            diskCacheBytes: cacheBytes,
            diskCacheURL: cacheURL,
            extensions: extensions,
            extensionsURL: extURL,
            rootCauseSummary: summary,
            primaryActionSuggestion: actionSuggestion
        )
    }

    private struct FriendlyAppEntry {
        let keyword: String
        let displayName: String
        let description: String
        let icon: String
        let color: Color
        let isExact: Bool
    }

    private static let knownAppsCatalog: [FriendlyAppEntry] = [
        FriendlyAppEntry(keyword: "du", displayName: "Disk Usage Scanner (du)", description: "Native macOS process calculating file and folder sizes on disk during scans.", icon: "externaldrive.badge.timemachine", color: .blue, isExact: true),
        FriendlyAppEntry(keyword: "find", displayName: "File Search Indexer (find)", description: "Native macOS process locating files and directory structures on disk.", icon: "doc.text.magnifyingglass", color: .teal, isExact: true),
        FriendlyAppEntry(keyword: "mds", displayName: "Spotlight Search Indexer (mds)", description: "Native macOS background indexing daemon for Spotlight search queries.", icon: "sparkle.magnifyingglass", color: .indigo, isExact: false),
        FriendlyAppEntry(keyword: "cloudd", displayName: "iCloud Drive Sync (cloudd)", description: "macOS background daemon synchronizing files with iCloud Drive.", icon: "icloud.fill", color: .blue, isExact: false),
        FriendlyAppEntry(keyword: "syspolicyd", displayName: "Gatekeeper Security (syspolicyd)", description: "macOS security subsystem verifying application codesigning and integrity.", icon: "shield.checkerboard", color: .green, isExact: false),
        FriendlyAppEntry(keyword: "kernel_task", displayName: "macOS Core Kernel (kernel_task)", description: "Core macOS operating system managing RAM, CPU scheduler, and thermal regulation.", icon: "cpu.fill", color: .gray, isExact: true),
        FriendlyAppEntry(keyword: "windowserver", displayName: "macOS Graphics Compositor (WindowServer)", description: "macOS display compositor rendering windows, blur effects, and external displays.", icon: "macwindow.on.rectangle", color: .purple, isExact: true),
        FriendlyAppEntry(keyword: "git", displayName: "Git Version Control (git)", description: "Developer tool tracking source code changes and repository history.", icon: "arrow.triangle.branch", color: .orange, isExact: true),
        FriendlyAppEntry(keyword: "antigravity", displayName: "Google Antigravity Assistant", description: "AI pair programming assistant currently running tasks on your Mac.", icon: "sparkles", color: .purple, isExact: false),
        FriendlyAppEntry(keyword: "chrome", displayName: "Google Chrome", description: "Google Chrome web browser, active web tabs, and extensions.", icon: "globe", color: .blue, isExact: false),
        FriendlyAppEntry(keyword: "figma", displayName: "Figma Desktop", description: "Cloud-based UI/UX vector design editor and canvas rendering engine.", icon: "paintbrush.pointed.fill", color: .pink, isExact: false),
        FriendlyAppEntry(keyword: "xcode", displayName: "Xcode IDE", description: "Apple integrated development environment (compilers, simulators, and indexers).", icon: "hammer.fill", color: .cyan, isExact: false),
        FriendlyAppEntry(keyword: "arc", displayName: "Arc Browser", description: "Arc web browser workspaces, active tabs, and extensions.", icon: "globe", color: .purple, isExact: false),
        FriendlyAppEntry(keyword: "brave", displayName: "Brave Browser", description: "Privacy-focused Brave web browser and shield engine.", icon: "globe", color: .orange, isExact: false),
        FriendlyAppEntry(keyword: "safari", displayName: "Safari Web Browser", description: "Apple native WebKit browser and active tab contents.", icon: "safari.fill", color: .blue, isExact: false),
        FriendlyAppEntry(keyword: "webcontent", displayName: "Safari Web Content", description: "WebKit isolated web renderer process.", icon: "safari.fill", color: .blue, isExact: false),
        FriendlyAppEntry(keyword: "spotify", displayName: "Spotify Music", description: "Streaming music player and podcast audio daemon.", icon: "music.note", color: .green, isExact: false),
        FriendlyAppEntry(keyword: "slack", displayName: "Slack", description: "Team collaboration and workplace messaging client.", icon: "bubble.left.and.bubble.right.fill", color: .yellow, isExact: false),
        FriendlyAppEntry(keyword: "photoshop", displayName: "Adobe Photoshop", description: "Professional raster graphics editor and image manipulation suite.", icon: "paintbrush.pointed.fill", color: .blue, isExact: false),
        FriendlyAppEntry(keyword: "premiere", displayName: "Adobe Premiere Pro", description: "Non-linear professional video editing suite.", icon: "film.stack.fill", color: .purple, isExact: false),
        FriendlyAppEntry(keyword: "after effects", displayName: "Adobe After Effects", description: "Digital visual effects, motion graphics, and compositing application.", icon: "sparkles.tv.fill", color: .purple, isExact: false),
        FriendlyAppEntry(keyword: "docker", displayName: "Docker Desktop", description: "Container virtualization engine and local development runtime.", icon: "shippingbox.fill", color: .blue, isExact: false)
    ]

    static func friendlyInfo(for raw: String) -> (displayName: String, description: String, icon: String, color: Color) {
        let lower = raw.lowercased()

        if let match = knownAppsCatalog.first(where: { entry in
            entry.isExact ? (lower == entry.keyword || lower.hasPrefix(entry.keyword + " ")) : lower.contains(entry.keyword)
        }) {
            return (match.displayName, match.description, match.icon, match.color)
        }

        return (raw, "User application or native macOS background process.", "app.dashed", .accentColor)
    }

    private static func canonicalName(for raw: String) -> String {
        friendlyInfo(for: raw).displayName
    }

    private static func icon(for canonical: String) -> String {
        friendlyInfo(for: canonical).icon
    }

    private static func color(for canonical: String) -> Color {
        friendlyInfo(for: canonical).color
    }

    private static var diskSizeCache: [String: (size: Int64, timestamp: Date)] = [:]

    private static func cachedDiskSize(of url: URL) -> Int64 {
        let path = url.path
        let now = Date()
        if let cached = diskSizeCache[path], now.timeIntervalSince(cached.timestamp) < 60.0 {
            return cached.size
        }
        let size = DiskScanner.size(of: url)
        diskSizeCache[path] = (size, now)
        return size
    }

    private static func findAppDiskCacheAndExtensions(appName: String) -> (bytes: Int64, cacheURL: URL?, extURL: URL?) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        let caches = lib.appendingPathComponent("Caches")
        let appSupport = lib.appendingPathComponent("Application Support")
        let fm = FileManager.default

        let lower = appName.lowercased()

        struct AppPathConfig {
            let cache: URL
            let extensions: URL?
        }

        let configs: [(keyword: String, config: AppPathConfig)] = [
            ("chrome", AppPathConfig(cache: caches.appendingPathComponent("Google/Chrome"), extensions: appSupport.appendingPathComponent("Google/Chrome/Default/Extensions"))),
            ("figma", AppPathConfig(cache: appSupport.appendingPathComponent("Figma"), extensions: nil)),
            ("xcode", AppPathConfig(cache: lib.appendingPathComponent("Developer/Xcode/DerivedData"), extensions: nil)),
            ("arc", AppPathConfig(cache: caches.appendingPathComponent("company.thebrowser.Browser"), extensions: appSupport.appendingPathComponent("Arc/User Data/Default/Extensions"))),
            ("brave", AppPathConfig(cache: caches.appendingPathComponent("BraveSoftware/Brave-Browser"), extensions: appSupport.appendingPathComponent("BraveSoftware/Brave-Browser/Default/Extensions"))),
            ("after effects", AppPathConfig(cache: caches.appendingPathComponent("Adobe/After Effects"), extensions: nil)),
            ("photoshop", AppPathConfig(cache: appSupport.appendingPathComponent("Adobe/Common"), extensions: nil)),
            ("premiere", AppPathConfig(cache: appSupport.appendingPathComponent("Adobe/Common"), extensions: nil))
        ]

        if let matched = configs.first(where: { lower.contains($0.keyword) }) {
            let cacheURL = matched.config.cache
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, matched.config.extensions)
        }

        return (0, nil, nil)
    }

    private static func parseExtensions(at url: URL, browserName: String) -> [BrowserExtensionInfo] {
        let fm = FileManager.default
        guard let extFolders = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [BrowserExtensionInfo] = []
        for folder in extFolders {
            guard let versionFolders = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]),
                  let latestVersion = versionFolders.first else { continue }

            let manifestURL = latestVersion.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            let name = json["name"] as? String ?? folder.lastPathComponent
            let version = json["version"] as? String ?? "1.0"
            let desc = json["description"] as? String ?? "Browser extension"

            let isHeavy = (name + " " + desc).lowercased().contains("screen") ||
                          (name + " " + desc).lowercased().contains("record") ||
                          (name + " " + desc).lowercased().contains("adblock") ||
                          (name + " " + desc).lowercased().contains("ai") ||
                          (name + " " + desc).lowercased().contains("copilot")

            results.append(
                BrowserExtensionInfo(
                    extensionID: folder.lastPathComponent,
                    name: name.hasPrefix("__MSG_") ? folder.lastPathComponent : name,
                    version: version,
                    description: desc.hasPrefix("__MSG_") ? "" : desc,
                    browserName: browserName,
                    isHeavyCandidate: isHeavy
                )
            )
        }
        return results
    }
}
