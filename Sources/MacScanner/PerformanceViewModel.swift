// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Drives the Performance tab: live system-load telemetry, sparkline history,
/// and process inspection.
@MainActor
final class PerformanceViewModel: ObservableObject {

    /// Every user-initiated (or tab-lifecycle) event the Performance view can raise.
    enum Action {
        /// Tab became visible — starts the live-refresh timer.
        case appear
        /// Tab was left — stops the timer so it's not polling in the background.
        case disappear
        /// Manual refresh, independent of the timer.
        case refreshNow
        /// Request termination of a specific process.
        case terminate(pid: Int32, name: String)
        /// The Top Processes sort mode changed — informs the next capture
        /// whether the (separate, equally expensive) RAM-sorted process
        /// scan is actually worth fetching.
        case setProcessSort(ProcessSortMode)
    }

    /// Live numbers — updates every tick (3s).
    @Published private(set) var snapshot: PerformanceMonitor.Snapshot?

    /// Rolling telemetry history for live Swift Charts sparklines.
    @Published private(set) var history: [PerformanceHistoryPoint] = []

    /// Search/filter query for top processes.
    @Published var processSearchQuery: String = ""

    /// Recommendations, one row per metric.
    @Published private(set) var stableRecommendations: [PerformanceRecommendation] = []

    private var timer: Timer?
    private var lastSignatures: [String: String] = [:]
    private var frozenAdviceByTitle: [String: String] = [:]
    private let maxHistoryPoints = 25
    private var processSort: ProcessSortMode = .cpu

    /// Single entry point for every action the Performance view can raise.
    func send(_ action: Action) {
        switch action {
        case .appear:
            refresh()
            startAutoRefresh()

        case .disappear:
            stopAutoRefresh()

        case .refreshNow:
            refresh()

        case .terminate(let pid, let name):
            let success = PerformanceMonitor.terminateProcess(pid: pid)
            if success {
                ToastManager.shared.show("Terminated \(name) (PID: \(pid))", icon: "xmark.octagon.fill", tint: .orange)
                refresh()
            } else {
                ToastManager.shared.show("Could not terminate \(name)", icon: "exclamationmark.circle.fill", tint: .red)
            }

        case .setProcessSort(let mode):
            processSort = mode
        }
    }

    // MARK: - Private

    private func refresh() {
        let wantsMemorySortedList = processSort == .memory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = PerformanceMonitor.capture(includeMemorySortedProcesses: wantsMemorySortedList)
            DispatchQueue.main.async { self?.apply(snapshot) }
        }
    }

    private func apply(_ snapshot: PerformanceMonitor.Snapshot) {
        self.snapshot = snapshot

        // Record history point for sparkline charts
        let point = PerformanceHistoryPoint(
            timestamp: Date(),
            cpuPercent: snapshot.cpuPercent,
            memoryPercent: snapshot.memory.usedFraction * 100
        )
        history.append(point)
        if history.count > maxHistoryPoints {
            history.removeFirst(history.count - maxHistoryPoints)
        }

        stableRecommendations = snapshot.recommendations.map { rec in
            let sig = signature(for: rec, snapshot: snapshot)
            if lastSignatures[rec.title] != sig || frozenAdviceByTitle[rec.title] == nil {
                lastSignatures[rec.title] = sig
                frozenAdviceByTitle[rec.title] = rec.advice
            }
            return PerformanceRecommendation(
                title: rec.title, icon: rec.icon, risk: rec.risk,
                statusLabel: rec.statusLabel,
                advice: frozenAdviceByTitle[rec.title] ?? rec.advice
            )
        }
    }

    private func signature(for rec: PerformanceRecommendation, snapshot: PerformanceMonitor.Snapshot) -> String {
        guard rec.risk != .ok else { return "\(rec.title):ok" }
        switch rec.title {
        case "Memory", "Swap":
            return "\(rec.title):\(rec.risk.rawValue):\(snapshot.heaviestByMemory?.name ?? "")"
        case "CPU":
            return "\(rec.title):\(rec.risk.rawValue):\(snapshot.heaviestProcess?.name ?? "")"
        default:
            return "\(rec.title):\(rec.risk.rawValue)"
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        // Every metric here is a subprocess spawn; even parallelized, polling
        // faster than this has diminishing returns for a "how's my Mac doing"
        // dashboard and just burns more CPU sampling more often.
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
}
