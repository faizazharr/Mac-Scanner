// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts

/// Interactive bar chart comparing application screen duration, power impact, and disk footprint.
struct ScreeningUsageChart: View, Equatable {
    let apps: [AppUsageScreeningItem]
    @Binding var chartMetric: ScreeningView.ChartMetric

    static func == (lhs: ScreeningUsageChart, rhs: ScreeningUsageChart) -> Bool {
        lhs.chartMetric == rhs.chartMetric && lhs.apps.count == rhs.apps.count && lhs.apps.first?.name == rhs.apps.first?.name
    }

    private var chartData: [AppUsageScreeningItem] {
        Array(apps.prefix(7))
    }

    private var totalHours: Double {
        chartData.reduce(0.0) { $0 + $1.estimatedDailyHours }
    }

    private var topApp: String {
        chartData.first?.name ?? "None"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Segmented Metric Control
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.purple)
                        Text("Usage Statistics Chart")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                    Text("Visual comparison of screen duration, power impact, and disk footprint.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Picker("Metric", selection: $chartMetric) {
                    ForEach(ScreeningView.ChartMetric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
            }

            // Summary Badges Row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("🏆 Top App:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(topApp)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.purple)
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
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
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())

                Spacer()
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
        case .hours: return String(format: "%.1fh", value)
        case .battery: return "\(Int(value))%"
        case .size: return ByteFormat.string(item.totalSizeBytes)
        }
    }
}
