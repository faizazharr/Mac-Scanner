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
    @Published var filter: ServiceFilter = .all

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
