// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Drives the Cleanup Recommendations tab: checks a fixed list of known
/// cleanup targets against this Mac and reports which ones actually exist
/// and how big they are.
@MainActor
final class RecommendationsViewModel: ObservableObject {

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
    }

    @Published private(set) var results: [Recommendation] = []
    @Published private(set) var isScanning = false
    @Published var selectedIDs: Set<UUID> = []
    @Published var selectedCategory: RecommendationCategory? = nil
    @Published var selectedRisk: RiskLevel? = nil

    /// Total size of every non-manual-review recommendation.
    var totalReclaimable: Int64 {
        results.filter { $0.risk != .manual }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Total size of currently selected recommendations.
    var totalSelectedBytes: Int64 {
        results.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var filteredResults: [Recommendation] {
        results.filter { rec in
            let matchesCat = selectedCategory == nil || rec.category == selectedCategory
            let matchesRisk = selectedRisk == nil || rec.risk == selectedRisk
            return matchesCat && matchesRisk
        }
    }

    /// Single entry point for every action the Recommendations view can raise.
    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard results.isEmpty, !isScanning else { return }
            scan()

        case .rescan:
            scan()

        case .moveToTrash(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved item to Trash", icon: "trash.fill", tint: .green)
            } catch {
                ToastManager.shared.show("Failed to move to Trash", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()

        case .moveSelectedToTrash:
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
                self?.results = final
                self?.isScanning = false
            }
        )
    }
}
