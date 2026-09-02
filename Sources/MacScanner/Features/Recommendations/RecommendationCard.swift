// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Single actionable smart recommendation card with safety badge, path inspection, and cleanup action buttons.
struct RecommendationCard: View, Equatable {
    let item: Recommendation
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onAction: () -> Void

    static func == (lhs: RecommendationCard, rhs: RecommendationCard) -> Bool {
        if lhs.item.id != rhs.item.id { return false }
        if lhs.isSelected != rhs.isSelected { return false }
        return lhs.item.sizeBytes == rhs.item.sizeBytes
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Multi-select Checkbox
            if item.risk != .manual {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(width: 22)
                    .padding(.top, 2)
            }

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.risk.color.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: item.iconName)
                    .font(.body.bold())
                    .foregroundStyle(item.risk.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Pill(text: item.risk.rawValue, color: item.risk.color, icon: item.risk.icon)
                    Pill(text: item.category.rawValue, color: .secondary, icon: item.category.icon)
                }
                Text(item.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Size & Action Buttons
            VStack(alignment: .trailing, spacing: 6) {
                Text(item.sizeBytes > 0 ? ByteFormat.string(item.sizeBytes) : "—")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)

                HStack(spacing: 6) {
                    Button(action: onReveal) {
                        Label("Reveal", systemImage: "arrow.up.forward.app")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    if item.title.contains("Docker Data") {
                        Button(action: onAction) {
                            Label("Smart Prune", systemImage: "sparkles")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.mini)
                    } else if item.title.contains("iOS/Simulator") {
                        Button(action: onAction) {
                            Label("Clean Old", systemImage: "sparkles")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.mini)
                    } else if item.risk != .manual {
                        Button(action: onAction) {
                            Label("Trash", systemImage: "trash")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.mini)
                    }
                }
            }
        }
        .padding(10)
        .glassCard(tint: isSelected ? .green : .secondary, opacity: isSelected ? 0.12 : 0.05)
        .listRowSeparator(.hidden)
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            Button("Copy Full Path", action: onCopyPath)
        }
    }
}
