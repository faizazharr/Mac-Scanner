// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Macintosh HD storage overview card with dynamic gauge, linear gradient bar, and folder exploration trigger.
struct StorageBreakdownCard: View, Equatable {
    let volumeTotal: Int64
    let volumeFree: Int64
    let onExploreFolders: () -> Void

    static func == (lhs: StorageBreakdownCard, rhs: StorageBreakdownCard) -> Bool {
        lhs.volumeTotal == rhs.volumeTotal && lhs.volumeFree == rhs.volumeFree
    }

    var body: some View {
        let used = volumeTotal - volumeFree
        let fraction = volumeTotal > 0 ? Double(used) / Double(volumeTotal) : 0
        let isCritical = fraction >= 0.90
        let isWarning = fraction >= 0.75

        HStack(spacing: 24) {
            StorageRingGauge(usedBytes: used, totalBytes: volumeTotal, freeBytes: volumeFree, size: 110, lineWidth: 11)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Macintosh HD Storage")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(ByteFormat.string(used)) used out of \(ByteFormat.string(volumeTotal)) total space")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isCritical {
                        Pill(text: "Storage Almost Full", color: .red, icon: "exclamationmark.triangle.fill")
                    } else if isWarning {
                        Pill(text: "Storage Filling Up", color: .orange, icon: "exclamationmark.circle.fill")
                    } else {
                        Pill(text: "Storage Healthy", color: .green, icon: "checkmark.shield.fill")
                    }
                }

                // Storage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isCritical ? [.orange, .red] : isWarning ? [.yellow, .orange] : [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(fraction)), height: 10)
                    }
                }
                .frame(height: 10)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Used: \(ByteFormat.string(used))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                        Text("Free: \(ByteFormat.string(volumeFree))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onExploreFolders) {
                        Label("Explore Folders", systemImage: "folder.badge.gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(18)
        .glassCard(tint: isCritical ? .red : isWarning ? .orange : .blue, opacity: 0.08)
    }
}
