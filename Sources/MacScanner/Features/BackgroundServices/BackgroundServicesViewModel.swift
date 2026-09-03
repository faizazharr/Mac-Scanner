// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Combine

/// Filter options for the Background Services list.
enum ServiceFilter: String, CaseIterable {
    case all        = "All"
    case thirdParty = "Third-Party"
    case running    = "Running"
    case heavy      = "Heavy (>5% CPU)"
}

/// ViewModel managing background service scanning, filtering, and polling.
@MainActor
final class BackgroundServicesViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var services: [BackgroundService] = []
    @Published private(set) var isScanning: Bool = false
    @Published var filter: ServiceFilter = .all { didSet { currentPage = 0 } }
    @Published private(set) var currentPage: Int = 0

    /// Rows are rendered a page at a time instead of all ~500+ at once —
    /// a `LazyVStack` still has to lay out every row's frame once its
    /// `ForEach` diffs a 500-item array on each 30s poll, which was
    /// showing up as visible per-tick main-thread cost.
    let pageSize = 40

    private var timer: Timer?

    // MARK: - Computed

    var filteredServices: [BackgroundService] {
        switch filter {
        case .all:        return services
        case .thirdParty: return services.filter(\.isThirdParty)
        case .running:    return services.filter { $0.status.isRunning }
        case .heavy:      return services.filter { $0.cpuPercent > 5 }
        }
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(filteredServices.count) / Double(pageSize))))
    }

    var pagedServices: [BackgroundService] {
        let all = filteredServices
        let start = min(currentPage * pageSize, all.count)
        let end = min(start + pageSize, all.count)
        return Array(all[start..<end])
    }

    func nextPage() {
        guard currentPage + 1 < totalPages else { return }
        currentPage += 1
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }

    var totalRunning: Int    { services.filter { $0.status.isRunning }.count }
    var totalCPU: Double     { services.reduce(0) { $0 + $1.cpuPercent } }
    var totalMemory: Int64   { services.reduce(0) { $0 + $1.memoryBytes } }
    var thirdPartyCount: Int { services.filter(\.isThirdParty).count }
    var heavyCount: Int      { services.filter { $0.cpuPercent > 5 || $0.memoryBytes > 150_000_000 }.count }

    // MARK: - Lifecycle

    func appear() {
        scanNow()
        startPolling()
    }

    func disappear() {
        stopPolling()
    }

    func scanNow() {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .utility) {
            let result = BackgroundServiceScanner.scan()
            await MainActor.run {
                self.services = result
                self.isScanning = false
                self.currentPage = 0
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanNow()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
