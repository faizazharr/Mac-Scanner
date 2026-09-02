// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Detailed inspector pane for an installed application and its associated leftover files.
///
/// Displays the app icon, metadata, a selection summary bar, and a lazy
/// list of leftover file components with per-item toggle, size badge, and reveal action.
@MainActor
struct AppUninstallerAppCard: View {
    let app: InstalledAppInfo
    let isDeleting: Bool
    let onUninstall: () -> Void
    let onSelectAll: (Bool) -> Void
    let onToggleItem: (AppLeftoverItem) -> Void
    let onRevealBundle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            appHeaderBar
            selectionSummaryBar
            fileListSection
        }
        .padding(16)
    }

    // MARK: - App Header

    private var appHeaderBar: some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if app.isSystemApp {
                        Pill(text: "System", color: .orange)
                    }
                }

                Text("Bundle ID: \(app.bundleID)  •  Version: \(app.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(app.bundleURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onUninstall) {
                if isDeleting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(.white)
                        Text("Removing…")
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Uninstall App")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.regular)
            .fontWeight(.semibold)
            .disabled(app.selectedItemsCount == 0 || isDeleting)
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .padding(.bottom, 10)
    }

    // MARK: - Selection Summary Bar

    private var selectionSummaryBar: some View {
        HStack(spacing: 0) {
            statBlock(
                label: "Total Size",
                value: ByteFormat.string(app.totalSizeBytes),
                color: .primary
            )
            Divider().frame(height: 28).padding(.horizontal, 14).opacity(0.3)
            statBlock(
                label: "Selected for Trash",
                value: "\(ByteFormat.string(app.selectedSizeBytes))  (\(app.selectedItemsCount) items)",
                color: .blue
            )
            Spacer()
            Button(action: onRevealBundle) {
                Label("Reveal in Finder", systemImage: "arrow.up.forward.app")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
        )
        .padding(.bottom, 12)
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }

    // MARK: - File List Section

    private var fileListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Leftover Components (\(app.items.count))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button("Select All") { onSelectAll(true) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("·").foregroundStyle(.quaternary)
                    Button("Deselect All") { onSelectAll(false) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)

            if app.isScanning {
                scanningPlaceholder
            } else if app.items.isEmpty {
                cleanPlaceholder
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(app.items) { item in
                            leftoverItemRow(item)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }

    private func leftoverItemRow(_ item: AppLeftoverItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in onToggleItem(item) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.category.color.opacity(0.13))
                    .frame(width: 32, height: 32)
                Image(systemName: item.category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.category.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.category.rawValue)
                        .font(.caption.bold())
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
                Image(systemName: "folder.badge.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.isSelected ? Color.blue.opacity(0.07) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    item.isSelected ? Color.blue.opacity(0.22) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: item.isSelected)
    }

    // MARK: - Placeholders

    private var scanningPlaceholder: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().controlSize(.large).tint(.blue)
            Text("Scanning Library & Sandbox directories…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var cleanPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No leftover files found")
                .font(.subheadline.bold())
            Text("This application leaves no detectable traces in Library folders.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
