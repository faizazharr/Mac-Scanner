// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AppKit

// MARK: - Hardware Service Protocol (SOLID: Interface Segregation)

protocol HardwareServiceProviderProtocol: Sendable {
    func fetchDeviceInfo() async -> DeviceInfo
}

// MARK: - Performance Telemetry Service Protocol (SOLID: Dependency Inversion)

protocol PerformanceTelemetryProviderProtocol: Sendable {
    func captureSnapshot() async -> PerformanceMonitor.Snapshot
}

// MARK: - App Uninstaller Service Protocol

protocol AppUninstallerServiceProtocol: Sendable {
    func scanInstalledApps() async -> [InstalledAppInfo]
    func scanAppLeftovers(for app: InstalledAppInfo) async -> [AppLeftoverItem]
    func removeItems(_ items: [AppLeftoverItem]) async throws -> Int64
}

// MARK: - Screening Telemetry Service Protocol

protocol ScreeningTelemetryServiceProtocol: Sendable {
    func fetchScreeningOverview() async -> MacScreeningOverview
}
