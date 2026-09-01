// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

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
        /// Moves all selected files to Trash.
        case moveSelectedToTrash
        /// Toggles selection for an item.
        case toggleSelect(UUID)
        /// Selects or deselects all currently filtered items.
        case toggleSelectAll
    }

    @Published private(set) var files: [FileEntry] = []
    @Published private(set) var isScanning = false
    @Published var minMB: Int = 200
    @Published var selectedCategory: FileCategory = .all
    @Published var selectedIDs: Set<UUID> = []
    @Published var searchQuery: String = ""

    var filteredFiles: [FileEntry] {
        files.filter { file in
            let matchesCategory = selectedCategory == .all || file.category == selectedCategory
            let matchesQuery = searchQuery.isEmpty
                || file.name.localizedCaseInsensitiveContains(searchQuery)
                || file.url.path.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesQuery
        }
    }

    var totalFilteredBytes: Int64 {
        filteredFiles.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalSelectedBytes: Int64 {
        files.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Single entry point for every action the Large Files view can raise.
    func send(_ action: Action) {
        switch action {
        case .rescan:
            scan()

        case .moveToTrash(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved file to Trash", icon: "trash.fill", tint: .green)
            } catch {
                ToastManager.shared.show("Failed to move to Trash", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()

        case .moveSelectedToTrash:
            let selectedFiles = files.filter { selectedIDs.contains($0.id) }
            var count = 0
            var reclaimed: Int64 = 0
            for file in selectedFiles {
                if (try? FileManager.default.trashItem(at: file.url, resultingItemURL: nil)) != nil {
                    count += 1
                    reclaimed += file.sizeBytes
                }
            }
            selectedIDs.removeAll()
            if count > 0 {
                ToastManager.shared.show("Moved \(count) files to Trash (\(ByteFormat.string(reclaimed)))", icon: "trash.fill", tint: .green)
            }
            scan()

        case .toggleSelect(let id):
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }

        case .toggleSelectAll:
            let currentIDs = Set(filteredFiles.map(\.id))
            if selectedIDs.isSuperset(of: currentIDs) {
                selectedIDs.subtract(currentIDs)
            } else {
                selectedIDs.formUnion(currentIDs)
            }
        }
    }

    // MARK: - Private

    private func scan() {
        isScanning = true
        files = []
        selectedIDs.removeAll()
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
