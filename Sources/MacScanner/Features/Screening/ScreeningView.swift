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
        case hours = "Jam Layar"
        case battery = "Dampak Baterai"
        case size = "Ukuran Disk"
    }

    enum AppFilterOption: String, CaseIterable {
        case all = "Semua"
        case running = "Sedang Berjalan"
        case heavy = "Dampak Berat"
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
                        ProgressView("Mengumpulkan telemetri penggunaan Mac…")
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
        let topApp = chartData.first?.name ?? "Tidak ada"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.purple)
                        Text("Grafik Statistik Pemakaian")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    Text("Perbandingan visual durasi layar, dampak daya, dan ukuran disk.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("🏆 Terbanyak:")
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

                    Picker("Metrik", selection: $chartMetric) {
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
                        x: .value("Aplikasi", item.name),
                        y: .value("Nilai", value)
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
                Text("Analisis waktu layar, estimasi jam pakai harian, ukuran disk, dan dampak baterai.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                engine.refreshScreening()
            } label: {
                Label("Refresh Telemetri", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func topMetricsGrid(_ overview: MacScreeningOverview) -> some View {
        HStack(spacing: 12) {
            MetricTileComponent(
                title: "Waktu Hidup Mac (Uptime)",
                value: formatUptime(overview.totalUptimeSeconds),
                subLabel: "Sejak dinyalakan pada \(formattedDate(overview.bootDate))",
                icon: "timer",
                color: .blue
            )

            MetricTileComponent(
                title: "Layar Aktif Hari Ini",
                value: String(format: "%.1f Jam", overview.estimatedScreenOnHoursToday),
                subLabel: "Waktu aktif sejak dini hari",
                icon: "laptopcomputer.and.ipad",
                color: .purple
            )

            MetricTileComponent(
                title: "Rata-rata Pemakaian Harian",
                value: String(format: "%.1f Jam / Hari", overview.estimatedDailyAverageHours),
                subLabel: "Berdasarkan durasi sesi MacBook",
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
                    Text("Status Sumber Daya: \(overview.powerSourceLabel)")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    if let health {
                        Pill(text: "Kesehatan: \(health)%", color: health >= 80 ? .green : .orange)
                    }
                }

                if let cycles {
                    Text("Jumlah Siklus Pengisian Daya: \(cycles) Siklus (\(condition)) • Penggunaan daya dioptimalkan oleh \(deviceVM.device?.chip ?? "Apple Silicon").")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Baterai dalam kondisi prima dan diatur secara dinamis.")
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
                    Text("Aplikasi yang Sering Digunakan & Dampak Daya")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Peringkat estimasi jam pakai harian, ukuran disk, dan konsumsi energi baterai.")
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
                    Text("Tidak ada aplikasi yang cocok dengan filter.")
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
                                    Pill(text: "Sedang Berjalan", color: .green)
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
                            Text(String(format: "%.1f Jam / Hari", item.estimatedDailyHours))
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
                                Text("Ukuran Disk")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(ByteFormat.string(item.totalSizeBytes))
                                    .font(.system(size: 11, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 70, alignment: .trailing)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Dampak Baterai")
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
                            .frame(width: 95, alignment: .trailing)
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
            return "\(days) Hari \(hours) Jam"
        }
        return "\(hours) Jam \(Int(seconds) % 3600 / 60) Mnt"
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}
