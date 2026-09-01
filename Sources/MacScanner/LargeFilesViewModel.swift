// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Drives the Large Files tab: finds individual files at or above a
/// user-chosen size threshold anywhere under the home folder.
@MainActor
final class LargeFilesViewModel: ObservableObject {

    /// Every user-initiated event the Large Files view can raise.
    enum Action {
        /// Runs (or reruns) the search with the current `minMB` threshold.
        case rescan
        /// Moves a file to the Trash, then reruns the search.
        case moveToTrash(URL)
    }

    @Published private(set) var files: [FileEntry] = []
    @Published private(set) var isScanning = false

    /// Minimum file size to report, in megabytes. Bound directly to the
    /// view's Stepper — it's plain UI state, not a state transition worth
    /// routing through `send(_:)`.
    @Published var minMB: Int = 200

    /// Single entry point for every action the Large Files view can raise.
    func send(_ action: Action) {
        switch action {
        case .rescan:
            scan()

        case .moveToTrash(let url):
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            scan()
        }
    }

    // MARK: - Private

    private func scan() {
        isScanning = true
        files = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let exclude = [
            home.appendingPathComponent("Library"),
            home.appendingPathComponent(".Trash")
        ]
        DiskScanner.findLargeFiles(root: home, minMB: minMB, exclude: exclude) { [weak self] found in
            self?.files = found
            self?.isScanning = false
        }
    }
}
