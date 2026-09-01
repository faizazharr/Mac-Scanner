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

        Task.detached(priority: .userInitiated) { [weak self] in
            let caches = await withCheckedContinuation { continuation in
                DesignerBrowserScanner.scanDesignCaches { results in
                    continuation.resume(returning: results)
                }
            }

            let b = await withCheckedContinuation { continuation in
                DesignerBrowserScanner.scanBrowsers { results in
                    continuation.resume(returning: results)
                }
            }

            let snapshot = PerformanceMonitor.capture(processLimit: 12)
            let diagnostics = DesignerBrowserScanner.generatePlainLanguageInsights(
                designCaches: caches,
                browsers: b,
                heaviestApps: snapshot.topProcesses
            )

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.designCaches = caches
                self.browsers = b
                self.insights = diagnostics
                if self.selectedBrowserID == nil, let first = b.first {
                    self.selectedBrowserID = first.id
                }
                self.isScanning = false
            }
        }
    }
}
