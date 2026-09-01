// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AppKit
import SwiftUI

/// Represents a single artifact or leftover directory belonging to an application.
struct AppLeftoverItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let category: LeftoverCategory
    let url: URL
    let sizeBytes: Int64
    var isSelected: Bool = true

    var formattedSize: String {
        ByteFormat.string(sizeBytes)
    }

    enum LeftoverCategory: String, CaseIterable, Sendable {
        case appBundle = "Main Application (.app)"
        case appSupport = "Application Support"
        case caches = "Caches & WebKit"
        case preferences = "Preferences (.plist)"
        case savedState = "Saved Application State"
        case containers = "Sandbox Containers"
        case logs = "Logs & Crash Reports"
        case launchAgents = "Startup Launch Agents"

        var icon: String {
            switch self {
            case .appBundle: return "app.badge.checkmark.fill"
            case .appSupport: return "folder.badge.gearshape"
            case .caches: return "bolt.horizontal.circle.fill"
            case .preferences: return "slider.horizontal.3"
            case .savedState: return "clock.arrow.circlepath"
            case .containers: return "shippingbox.fill"
            case .logs: return "doc.text.fill"
            case .launchAgents: return "antenna.radiowaves.left.and.right"
            }
        }

        var color: Color {
            switch self {
            case .appBundle: return .blue
            case .appSupport: return .orange
            case .caches: return .purple
            case .preferences: return .cyan
            case .savedState: return .teal
            case .containers: return .indigo
            case .logs: return .gray
            case .launchAgents: return .red
            }
        }
    }
}

/// Information model for an installed application and all its root files.
struct InstalledAppInfo: Identifiable, @unchecked Sendable {
    let id = UUID()
    let name: String
    let bundleID: String
    let bundleURL: URL
    let icon: NSImage
    let version: String
    let isSystemApp: Bool
    var items: [AppLeftoverItem] = []
    var isScanning: Bool = false

    var totalSizeBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedSizeBytes: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedItemsCount: Int {
        items.filter(\.isSelected).count
    }
}

// MARK: - Single-Event Driven Action
enum AppUninstallerAction: Sendable {
    case reload
    case selectApp(InstalledAppInfo)
    case toggleItem(AppLeftoverItem)
    case selectAllItems(Bool)
    case uninstallSelected
}

struct DefaultAppUninstallerService: AppUninstallerServiceProtocol {
    init() {}

    func scanInstalledApps() async -> [InstalledAppInfo] {
        AppUninstallerEngine.scanInstalledApplications()
    }

    func scanAppLeftovers(for app: InstalledAppInfo) async -> [AppLeftoverItem] {
        AppUninstallerEngine.scanAppLeftovers(app: app)
    }

    func removeItems(_ items: [AppLeftoverItem]) async throws -> Int64 {
        try AppUninstallerEngine.performTrashDeletion(items: items)
    }
}

@MainActor
final class AppUninstallerEngine: ObservableObject {
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var selectedApp: InstalledAppInfo?
    @Published var searchQuery: String = ""
    @Published var isLoadingApps: Bool = false
    @Published var isDeleting: Bool = false
    @Published var lastUninstalledName: String?

    private let service: any AppUninstallerServiceProtocol

    init(service: any AppUninstallerServiceProtocol = DefaultAppUninstallerService()) {
        self.service = service
        send(.reload)
    }

    func send(_ action: AppUninstallerAction) {
        switch action {
        case .reload:
            loadInstalledApps()
        case .selectApp(let app):
            selectApp(app)
        case .toggleItem(let item):
            toggleItemSelection(item)
        case .selectAllItems(let select):
            selectAllItems(select)
        case .uninstallSelected:
            uninstallSelectedApp()
        }
    }

    func loadInstalledApps() {
        isLoadingApps = true
        Task.detached(priority: .userInitiated) { [service] in
            let scannedApps = await service.scanInstalledApps()
            await MainActor.run {
                self.installedApps = scannedApps
                self.isLoadingApps = false
                if self.selectedApp == nil, let first = scannedApps.first(where: { !$0.isSystemApp }) {
                    self.selectedApp = first
                }
            }
        }
    }

    nonisolated static func scanInstalledApplications() -> [InstalledAppInfo] {
        var rawApps: [(name: String, bundleID: String, bundleURL: URL, icon: NSImage, version: String, isSystem: Bool)] = []
        let fm = FileManager.default
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var seenBundleIDs = Set<String>()

        for appDir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let name = url.deletingPathExtension().lastPathComponent
                let bundleID = bundle?.bundleIdentifier ?? "com.unknown.\(name.lowercased())"
                let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String ?? (bundle?.infoDictionary?["CFBundleVersion"] as? String ?? "1.0")

                if seenBundleIDs.contains(bundleID) { continue }
                seenBundleIDs.insert(bundleID)

                // Absolute Self-Protection: Never allow MacScanner to appear or be uninstalled by itself
                if name.localizedCaseInsensitiveContains("MacScanner") ||
                    bundleID.localizedCaseInsensitiveContains("MacScanner") ||
                    bundleID == (Bundle.main.bundleIdentifier ?? "") ||
                    url.lastPathComponent == "MacScanner.app" ||
                    url.path == Bundle.main.bundleURL.path {
                    continue
                }

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let isSystem = url.path.hasPrefix("/System/") || name == "Finder"

                rawApps.append((name: name, bundleID: bundleID, bundleURL: url, icon: icon, version: version, isSystem: isSystem))
            }
        }

        // Concurrently scan root leftovers and calculate sizes for all applications
        var completedApps: [InstalledAppInfo] = []
        for raw in rawApps {
            var tempApp = InstalledAppInfo(
                name: raw.name,
                bundleID: raw.bundleID,
                bundleURL: raw.bundleURL,
                icon: raw.icon,
                version: raw.version,
                isSystemApp: raw.isSystem
            )
            tempApp.items = scanAppLeftovers(app: tempApp)
            completedApps.append(tempApp)
        }

        // Sort by total size descending so heaviest apps appear first by default
        completedApps.sort { $0.totalSizeBytes > $1.totalSizeBytes }
        return completedApps
    }

    func selectApp(_ app: InstalledAppInfo) {
        var appCopy = app
        appCopy.isScanning = true
        self.selectedApp = appCopy

        Task.detached(priority: .userInitiated) {
            let items = Self.scanAppLeftovers(app: app)
            await MainActor.run {
                var updated = app
                updated.items = items
                updated.isScanning = false
                self.selectedApp = updated

                // Also update in list
                if let idx = self.installedApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
                    self.installedApps[idx] = updated
                }
            }
        }
    }

    /// Scans all standard macOS root leftover paths for a specific app bundle.
    nonisolated static func scanAppLeftovers(app: InstalledAppInfo) -> [AppLeftoverItem] {
        var items: [AppLeftoverItem] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")

        // 1. Main .app Bundle
        if fm.fileExists(atPath: app.bundleURL.path) {
            let size = DiskScanner.size(of: app.bundleURL)
            items.append(AppLeftoverItem(category: .appBundle, url: app.bundleURL, sizeBytes: size))
        }

        let name = app.name
        let bundleID = app.bundleID

        // 2. Application Support
        let appSupportDirs = [
            lib.appendingPathComponent("Application Support").appendingPathComponent(name),
            lib.appendingPathComponent("Application Support").appendingPathComponent(bundleID)
        ]
        for dir in appSupportDirs where fm.fileExists(atPath: dir.path) {
            let size = DiskScanner.size(of: dir)
            items.append(AppLeftoverItem(category: .appSupport, url: dir, sizeBytes: size))
        }

        // 3. Caches & WebKit
        let cacheDirs = [
            lib.appendingPathComponent("Caches").appendingPathComponent(bundleID),
            lib.appendingPathComponent("Caches").appendingPathComponent(name),
            lib.appendingPathComponent("WebKit").appendingPathComponent(bundleID),
            lib.appendingPathComponent("HTTPStorages").appendingPathComponent(bundleID)
        ]
        for dir in cacheDirs where fm.fileExists(atPath: dir.path) {
            let size = DiskScanner.size(of: dir)
            items.append(AppLeftoverItem(category: .caches, url: dir, sizeBytes: size))
        }

        // 4. Preferences (.plist)
        let prefFiles = [
            lib.appendingPathComponent("Preferences").appendingPathComponent("\(bundleID).plist"),
            lib.appendingPathComponent("Preferences").appendingPathComponent("\(bundleID).plist.lockfile")
        ]
        for file in prefFiles where fm.fileExists(atPath: file.path) {
            let size = (try? fm.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 4096
            items.append(AppLeftoverItem(category: .preferences, url: file, sizeBytes: size))
        }

        // 5. Saved Application State
        let stateDir = lib.appendingPathComponent("Saved Application State").appendingPathComponent("\(bundleID).savedState")
        if fm.fileExists(atPath: stateDir.path) {
            let size = DiskScanner.size(of: stateDir)
            items.append(AppLeftoverItem(category: .savedState, url: stateDir, sizeBytes: size))
        }

        // 6. Sandbox Containers
        let containerDirs = [
            lib.appendingPathComponent("Containers").appendingPathComponent(bundleID),
            lib.appendingPathComponent("Group Containers").appendingPathComponent(bundleID)
        ]
        for dir in containerDirs where fm.fileExists(atPath: dir.path) {
            let size = DiskScanner.size(of: dir)
            items.append(AppLeftoverItem(category: .containers, url: dir, sizeBytes: size))
        }

        // 7. Logs & Diagnostic Reports
        let logDirs = [
            lib.appendingPathComponent("Logs").appendingPathComponent(name),
            lib.appendingPathComponent("Logs").appendingPathComponent(bundleID)
        ]
        for dir in logDirs where fm.fileExists(atPath: dir.path) {
            let size = DiskScanner.size(of: dir)
            items.append(AppLeftoverItem(category: .logs, url: dir, sizeBytes: size))
        }

        // 8. Launch Agents
        let launchAgent = lib.appendingPathComponent("LaunchAgents").appendingPathComponent("\(bundleID).plist")
        if fm.fileExists(atPath: launchAgent.path) {
            let size = (try? fm.attributesOfItem(atPath: launchAgent.path)[.size] as? Int64) ?? 2048
            items.append(AppLeftoverItem(category: .launchAgents, url: launchAgent, sizeBytes: size))
        }

        return items
    }

    nonisolated static func performTrashDeletion(items: [AppLeftoverItem]) throws -> Int64 {
        let fm = FileManager.default
        var deletedBytes: Int64 = 0
        for item in items {
            do {
                try fm.trashItem(at: item.url, resultingItemURL: nil)
                deletedBytes += item.sizeBytes
            } catch {
                print("Error moving \(item.url.path) to Trash: \(error)")
            }
        }
        return deletedBytes
    }

    /// Safely moves all selected items to Trash via injected service.
    func uninstallSelectedApp() {
        guard let app = selectedApp else { return }

        // Extra Safety Protection: Guard against self-destruction
        guard !app.name.localizedCaseInsensitiveContains("MacScanner"),
              !app.bundleID.localizedCaseInsensitiveContains("MacScanner"),
              app.bundleID != (Bundle.main.bundleIdentifier ?? ""),
              !app.bundleURL.path.contains("MacScanner.app") else {
            ToastManager.shared.show("MacScanner is self-protected and cannot uninstall itself.", icon: "shield.fill", tint: .orange)
            return
        }

        isDeleting = true

        let selectedItems = app.items.filter(\.isSelected)
        let appName = app.name

        Task.detached(priority: .userInitiated) { [service] in
            let finalDeletedBytes = (try? await service.removeItems(selectedItems)) ?? 0

            await MainActor.run {
                self.isDeleting = false
                self.lastUninstalledName = appName
                self.installedApps.removeAll { $0.bundleID == app.bundleID }
                self.selectedApp = self.installedApps.first(where: { !$0.isSystemApp })
                if let next = self.selectedApp {
                    self.selectApp(next)
                }
                ToastManager.shared.show("Successfully uninstalled \(appName) (\(ByteFormat.string(finalDeletedBytes)) moved to Trash)", icon: "trash.fill", tint: .green)
            }
        }
    }

    func toggleItemSelection(_ item: AppLeftoverItem) {
        guard var app = selectedApp else { return }
        if let idx = app.items.firstIndex(where: { $0.id == item.id }) {
            app.items[idx].isSelected.toggle()
            selectedApp = app
        }
    }

    func selectAllItems(_ select: Bool) {
        guard var app = selectedApp else { return }
        for i in 0..<app.items.count {
            app.items[i].isSelected = select
        }
        selectedApp = app
    }
}
