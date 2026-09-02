// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts

/// Modern Mac Usage Screening & Battery Impact Dashboard.
struct ScreeningView: View {
    @ObservedObject var deviceVM: DeviceInfoViewModel
    @StateObject private var engine = ScreeningEngine()
    @State private var chartMetric: ChartMetric = .hours
    @State private var appFilter: AppFilterOption = .all

    enum ChartMetric: String, CaseIterable {
        case hours = "Screen Time"
        case battery = "Battery Impact"
        case size = "Disk Size"
    }

    enum AppFilterOption: String, CaseIterable {
        case all = "All"
        case running = "Running"
        case heavy = "Heavy Impact"
    }

    var filteredApps: [AppUsageScreeningItem] {
        guard let overview = engine.overview else { return [] }
        switch appFilter {
        case .all:
            return overview.topAppsByUsage
        case .running:
            return overview.topAppsByUsage.filter(\.isRunning)
        case .heavy:
            return overview.topAppsByUsage.filter { $0.batteryImpactLevel == .high || $0.estimatedDailyHours >= 3.0 }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if engine.isLoading && engine.overview == nil {
                    HStack {
                        Spacer()
                        ProgressView("Gathering Mac usage telemetry…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                    .glassCard()
                } else if let overview = engine.overview {
                    topMetricsGrid(overview)
                    ScreeningUsageChart(apps: overview.topAppsByUsage, chartMetric: $chartMetric)
                    batteryPowerBanner(overview)
                    appScreeningSection(filteredApps)
                }
            }
            .padding(20)
        }
        .onAppear {
            deviceVM.send(.appearIfNeeded)
        }
    }

    // MARK: - Header & Metrics

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.purple.opacity(0.4), lineWidth: 3))
                    Text("Mac & App Screen Time Screening")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Text("Analyze screen time, daily usage estimations, disk footprint, and battery drain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                engine.refreshScreening()
            } label: {
                Label("Refresh Telemetry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func topMetricsGrid(_ overview: MacScreeningOverview) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            MetricTileComponent(
                title: "System Uptime",
                value: formatUptime(overview.totalUptimeSeconds),
                subLabel: "Since boot on \(formattedDate(overview.bootDate))",
                icon: "timer",
                color: .blue
            )

            MetricTileComponent(
                title: "Screen Active Today",
                value: String(format: "%.1f Hours", overview.estimatedScreenOnHoursToday),
                subLabel: "Active time since midnight",
                icon: "laptopcomputer.and.ipad",
                color: .purple
            )

            MetricTileComponent(
                title: "Estimated Daily Average",
                value: String(format: "%.1f Hours / Day", overview.estimatedDailyAverageHours),
                subLabel: "Based on active user sessions",
                icon: "chart.bar.xaxis",
                color: .teal
            )
        }
    }

    private func batteryPowerBanner(_ overview: MacScreeningOverview) -> some View {
        let health = deviceVM.device?.batteryMaxCapacityPercent ?? overview.batteryHealthPercent
        let cycles = deviceVM.device?.batteryCycleCount ?? overview.batteryCycleCount
        let condition = deviceVM.device?.batteryCondition ?? "Normal"

        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: overview.isPluggedIn ? "battery.100.bolt" : "battery.75")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Power Source: \(overview.powerSourceLabel)")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    if let health {
                        Pill(text: "Health: \(health)%", color: health >= 80 ? .green : .orange)
                    }
                }

                if let cycles {
                    Text("Charge Cycle Count: \(cycles) Cycles (\(condition)) • Power optimized by \(deviceVM.device?.chip ?? "Apple Silicon").")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Battery is in peak condition and dynamically managed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .glassCard(tint: .green, opacity: 0.05)
    }

    private func appScreeningSection(_ apps: [AppUsageScreeningItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frequently Used Apps & Power Impact")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Ranked by estimated daily active hours, disk footprint, and energy consumption.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Picker("Filter", selection: $appFilter) {
                    ForEach(AppFilterOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }

            if apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.fill").font(.title2).foregroundStyle(.secondary)
                    Text("No applications match the selected filter.").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard()
            } else {
                let maxHours = max(1.0, apps.map(\.estimatedDailyHours).max() ?? 1.0)
                ForEach(apps) { item in
                    ScreeningAppRow(item: item, maxHours: maxHours)
                }
            }
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalHours = Int(seconds) / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h \(Int(seconds) % 3600 / 60)m"
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
