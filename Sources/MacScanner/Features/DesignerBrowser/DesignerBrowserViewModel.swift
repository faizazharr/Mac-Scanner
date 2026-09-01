// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI

/// Drives the Designer & Browser Bloat Screener tab.
@MainActor
final class DesignerBrowserViewModel: ObservableObject {

    enum Action {
        case appearIfNeeded
        case rescan
        case cleanDesignCache(URL)
        case cleanBrowserCache(URL)
        case cleanAllSafeDesignCaches
    }

    @Published private(set) var designCaches: [DesignAppCacheInfo] = []
    @Published private(set) var browsers: [BrowserInfo] = []
    @Published private(set) var insights: [DesignerDiagnosticInsight] = []
    @Published private(set) var isScanning = false
    @Published var selectedBrowserID: UUID?

    var totalDesignCacheBytes: Int64 {
        designCaches.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalBrowserCacheBytes: Int64 {
        browsers.reduce(0) { $0 + $1.cacheBytes }
    }

    var totalExtensionsCount: Int {
        browsers.reduce(0) { $0 + $1.extensionsCount }
    }

    func send(_ action: Action) {
        switch action {
        case .appearIfNeeded:
            guard designCaches.isEmpty && browsers.isEmpty, !isScanning else { return }
            scan()

        case .rescan:
            scan()

        case .cleanDesignCache(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Moved design cache to Trash", icon: "paintbrush.fill", tint: .green)
            } catch {
                ToastManager.shared.show("Could not clean cache", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()

        case .cleanBrowserCache(let url):
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                ToastManager.shared.show("Cleared browser cache", icon: "globe", tint: .green)
            } catch {
                ToastManager.shared.show("Could not clear cache", icon: "exclamationmark.triangle.fill", tint: .red)
            }
            scan()

        case .cleanAllSafeDesignCaches:
            var cleanedCount = 0
            var reclaimedBytes: Int64 = 0
            for item in designCaches where item.safeToClean {
                if (try? FileManager.default.trashItem(at: item.path, resultingItemURL: nil)) != nil {
                    cleanedCount += 1
                    reclaimedBytes += item.sizeBytes
                }
            }
            if cleanedCount > 0 {
                ToastManager.shared.show("Cleaned \(cleanedCount) design caches (\(ByteFormat.string(reclaimedBytes)))", icon: "sparkles", tint: .green)
            }
            scan()
        }
    }

    // MARK: - Private

    private func scan() {
        isScanning = true
        designCaches = []
        browsers = []
        insights = []

        let group = DispatchGroup()
        var scannedCaches: [DesignAppCacheInfo] = []
        var scannedBrowsers: [BrowserInfo] = []

        group.enter()
        DesignerBrowserScanner.scanDesignCaches { results in
            scannedCaches = results
            group.leave()
        }

        group.enter()
        DesignerBrowserScanner.scanBrowsers { results in
            scannedBrowsers = results
            group.leave()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            group.wait()
            let snapshot = PerformanceMonitor.capture(processLimit: 12)
            let diagnostics = DesignerBrowserScanner.generatePlainLanguageInsights(
                designCaches: scannedCaches,
                browsers: scannedBrowsers,
                heaviestApps: snapshot.topProcesses
            )

            DispatchQueue.main.async {
                guard let self else { return }
                self.designCaches = scannedCaches
                self.browsers = scannedBrowsers
                self.insights = diagnostics
                if self.selectedBrowserID == nil, let first = scannedBrowsers.first {
                    self.selectedBrowserID = first.id
                }
                self.isScanning = false
            }
        }
    }
}
