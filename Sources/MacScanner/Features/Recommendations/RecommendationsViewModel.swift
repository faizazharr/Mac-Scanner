// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Drives the Cleanup Recommendations tab: checks a fixed list of known
/// cleanup targets against this Mac and reports which ones actually exist
/// and how big they are.
@MainActor
final class RecommendationsViewModel: ObservableObject {

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Size (Largest)"
        case safety = "Safety (Safe First)"
        case name = "Name (A-Z)"
    }

    /// Every user-initiated event the Recommendations view can raise.
    enum Action {
        /// View appeared (or the tab was selected) — scans once, if not already done.
        case appearIfNeeded
        /// Forces a fresh scan, overwriting the previous results.
        case rescan
        /// Moves a recommended item to the Trash, then rescans.
        case moveToTrash(URL)
        /// Moves multiple selected recommendations to the Trash.
        case moveSelectedToTrash
        /// Selects or deselects all safe recommendations.
        case toggleSelectAllSafe
        /// Runs smart Docker system & builder prune.
        case dockerSmartPrune
        /// Deletes unavailable/old simulator runtimes and simulator caches.
        case simulatorCleanUnavailable
    }

    @Published private(set) var results: [Recommendation] = []
    @Published private(set) var isScanning = false
    @Published var selectedIDs: Set<UUID> = []
    @Published var selectedCategory: RecommendationCategory? = nil
    @Published var selectedRisk: RiskLevel? = nil
    @Published var searchQuery: String = ""
    @Published var sortOption: SortOption = .sizeDesc

    /// What's actually grown since an earlier check — persisted across app
    /// launches (see `StorageHistoryStore`), unlike everything else here.
    @Published private(set) var growth: [StorageGrowthEntry] = []

    /// Total size of 100% safe-to-clean items (caches, temp logs, build intermediates).
    var totalSafeReclaimable: Int64 {
        results.filter { $0.risk == .safe }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Total size of items requiring review (Docker virtual disks, Simulators, Backups).
    var totalCautionReclaimable: Int64 {
        results.filter { $0.risk == .caution }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Total size of every non-manual-review recommendation.
    var totalReclaimable: Int64 {
        results.filter { $0.risk != .manual }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Total size of currently selected recommendations.
    var totalSelectedBytes: Int64 {
        results.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var filteredResults: [Recommendation] {
        let filtered = results.filter { rec in
            let matchesCat = selectedCategory == nil || rec.category == selectedCategory
            let matchesRisk = selectedRisk == nil || rec.risk == selectedRisk
            let matchesQuery = searchQuery.isEmpty ||
                rec.title.localizedCaseInsensitiveContains(searchQuery) ||
                rec.explanation.localizedCaseInsensitiveContains(searchQuery) ||
                rec.path.path.localizedCaseInsensitiveContains(searchQuery)
            return matchesCat && matchesRisk && matchesQuery
        }

        switch sortOption {
        case .sizeDesc:
            return filtered.sorted { $0.sizeBytes > $1.sizeBytes }
        case .safety:
            return filtered.sorted { a, b in
                if a.risk != b.risk {
                    return a.risk.rawValue < b.risk.rawValue
                }
                return a.sizeBytes > b.sizeBytes
            }
        case .name:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    /// Single entry point for every action the Recommendations view can raise.
    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard results.isEmpty, !isScanning else { return }
            scan()

        case .rescan:
            DiskScanner.invalidateCache()
            scan()

        case .moveToTrash(let url):
            DiskScanner.invalidateCache()
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved item to Trash", icon: "trash.fill", tint: .green)
            } catch {
                ToastManager.shared.show("Failed to move to Trash", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()

        case .moveSelectedToTrash:
            DiskScanner.invalidateCache()
            let selectedRecs = results.filter { selectedIDs.contains($0.id) }
            var movedCount = 0
            var reclaimedBytes: Int64 = 0
            for rec in selectedRecs {
                if (try? FileManager.default.trashItem(at: rec.path, resultingItemURL: nil)) != nil {
                    movedCount += 1
                    reclaimedBytes += rec.sizeBytes
                }
            }
            selectedIDs.removeAll()
            if movedCount > 0 {
                ToastManager.shared.show("Cleaned \(movedCount) items (\(ByteFormat.string(reclaimedBytes)))", icon: "sparkles", tint: .green)
            }
            scan()

        case .toggleSelectAllSafe:
            let safeIDs = Set(results.filter { $0.risk == .safe }.map(\.id))
            if selectedIDs.isSuperset(of: safeIDs) {
                selectedIDs.subtract(safeIDs)
            } else {
                selectedIDs.formUnion(safeIDs)
            }

        case .dockerSmartPrune:
            DiskScanner.invalidateCache()
            Task {
                let (output, builderOutput) = await Task.detached(priority: .userInitiated) { () -> (String, String) in
                    let dockerPath = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker", "\(FileManager.default.homeDirectoryForCurrentUser.path)/.docker/bin/docker"].first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin/docker"
                    let o1 = Shell.run(dockerPath, ["system", "prune", "-f"])
                    let o2 = Shell.run(dockerPath, ["builder", "prune", "-f"])
                    return (o1, o2)
                }.value

                if output.contains("Total reclaimed space") || builderOutput.contains("Total reclaimed space") {
                    ToastManager.shared.show("Docker build cache & dangling images pruned!", icon: "sparkles", tint: .green)
                } else if output.contains("Cannot connect") || output.contains("docker daemon is not running") {
                    ToastManager.shared.show("Docker Desktop belum aktif. Buka Docker Desktop terlebih dahulu.", icon: "exclamationmark.triangle.fill", tint: .orange)
                } else {
                    ToastManager.shared.show("Docker Smart Prune selesai!", icon: "checkmark.circle.fill", tint: .green)
                }
                self.scan()
            }

        case .simulatorCleanUnavailable:
            DiskScanner.invalidateCache()
            Task {
                await Task.detached(priority: .userInitiated) {
                    _ = Shell.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])
                    let cacheDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/CoreSimulator/Caches")
                    _ = try? FileManager.default.trashItem(at: cacheDir, resultingItemURL: nil)
                }.value

                ToastManager.shared.show("Cleaned unavailable simulators & caches", icon: "sparkles", tint: .green)
                self.scan()
            }
        }
    }

    // MARK: - Private

    private func scan() {
        isScanning = true
        results = []
        selectedIDs.removeAll()
        RecommendationEngine.evaluate(
            RecommendationEngine.candidates(),
            progress: { _ in },
            completion: { [weak self] final in
                guard let self else { return }
                self.results = final
                self.isScanning = false
                self.growth = StorageHistoryStore.shared.growth(against: final)
                StorageHistoryStore.shared.recordSnapshot(from: final)
            }
        )
    }
}
