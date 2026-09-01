// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Drives the Performance tab: live system-load telemetry, sparkline history,
/// process inspection, and app root-cause dissection.
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
        /// Inspect a specific app's root cause and process anatomy.
        case inspectApp(String)
        /// Clear inspected app detail.
        case clearInspectedApp
        /// Clean an app's disk cache.
        case cleanAppCache(URL, String)
        /// The Top Processes sort mode changed.
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

    /// Which apps have actually been heavy over this session.
    @Published private(set) var heaviestAppsThisSession: [AppImpactRecord] = []

    /// Detailed anatomical root-cause breakdown of a selected/highlighted heavy app.
    @Published private(set) var inspectedApp: AppInspectionDetail?

    private var timer: Timer?
    private var lastSignatures: [String: String] = [:]
    private var frozenAdviceByTitle: [String: String] = [:]
    private let maxHistoryPoints = 25
    private var processSort: ProcessSortMode = .cpu
    private let impactTracker = AppImpactTracker()
    private var lastApplyTime: Date?
    private var manuallySelectedAppName: String?
    private var activeViewerCount = 0

    /// Single entry point for every action the Performance view can raise.
    func send(_ action: Action) {
        switch action {
        case .appear:
            activeViewerCount += 1
            if activeViewerCount == 1 {
                refresh()
                startAutoRefresh()
            }

        case .disappear:
            activeViewerCount = max(0, activeViewerCount - 1)
            if activeViewerCount == 0 {
                stopAutoRefresh()
            }

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

        case .inspectApp(let name):
            manuallySelectedAppName = name
            updateInspectedApp()

        case .clearInspectedApp:
            manuallySelectedAppName = nil
            inspectedApp = nil

        case .cleanAppCache(let url, let appName):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Cleared \(appName) cache", icon: "trash.fill", tint: .green)
                updateInspectedApp()
            } catch {
                ToastManager.shared.show("Could not clear cache", icon: "exclamationmark.triangle.fill", tint: .red)
            }

        case .setProcessSort(let mode):
            processSort = mode
        }
    }

    // MARK: - Private

    private func refresh() {
        let wantsMem = processSort == .memory
        Task {
            let snap = await Task.detached(priority: .utility) {
                PerformanceMonitor.capture(includeMemorySortedProcesses: wantsMem)
            }.value

            self.apply(snapshot: snap)
        }
    }

    private func apply(snapshot: PerformanceMonitor.Snapshot) {
        self.snapshot = snapshot

        let now = Date()
        let elapsed = lastApplyTime.map { now.timeIntervalSince($0) } ?? 3.0
        lastApplyTime = now
        impactTracker.record(snapshot.topProcesses, intervalSeconds: elapsed)
        heaviestAppsThisSession = impactTracker.rankedBySustainedImpact()

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

        updateInspectedApp()
    }

    private func updateInspectedApp() {
        guard let snapshot = self.snapshot else { return }

        // Determine which app to inspect: manually chosen app, or the #1 heaviest non-system app
        let targetName: String
        if let manual = manuallySelectedAppName {
            targetName = manual
        } else if let topUserApp = heaviestAppsThisSession.first(where: { !$0.isSystemDaemon }) {
            targetName = topUserApp.name
        } else if let heaviestProc = snapshot.topProcesses.first(where: { !$0.isSystemDaemon }) {
            targetName = heaviestProc.canonicalAppName
        } else {
            return
        }

        Task {
            let detail = await Task.detached(priority: .utility) {
                AppInspector.inspect(appName: targetName, allProcesses: snapshot.topProcesses)
            }.value
            self.inspectedApp = detail
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
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
}
