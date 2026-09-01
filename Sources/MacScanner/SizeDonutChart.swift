// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts

/// One wedge of `SizeDonutChart`.
struct ChartSlice: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int64
    let percent: Double
}

/// Percentage breakdown of a folder's children as a donut chart — top slices
/// individually, everything past that grouped into "Others" so it stays readable.
struct SizeDonutChart: View {
    let entries: [FileEntry]

    private let maxSlices = 6
    private let palette: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green, .secondary]

    private var slices: [ChartSlice] {
        let total = entries.reduce(0) { $0 + $1.sizeBytes }
        guard total > 0 else { return [] }
        let sorted = entries.sorted { $0.sizeBytes > $1.sizeBytes }
        let top = sorted.prefix(maxSlices)
        let restBytes = sorted.dropFirst(maxSlices).reduce(0) { $0 + $1.sizeBytes }

        var result = top.map {
            ChartSlice(name: $0.name, bytes: $0.sizeBytes, percent: Double($0.sizeBytes) / Double(total) * 100)
        }
        if restBytes > 0 {
            result.append(ChartSlice(name: "Others", bytes: restBytes, percent: Double(restBytes) / Double(total) * 100))
        }
        return result
    }

    var body: some View {
        if !slices.isEmpty {
            HStack(alignment: .center, spacing: 20) {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Size", slice.bytes), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(by: .value("Name", slice.name))
                        .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: slices.map(\.name), range: palette)
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(palette[index % palette.count])
                                .frame(width: 8, height: 8)
                            Text(slice.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(ByteFormat.string(slice.bytes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: 260, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }
}
