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

    static func friendlyInfo(for raw: String) -> (displayName: String, description: String, icon: String, color: Color) {
        let lower = raw.lowercased()
        if lower == "du" || lower.hasPrefix("du ") {
            return ("Disk Usage Scanner (du)", "Proses bawaan macOS yang menghitung ukuran berkas dan folder di disk saat pemindaian.", "externaldrive.badge.timemachine", .blue)
        }
        if lower == "find" || lower.hasPrefix("find ") {
            return ("File Search Indexer (find)", "Proses bawaan macOS yang mencari berkas atau direktori di dalam disk.", "doc.text.magnifyingglass", .teal)
        }
        if lower == "mds" || lower == "mdworker" || lower.contains("mdworker") || lower == "mds_stores" {
            return ("Spotlight Search Indexer (mds)", "Layanan latar belakang macOS yang mengindeks file untuk pencarian cepat Spotlight.", "sparkle.magnifyingglass", .indigo)
        }
        if lower == "cloudd" || lower == "bird" {
            return ("iCloud Drive Sync (cloudd)", "Layanan latar belakang macOS untuk sinkronisasi berkas iCloud Drive.", "icloud.fill", .blue)
        }
        if lower == "syspolicyd" || lower == "trustd" {
            return ("Gatekeeper Security (syspolicyd)", "Layanan keamanan macOS yang memverifikasi integritas dan sertifikat aplikasi.", "shield.checkerboard", .green)
        }
        if lower == "kernel_task" {
            return ("macOS Core Kernel (kernel_task)", "Inti sistem operasi macOS yang mengelola RAM, CPU, dan manajemen suhu termal.", "cpu.fill", .gray)
        }
        if lower == "windowserver" {
            return ("macOS Graphics Compositor (WindowServer)", "Layanan grafis macOS yang menggambar seluruh jendela, efek blur, dan layar Mac.", "macwindow.on.rectangle", .purple)
        }
        if lower == "git" {
            return ("Git Version Control (git)", "Alat pelacak versi kode sumber pada proyek developer.", "arrow.triangle.branch", .orange)
        }
        if lower.contains("antigravity") {
            return ("Google Antigravity Assistant", "Asisten pemrograman AI yang sedang aktif menjalankan tugas di Mac Anda.", "sparkles", .purple)
        }
        if lower.contains("chrome") {
            return ("Google Chrome", "Browser web Google Chrome beserta tab dan ekstensinya.", "globe", .blue)
        }
        if lower.contains("figma") {
            return ("Figma Desktop", "Aplikasi desain UI/UX berbasis cloud beserta tab kanvas dan render engine.", "paintbrush.pointed.fill", .pink)
        }
        if lower.contains("xcode") {
            return ("Xcode IDE", "Lingkungan pengembangan aplikasi Apple (compiler, simulator, dan indexer).", "hammer.fill", .cyan)
        }
        if lower.contains("arc") {
            return ("Arc Browser", "Browser web Arc beserta tab dan pengelola ruang kerja.", "globe", .purple)
        }
        if lower.contains("brave") {
            return ("Brave Browser", "Browser web Brave yang berfokus pada privasi.", "globe", .orange)
        }
        if lower.contains("safari") || lower.contains("webcontent") {
            return ("Safari Web Browser", "Browser web bawaan Apple macOS beserta konten tab aktif.", "safari.fill", .blue)
        }
        if lower.contains("spotify") {
            return ("Spotify Music", "Aplikasi pemutar musik dan podcast streaming.", "music.note", .green)
        }
        if lower.contains("slack") {
            return ("Slack", "Aplikasi komunikasi dan kolaborasi tim kerja.", "bubble.left.and.bubble.right.fill", .yellow)
        }
        if lower.contains("photoshop") {
            return ("Adobe Photoshop", "Aplikasi edit grafis dan manipulasi foto raster.", "paintbrush.pointed.fill", .blue)
        }
        if lower.contains("premiere") {
            return ("Adobe Premiere Pro", "Aplikasi penyunting video profesional.", "film.stack.fill", .purple)
        }
        if lower.contains("after effects") {
            return ("Adobe After Effects", "Aplikasi efek visual dan animasi gerak.", "sparkles.tv.fill", .purple)
        }
        if lower.contains("docker") {
            return ("Docker Desktop", "Platform virtualisasi container dan development runtime.", "shippingbox.fill", .blue)
        }
        return (raw, "Aplikasi pengguna atau proses latar belakang macOS.", "app.dashed", .accentColor)
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
        if lower.contains("chrome") {
            let cacheURL = caches.appendingPathComponent("Google/Chrome")
            let extURL = appSupport.appendingPathComponent("Google/Chrome/Default/Extensions")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, extURL)
        } else if lower.contains("figma") {
            let cacheURL = appSupport.appendingPathComponent("Figma")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, nil)
        } else if lower.contains("xcode") {
            let cacheURL = lib.appendingPathComponent("Developer/Xcode/DerivedData")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, nil)
        } else if lower.contains("arc") {
            let cacheURL = caches.appendingPathComponent("company.thebrowser.Browser")
            let extURL = appSupport.appendingPathComponent("Arc/User Data/Default/Extensions")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, extURL)
        } else if lower.contains("brave") {
            let cacheURL = caches.appendingPathComponent("BraveSoftware/Brave-Browser")
            let extURL = appSupport.appendingPathComponent("BraveSoftware/Brave-Browser/Default/Extensions")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, extURL)
        } else if lower.contains("after effects") {
            let cacheURL = caches.appendingPathComponent("Adobe/After Effects")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, nil)
        } else if lower.contains("photoshop") || lower.contains("premiere") {
            let cacheURL = appSupport.appendingPathComponent("Adobe/Common")
            let size = fm.fileExists(atPath: cacheURL.path) ? cachedDiskSize(of: cacheURL) : 0
            return (size, cacheURL, nil)
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
