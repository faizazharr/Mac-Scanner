// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Drives the Cleanup Recommendations tab: checks a fixed list of known
/// cleanup targets against this Mac and reports which ones actually exist
/// and how big they are. See `RecommendationEngine` for the candidate list.
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
    }

    @Published private(set) var results: [Recommendation] = []
    @Published private(set) var isScanning = false

    /// Total size of every non-manual-review recommendation — the headline
    /// "reclaimable" figure shown at the top of the tab.
    var totalReclaimable: Int64 {
        results.filter { $0.risk != .manual }.reduce(0) { $0 + $1.sizeBytes }
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
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            scan()
        }
    }

    // MARK: - Private

    private func scan() {
        isScanning = true
        results = []
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
