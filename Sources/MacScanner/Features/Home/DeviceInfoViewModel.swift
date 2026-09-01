// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

struct DefaultHardwareService: HardwareServiceProviderProtocol {
    init() {}
    func fetchDeviceInfo() async -> DeviceInfo {
        DeviceInfoProvider.fetch()
    }
}

/// Fetches this Mac's static hardware/software specs once per session and
/// shares them — both the Home tab and the Performance tab's device card
/// read from the same instance, so `system_profiler` only runs once.
@MainActor
final class DeviceInfoViewModel: ObservableObject {

    enum Action {
        /// Fetches device info the first time this is called; a no-op after that.
        case appearIfNeeded
        case forceRefresh
    }

    @Published private(set) var device: DeviceInfo?

    private let service: any HardwareServiceProviderProtocol
    private var didFetch = false

    init(service: any HardwareServiceProviderProtocol = DefaultHardwareService()) {
        self.service = service
    }

    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard !didFetch else { return }
            didFetch = true
            Task.detached(priority: .utility) { [service] in
                let info = await service.fetchDeviceInfo()
                await MainActor.run { [weak self] in
                    self?.device = info
                }
            }
        case .forceRefresh:
            didFetch = true
            Task.detached(priority: .userInitiated) { [service] in
                let info = await service.fetchDeviceInfo()
                await MainActor.run { [weak self] in
                    self?.device = info
                }
            }
        }
    }
}
