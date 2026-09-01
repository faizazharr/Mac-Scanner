// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import Combine
import SwiftUI

/// Drives the Folder Browser tab.
@MainActor
final class BrowserViewModel: ObservableObject {

    /// Every user-initiated event the Folder Browser view can raise.
    enum Action {
        /// View appeared — scans the initial (home) folder exactly once.
        case appear
        /// Forces a fresh scan of the current folder, bypassing the cache.
        case rescan
        /// Navigates to a folder (breadcrumb, a row, Home/Up buttons, "Choose Folder…").
        case navigate(to: URL)
        /// Navigates one level up from the current folder.
        case navigateUp
        /// Moves a file or folder to the Trash, then rescans the current folder.
        case moveToTrash(URL)
    }

    @Published private(set) var currentDirectory: URL
    @Published private(set) var entries: [FileEntry] = []
    @Published private(set) var isScanning = false
    @Published private(set) var volumeTotal: Int64 = 0
    @Published private(set) var volumeFree: Int64 = 0

    @Published var selectedCategory: FileCategory = .all
    @Published var searchQuery: String = ""

    var filteredEntries: [FileEntry] {
        entries.filter { entry in
            let matchesCategory = selectedCategory == .all || entry.category == selectedCategory
            let matchesQuery = searchQuery.isEmpty || entry.name.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesQuery
        }
    }

    /// Per-folder scan cache, keyed by path.
    private var cache: [String: [FileEntry]] = [:]
    private var inFlightScans: Set<String> = []
    private var didAppear = false

    init() {
        currentDirectory = FileManager.default.homeDirectoryForCurrentUser
        refreshVolumeInfo()
    }

    /// Single entry point for every action the Folder Browser view can raise.
    func send(_ action: Action) {
        switch action {
        case .appear:
            guard !didAppear else { return }
            didAppear = true
            scan()

        case .rescan:
            scan()

        case .navigate(let url):
            navigate(to: url)

        case .navigateUp:
            guard currentDirectory.standardizedFileURL.pathComponents.count > 1 else { return }
            navigate(to: currentDirectory.deletingLastPathComponent())

        case .moveToTrash(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved item to Trash", icon: "trash.fill", tint: .green)
            } catch {
                ToastManager.shared.show("Failed to move to Trash", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()
        }
    }

    var pathChain: [URL] {
        var chain: [URL] = []
        var url = currentDirectory.standardizedFileURL
        while url.pathComponents.count > 1 {
            chain.append(url)
            url = url.deletingLastPathComponent()
        }
        chain.append(url)
        return chain.reversed()
    }

    // MARK: - Private

    private func refreshVolumeInfo() {
        if let info = DiskScanner.volumeInfo(for: currentDirectory) {
            volumeTotal = info.total
            volumeFree = info.free
        }
    }

    private func navigate(to url: URL) {
        currentDirectory = url
        refreshVolumeInfo()
        if let cached = cache[url.path] {
            entries = cached
            isScanning = false
        } else {
            scan()
        }
    }

    private func scan() {
        isScanning = true
        entries = []
        refreshVolumeInfo()
        let dir = currentDirectory

        guard !inFlightScans.contains(dir.path) else { return }
        inFlightScans.insert(dir.path)

        DiskScanner.scanChildren(
            of: dir,
            progress: { [weak self] entry in
                guard let self, self.currentDirectory == dir else { return }
                self.entries.append(entry)
                self.entries.sort { $0.sizeBytes > $1.sizeBytes }
            },
            completion: { [weak self] final in
                guard let self else { return }
                self.inFlightScans.remove(dir.path)
                self.cache[dir.path] = final
                guard self.currentDirectory == dir else { return }
                self.entries = final
                self.isScanning = false
            }
        )
    }
}
