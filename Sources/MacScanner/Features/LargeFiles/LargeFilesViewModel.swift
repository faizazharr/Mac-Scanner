// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI
import AppKit

/// Drives the Large Files tab: finds individual files at or above a
/// user-chosen size threshold anywhere under the selected scope.
@MainActor
final class LargeFilesViewModel: ObservableObject {

    enum ScanScope: String, CaseIterable, Identifiable {
        case home = "Home Folder"
        case downloads = "Downloads"
        case entireDrive = "Entire Mac"
        case custom = "Custom…"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .downloads: return "arrow.down.circle.fill"
            case .entireDrive: return "internaldrive.fill"
            case .custom: return "folder.badge.gearshape"
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case largestFirst = "Largest First"
        case smallestFirst = "Smallest First"
        case nameAZ = "Name (A-Z)"
        case recentFirst = "Recently Modified"

        var id: String { rawValue }
    }

    /// Every user-initiated event the Large Files view can raise.
    enum Action {
        case appear
        case rescan
        case moveToTrash(URL)
        case moveSelectedToTrash
        case toggleSelect(UUID)
        case toggleSelectAll
        case setCustomScope(URL)
    }

    @Published private(set) var files: [FileEntry] = []
    @Published private(set) var isScanning = false
    @Published var minMB: Int = 100
    @Published var scanScope: ScanScope = .home
    @Published var customScopeURL: URL?
    @Published var sortOption: SortOption = .largestFirst
    @Published var selectedCategory: FileCategory = .all
    @Published var selectedIDs: Set<UUID> = []
    @Published var searchQuery: String = ""

    private var hasAppeared = false

    var targetDirectory: URL {
        switch scanScope {
        case .home:
            return FileManager.default.homeDirectoryForCurrentUser
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        case .entireDrive:
            return URL(fileURLWithPath: "/")
        case .custom:
            return customScopeURL ?? FileManager.default.homeDirectoryForCurrentUser
        }
    }

    var filteredFiles: [FileEntry] {
        let matched = files.filter { file in
            let matchesCategory = selectedCategory == .all || file.category == selectedCategory
            let matchesQuery = searchQuery.isEmpty
                || file.name.localizedCaseInsensitiveContains(searchQuery)
                || file.url.path.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesQuery
        }

        switch sortOption {
        case .largestFirst:
            return matched.sorted { $0.sizeBytes > $1.sizeBytes }
        case .smallestFirst:
            return matched.sorted { $0.sizeBytes < $1.sizeBytes }
        case .nameAZ:
            return matched.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .recentFirst:
            return matched.sorted { (file1, file2) -> Bool in
                let d1 = (try? file1.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let d2 = (try? file2.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return d1 > d2
            }
        }
    }

    var categoryBreakdown: [(category: FileCategory, count: Int, totalBytes: Int64)] {
        FileCategory.allCases.filter { $0 != .all }.compactMap { cat in
            let catFiles = files.filter { $0.category == cat }
            guard !catFiles.isEmpty else { return nil }
            let total = catFiles.reduce(0) { $0 + $1.sizeBytes }
            return (category: cat, count: catFiles.count, totalBytes: total)
        }.sorted { $0.totalBytes > $1.totalBytes }
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
        case .appear:
            if !hasAppeared {
                hasAppeared = true
                scan()
            }

        case .rescan:
            scan()

        case .setCustomScope(let url):
            customScopeURL = url
            scanScope = .custom
            scan()

        case .moveToTrash(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved to Trash", icon: "trash.fill", tint: .green)
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

        let root = targetDirectory
        let exclude = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        ]

        DiskScanner.findLargeFiles(root: root, minMB: minMB, exclude: exclude) { [weak self] found in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.files = found
                self?.isScanning = false
            }
        }
    }
}

