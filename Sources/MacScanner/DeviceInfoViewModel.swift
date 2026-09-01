// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation

/// Fetches this Mac's static hardware/software specs once per session and
/// shares them — both the Home tab and the Performance tab's device card
/// read from the same instance, so `system_profiler` (a few hundred
/// milliseconds) only runs once, not once per tab.
@MainActor
final class DeviceInfoViewModel: ObservableObject {

    enum Action {
        /// Fetches device info the first time this is called; a no-op after that.
        case appearIfNeeded
    }

    @Published private(set) var device: DeviceInfo?

    private var didFetch = false

    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard !didFetch else { return }
            didFetch = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let info = DeviceInfoProvider.fetch()
                DispatchQueue.main.async { self?.device = info }
            }
        }
    }
}
