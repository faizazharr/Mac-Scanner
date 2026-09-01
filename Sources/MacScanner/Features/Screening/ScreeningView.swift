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
                    // 1. Top Metric Tiles
                    topMetricsGrid(overview)

                    // 2. Compact & Highly Informative Swift Charts Bar Chart
                    usageStatisticsChartSection(overview.topAppsByUsage)

                    // 3. Battery & Power Status Card
                    batteryPowerBanner(overview)

                    // 4. App Screening & Usage Ranking
                    appScreeningSection(filteredApps)
                }
            }
            .padding(20)
        }
        .onAppear {
            deviceVM.send(.appearIfNeeded)
        }
    }

    // MARK: - Compact & Informative Swift Charts Section

    private func usageStatisticsChartSection(_ apps: [AppUsageScreeningItem]) -> some View {
        let chartData = Array(apps.prefix(7))
        let totalHours = chartData.reduce(0.0) { $0 + $1.estimatedDailyHours }
        let topApp = chartData.first?.name ?? "None"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.purple)
                        Text("Usage Statistics Chart")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Text("Visual comparison of screen duration, power impact, and disk footprint.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("🏆 Top App:")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(topApp)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.purple)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Capsule())

                    HStack(spacing: 4) {
                        Text("⏱️ Total:")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fh", totalHours))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())

                    Picker("Metric", selection: $chartMetric) {
                        ForEach(ChartMetric.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
            }

            Chart {
                ForEach(chartData) { item in
                    let value: Double = {
                        switch chartMetric {
                        case .hours: return item.estimatedDailyHours
                        case .battery: return item.batteryPercentageImpact
                        case .size: return Double(item.totalSizeBytes) / Double(1024 * 1024 * 1024)
                        }
                    }()

                    let barColor: Color = {
                        switch chartMetric {
                        case .hours: return item.isRunning ? .purple : .blue
                        case .battery: return item.batteryImpactLevel.color
                        case .size: return .cyan
                        }
                    }()

                    BarMark(
                        x: .value("App", item.name),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barColor.opacity(0.6), barColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text(chartValueString(for: item, value: value))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                        .font(.system(size: 8))
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel()
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .frame(height: 125)
        }
        .padding(12)
        .glassCard(tint: .purple, opacity: 0.05)
    }

    private func chartValueString(for item: AppUsageScreeningItem, value: Double) -> String {
        switch chartMetric {
        case .hours:
            return String(format: "%.1fh", value)
        case .battery:
            return "\(Int(value))%"
        case .size:
            return ByteFormat.string(item.totalSizeBytes)
        }
    }

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
        HStack(spacing: 12) {
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
                .frame(width: 260)
            }

            if apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No applications match the selected filter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard()
            } else {
                let maxHours = max(1.0, apps.map(\.estimatedDailyHours).max() ?? 1.0)

                ForEach(apps) { item in
                    let fraction = min(1.0, max(0.06, item.estimatedDailyHours / maxHours))

                    HStack(spacing: 12) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                if item.isRunning {
                                    Pill(text: "Running", color: .green)
                                }
                            }

                            Text(item.explanation)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Inline Visual Progress Meter
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "%.1f hrs / day", item.estimatedDailyHours))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(item.isRunning ? Color.purple : Color.blue)

                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 84, height: 5)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: item.isRunning ? [.purple, .indigo] : [.blue, .cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 84 * CGFloat(fraction), height: 5)
                            }
                        }
                        .frame(width: 95, alignment: .trailing)

                        // Metrics (Size & Battery)
                        HStack(spacing: 18) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Disk Size")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(ByteFormat.string(item.totalSizeBytes))
                                    .font(.system(size: 11, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 70, alignment: .trailing)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Battery Impact")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                HStack(spacing: 4) {
                                    Image(systemName: item.batteryImpactLevel.icon)
                                        .font(.system(size: 10))
                                    Text(item.batteryImpactLevel.rawValue)
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(item.batteryImpactLevel.color)
                            }
                            .frame(width: 105, alignment: .trailing)
                        }
                    }
                    .padding(12)
                    .glassCard(tint: item.isRunning ? .purple : .secondary, opacity: item.isRunning ? 0.08 : 0.03)
                }
            }
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalHours = Int(seconds) / 3600
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h \(Int(seconds) % 3600 / 60)m"
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
