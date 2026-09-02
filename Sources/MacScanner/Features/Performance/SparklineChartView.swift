// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts

/// Real-time multi-metric activity sparkline chart utilizing native Swift Charts.
///
/// Smoothly plots CPU and Memory percentage histories with Catmull-Rom spline interpolation
/// and subtle gradient area fills.
struct SparklineChartView: View, Equatable {
    let history: [PerformanceHistoryPoint]

    static func == (lhs: SparklineChartView, rhs: SparklineChartView) -> Bool {
        lhs.history.count == rhs.history.count && lhs.history.last?.timestamp == rhs.history.last?.timestamp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Realtime Activity Trends", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.cyan).frame(width: 7, height: 7)
                        Text("CPU %").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.purple).frame(width: 7, height: 7)
                        Text("RAM %").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Chart(history) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Color.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.2), Color.cyan.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Memory", point.memoryPercent),
                    series: .value("Metric", "RAM")
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)%").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .padding(14)
        .glassCard()
    }
}
