// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

// MARK: - Metric Tile Component (Object-Oriented Atomic UI)

public struct MetricTileComponent: View {
    public let title: String
    public let value: String
    public let subLabel: String
    public let icon: String
    public let color: Color
    public var tintOpacity: Double = 0.08

    public init(
        title: String,
        value: String,
        subLabel: String,
        icon: String,
        color: Color,
        tintOpacity: Double = 0.08
    ) {
        self.title = title
        self.value = value
        self.subLabel = subLabel
        self.icon = icon
        self.color = color
        self.tintOpacity = tintOpacity
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(subLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: color, opacity: tintOpacity)
    }
}

// MARK: - Section Header Component

public struct SectionHeaderComponent<TrailingView: View>: View {
    public let title: String
    public let subtitle: String
    public var statusDotColor: Color? = nil
    @ViewBuilder public var trailing: () -> TrailingView

    public init(
        title: String,
        subtitle: String,
        statusDotColor: Color? = nil,
        @ViewBuilder trailing: @escaping () -> TrailingView = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusDotColor = statusDotColor
        self.trailing = trailing
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let dotColor = statusDotColor {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(dotColor.opacity(0.4), lineWidth: 3))
                    }
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing()
        }
    }
}

// MARK: - Filter Segment Component

public struct FilterSegmentComponent<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    public let title: String
    public let options: [T]
    @Binding public var selection: T
    public var width: CGFloat = 260

    public init(
        title: String = "Filter",
        options: [T],
        selection: Binding<T>,
        width: CGFloat = 260
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.width = width
    }

    public var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { opt in
                Text(opt.rawValue).tag(opt)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: width)
    }
}
