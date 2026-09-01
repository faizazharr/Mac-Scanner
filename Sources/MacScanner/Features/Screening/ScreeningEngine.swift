// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AppKit
import SwiftUI

/// App screening telemetry report model.
struct AppUsageScreeningItem: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let icon: NSImage
    let isRunning: Bool
    let totalSizeBytes: Int64
    let lastUsedDate: Date?
    let estimatedDailyHours: Double
    let batteryImpactLevel: BatteryImpactLevel
    let batteryPercentageImpact: Double
    let explanation: String

    enum BatteryImpactLevel: String {
        case low = "Hemat Energi"
        case moderate = "Sedang"
        case high = "Tinggi"

        var color: Color {
            switch self {
            case .low: return .green
            case .moderate: return .orange
            case .high: return .red
            }
        }

        var icon: String {
            switch self {
            case .low: return "leaf.fill"
            case .moderate: return "bolt.fill"
            case .high: return "flame.fill"
            }
        }
    }
}

/// System-wide Screen Time & Mac Screening Overview.
struct MacScreeningOverview {
    let bootDate: Date
    let totalUptimeSeconds: TimeInterval
    let estimatedScreenOnHoursToday: Double
    let estimatedDailyAverageHours: Double
    let batteryHealthPercent: Int?
    let batteryCycleCount: Int?
    let isPluggedIn: Bool
    let powerSourceLabel: String
    let topAppsByUsage: [AppUsageScreeningItem]
}

// MARK: - Single-Event Driven Action
enum ScreeningAction: Sendable {
    case refresh
}

struct DefaultScreeningTelemetryService: ScreeningTelemetryServiceProtocol {
    init() {}
    func fetchScreeningOverview() async -> MacScreeningOverview {
        ScreeningEngine.gatherScreeningData()
    }
}

@MainActor
final class ScreeningEngine: ObservableObject {
    @Published var overview: MacScreeningOverview?
    @Published var isLoading: Bool = false

    private let service: any ScreeningTelemetryServiceProtocol

    init(service: any ScreeningTelemetryServiceProtocol = DefaultScreeningTelemetryService()) {
        self.service = service
        send(.refresh)
    }

    func send(_ action: ScreeningAction) {
        switch action {
        case .refresh:
            refreshScreening()
        }
    }

    func refreshScreening() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [service] in
            let data = await service.fetchScreeningOverview()
            await MainActor.run {
                self.overview = data
                self.isLoading = false
            }
        }
    }

    nonisolated static func gatherScreeningData() -> MacScreeningOverview {
        let uptime = ProcessInfo.processInfo.systemUptime
        let bootDate = Date(timeIntervalSinceNow: -uptime)

        // Estimated daily screen active calculation
        let daysUp = max(1.0, uptime / 86400.0)
        let estimatedDailyAvg = min(14.0, max(2.5, (uptime / 3600.0) / daysUp * 0.75))

        let calendar = Calendar.current
        let hoursSinceMidnight = Double(calendar.component(.hour, from: Date())) + (Double(calendar.component(.minute, from: Date())) / 60.0)
        let estimatedTodayScreenOn = min(hoursSinceMidnight, max(1.0, hoursSinceMidnight * 0.65))

        // Power telemetry
        let (isPlugged, powerLabel) = getPowerSourceInfo()
        let (batteryHealth, cycles) = getBatteryDetails()

        // Screen applications
        let apps = gatherAppUsageItems()

        return MacScreeningOverview(
            bootDate: bootDate,
            totalUptimeSeconds: uptime,
            estimatedScreenOnHoursToday: estimatedTodayScreenOn,
            estimatedDailyAverageHours: estimatedDailyAvg,
            batteryHealthPercent: batteryHealth,
            batteryCycleCount: cycles,
            isPluggedIn: isPlugged,
            powerSourceLabel: powerLabel,
            topAppsByUsage: apps
        )
    }

    nonisolated private static func getPowerSourceInfo() -> (Bool, String) {
        let output = Shell.run("/usr/bin/pmset", ["-g", "batt"])
        let isAC = output.contains("AC Power") || output.contains("charged")
        let label = isAC ? "Tersambung Adaptor (AC)" : "Baterai (Discharging)"
        return (isAC, label)
    }

    nonisolated private static func getBatteryDetails() -> (health: Int?, cycles: Int?) {
        let device = DeviceInfoProvider.fetch()
        return (device.batteryMaxCapacityPercent, device.batteryCycleCount)
    }

    nonisolated private static func gatherAppUsageItems() -> [AppUsageScreeningItem] {
        let runningApps = NSWorkspace.shared.runningApplications
        let runningBundleIDs = Set(runningApps.compactMap(\.bundleIdentifier))

        let fm = FileManager.default
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var items: [AppUsageScreeningItem] = []
        var seenIDs = Set<String>()

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !seenIDs.contains(bundleID) else { continue }

                seenIDs.insert(bundleID)
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                let isRunning = runningBundleIDs.contains(bundleID)

                // Approximate app size
                let size = DiskScanner.size(of: url)
                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

                // Battery & Daily hours heuristic
                let (dailyHours, battLevel, battPercent, explanation) = evaluateBatteryImpact(name: name, bundleID: bundleID, isRunning: isRunning)

                items.append(
                    AppUsageScreeningItem(
                        name: name,
                        bundleID: bundleID,
                        icon: icon,
                        isRunning: isRunning,
                        totalSizeBytes: size,
                        lastUsedDate: modDate,
                        estimatedDailyHours: dailyHours,
                        batteryImpactLevel: battLevel,
                        batteryPercentageImpact: battPercent,
                        explanation: explanation
                    )
                )
            }
        }

        // Sort by daily usage and battery impact
        items.sort {
            if $0.isRunning != $1.isRunning { return $0.isRunning && !$1.isRunning }
            return $0.estimatedDailyHours > $1.estimatedDailyHours
        }

        return Array(items.prefix(16))
    }

    nonisolated private static func evaluateBatteryImpact(name: String, bundleID: String, isRunning: Bool) -> (Double, AppUsageScreeningItem.BatteryImpactLevel, Double, String) {
        let lower = (name + " " + bundleID).lowercased()

        if lower.contains("xcode") || lower.contains("simulator") || lower.contains("after effects") || lower.contains("premiere") || lower.contains("blender") {
            let hours = isRunning ? 4.5 : 1.2
            return (hours, .high, 28.0, "Kompilasi kode atau grafis berat memicu beban CPU/GPU intensif.")
        }
        if lower.contains("chrome") || lower.contains("arc") || lower.contains("brave") || lower.contains("edge") {
            let hours = isRunning ? 5.0 : 2.0
            return (hours, .moderate, 18.0, "Banyak tab latar belakang dan proses renderer multi-core.")
        }
        if lower.contains("figma") || lower.contains("photoshop") || lower.contains("illustrator") {
            let hours = isRunning ? 3.5 : 1.0
            return (hours, .moderate, 15.0, "Render kanvas GPU dan akselerasi grafis WebGL.")
        }
        if lower.contains("spotify") || lower.contains("music") || lower.contains("slack") || lower.contains("whatsapp") || lower.contains("telegram") {
            let hours = isRunning ? 4.0 : 1.5
            return (hours, .low, 6.0, "Aplikasi streaming atau perpesanan hemat daya di latar belakang.")
        }

        let hours = isRunning ? 2.0 : 0.4
        return (hours, .low, 3.0, "Aplikasi utilitas ringan dengan konsumsi daya minimal.")
    }
}
