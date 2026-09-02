// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Detailed inspector pane for an installed application and its associated leftover files.
struct AppUninstallerAppCard: View {
    let app: InstalledAppInfo
    let isDeleting: Bool
    let onUninstall: () -> Void
    let onSelectAll: (Bool) -> Void
    let onToggleItem: (AppLeftoverItem) -> Void
    let onRevealBundle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Bar
            HStack(spacing: 16) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(radius: 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if app.isSystemApp {
                            Pill(text: "System Protected", color: .orange)
                        }
                    }

                    Text("Bundle ID: \(app.bundleID) • Version: \(app.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(app.bundleURL.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: onUninstall) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Uninstall App")
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(app.selectedItemsCount == 0 || isDeleting)
            }
            .padding(14)
            .glassCard()

            // Selection Summary Bar
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Text("Total Size:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.string(app.totalSizeBytes))
                        .font(.caption.bold())
                }

                HStack(spacing: 6) {
                    Text("Selected for Trash:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(ByteFormat.string(app.selectedSizeBytes)) (\(app.selectedItemsCount) items)")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }

                Spacer()

                Button(action: onRevealBundle) {
                    Label("Reveal App in Finder", systemImage: "arrow.up.forward.app")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassCard()

            // Selection Control Toolbar
            HStack {
                Text("Root & Leftover Files Found (\(app.items.count) Components):")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Select All") { onSelectAll(true) }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.blue)

                Text("•").foregroundStyle(.secondary)

                Button("Deselect All") { onSelectAll(false) }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if app.isScanning {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Scanning Library & Sandbox directories…")
                    Spacer()
                }
                Spacer()
            } else if app.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("No hidden leftover files found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // File Items List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(app.items) { item in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { item.isSelected },
                                    set: { _ in onToggleItem(item) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.category.color.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: item.category.icon)
                                        .font(.caption.bold())
                                        .foregroundStyle(item.category.color)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.category.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(.primary)

                                        Pill(text: item.formattedSize, color: item.category.color)
                                    }

                                    Text(item.url.path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button {
                                    FileActions.reveal(item.url)
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                            }
                            .padding(10)
                            .glassCard(tint: item.isSelected ? .blue : .secondary, opacity: item.isSelected ? 0.08 : 0.03)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }
}
