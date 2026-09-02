// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Visual list row displaying individual app usage time, inline progress meter,
/// total disk space, and battery impact level.
struct ScreeningAppRow: View {
    let item: AppUsageScreeningItem
    let maxHours: Double

    var body: some View {
        let fraction = min(1.0, max(0.06, item.estimatedDailyHours / max(1.0, maxHours)))

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
