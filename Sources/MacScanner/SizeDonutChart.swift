// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts

/// One wedge of `SizeDonutChart`.
struct ChartSlice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let bytes: Int64
    let percent: Double
    let color: Color
}

/// Percentage breakdown of a folder's children as a rich donut chart.
struct SizeDonutChart: View {
    let entries: [FileEntry]

    @State private var selectedSliceID: UUID?
    private let maxSlices = 6
    private let palette: [Color] = [
        .blue, .purple, .pink, .orange, .cyan, .green, .indigo, .secondary
    ]

    private var slices: [ChartSlice] {
        let total = entries.reduce(0) { $0 + $1.sizeBytes }
        guard total > 0 else { return [] }
        let sorted = entries.sorted { $0.sizeBytes > $1.sizeBytes }
        let top = sorted.prefix(maxSlices)
        let restBytes = sorted.dropFirst(maxSlices).reduce(0) { $0 + $1.sizeBytes }

        var result: [ChartSlice] = []
        for (index, entry) in top.enumerated() {
            result.append(
                ChartSlice(
                    name: entry.name,
                    bytes: entry.sizeBytes,
                    percent: Double(entry.sizeBytes) / Double(total) * 100,
                    color: palette[index % palette.count]
                )
            )
        }

        if restBytes > 0 {
            result.append(
                ChartSlice(
                    name: "Others (\(sorted.count - maxSlices))",
                    bytes: restBytes,
                    percent: Double(restBytes) / Double(total) * 100,
                    color: palette.last ?? .secondary
                )
            )
        }
        return result
    }

    private var activeSlice: ChartSlice? {
        if let id = selectedSliceID, let slice = slices.first(where: { $0.id == id }) {
            return slice
        }
        return slices.first
    }

    var body: some View {
        if !slices.isEmpty {
            HStack(alignment: .center, spacing: 24) {
                // Donut Chart with Center Data Callout
                ZStack {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Size", slice.bytes),
                            innerRadius: .ratio(0.68),
                            angularInset: 2.0
                        )
                        .foregroundStyle(slice.color)
                        .cornerRadius(4)
                        .opacity(selectedSliceID == nil || selectedSliceID == slice.id ? 1.0 : 0.45)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 140, height: 140)

                    // Center Inspection
                    if let active = activeSlice {
                        VStack(spacing: 2) {
                            Text("\(Int(active.percent.rounded()))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(ByteFormat.string(active.bytes))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                    }
                }

                // Legend List
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices) { slice in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedSliceID == slice.id {
                                    selectedSliceID = nil
                                } else {
                                    selectedSliceID = slice.id
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 8, height: 8)
                                Text(slice.name)
                                    .font(.caption)
                                    .fontWeight(selectedSliceID == slice.id ? .bold : .regular)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(ByteFormat.string(slice.bytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("(\(Int(slice.percent.rounded()))%)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 38, alignment: .trailing)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedSliceID == slice.id ? slice.color.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .glassCard()
        }
    }
}
