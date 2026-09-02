// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Single file row in the Large Files list with selection, path truncation, size badge, and context actions.
struct LargeFileRow: View, Equatable {
    let file: FileEntry
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void
    let onTrash: () -> Void

    nonisolated static func == (lhs: LargeFileRow, rhs: LargeFileRow) -> Bool {
        if lhs.file.id != rhs.file.id { return false }
        if lhs.isSelected != rhs.isSelected { return false }
        return lhs.file.sizeBytes == rhs.file.sizeBytes
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.purple : Color.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(file.category.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: file.category.icon)
                    .font(.caption.bold())
                    .foregroundStyle(file.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.url.deletingLastPathComponent().path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Pill(text: file.url.pathExtension.isEmpty ? "FILE" : file.url.pathExtension.uppercased(), color: file.category.color)

            Text(file.sizeString)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .frame(width: 90, alignment: .trailing)

            HStack(spacing: 6) {
                Button(action: onReveal) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Move to Trash")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            Button("Copy Full Path", action: onCopyPath)
            Divider()
            Button("Move to Trash", role: .destructive, action: onTrash)
        }
    }
}
