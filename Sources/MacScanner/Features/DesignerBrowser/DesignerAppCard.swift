// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Visual card component displaying individual creative design app caches (Figma, Adobe, Sketch).
///
/// Features plain-language explanations of disk bloat and direct single-click
/// reversible trash cleanup actions.
struct DesignerAppCard: View {
    let item: DesignAppCacheInfo
    let onClean: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.title3.bold())
                    .foregroundStyle(Color.pink)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.appName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if item.exists {
                        Pill(text: item.category, color: .pink)
                    }
                }

                Text(item.explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(item.path.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(ByteFormat.string(item.sizeBytes))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(item.sizeBytes > 500 * 1024 * 1024 ? Color.pink : Color.primary)

                if item.sizeBytes > 0 {
                    Button {
                        onClean()
                    } label: {
                        Label("Clean", systemImage: "trash")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .glassCard(tint: .pink, opacity: 0.05)
    }
}
