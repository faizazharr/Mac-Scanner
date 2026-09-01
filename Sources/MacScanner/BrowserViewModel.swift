// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import Combine

/// Drives the Folder Browser tab.
///
/// All mutations go through `send(_:)` — a single dispatch point for every
/// user-raised event (navigation, rescan, trash) — instead of a grab-bag of
/// public methods called directly from the view. Every published property is
/// `private(set)`: the view can only read state and raise actions, never
/// mutate it directly, so every state change is traceable to one call site.
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

    /// Per-folder scan cache, keyed by path — revisiting a folder (breadcrumb,
    /// switching tabs and back) shows the last result instantly instead of
    /// re-running `du` over it again. `.rescan` bypasses this on purpose.
    private var cache: [String: [FileEntry]] = [:]

    /// Folders currently being scanned — bouncing in and out of a folder
    /// before its scan finishes must not spawn a second redundant scan.
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
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            scan()
        }
    }

    /// Every ancestor of `currentDirectory`, from "/" down to the current folder,
    /// so the breadcrumb always reflects the true path — not just navigation history.
    var pathChain: [URL] {
        var chain: [URL] = []
        var url = currentDirectory.standardizedFileURL
        // Bound by pathComponents count, not string equality — a trailing-slash
        // or percent-encoding mismatch between successive deletingLastPathComponent()
        // calls can make `parent.path == url.path` never become true, spinning
        // the main thread forever (this once pegged CPU and leaked memory).
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

        guard !inFlightScans.contains(dir.path) else {
            // Already scanning this exact folder from an earlier visit (user
            // bounced back in before it finished) — don't duplicate the work,
            // the running scan will land here and cache it regardless.
            return
        }
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
                // Always cache — even if the user already navigated elsewhere
                // (e.g. clicked into a folder before this scan finished), so
                // coming back to `dir` later is instant instead of rescanning.
                self.cache[dir.path] = final
                guard self.currentDirectory == dir else { return }
                self.entries = final
                self.isScanning = false
            }
        )
    }
}
