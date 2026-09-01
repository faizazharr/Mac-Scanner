// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// View for Deep Root App Uninstaller.
struct AppUninstallerView: View {
    @StateObject private var engine = AppUninstallerEngine()
    @State private var showConfirmDialog = false
    @State private var sortOption: AppSortOption = .size

    enum AppSortOption: String, CaseIterable {
        case size = "Size"
        case name = "Name"
    }

    var filteredApps: [InstalledAppInfo] {
        var list = engine.installedApps
        if !engine.searchQuery.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(engine.searchQuery) ||
                $0.bundleID.localizedCaseInsensitiveContains(engine.searchQuery)
            }
        }
        if sortOption == .size {
            list.sort { $0.totalSizeBytes > $1.totalSizeBytes }
        } else {
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Pane: Installed Apps List
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Uninstaller")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("\(engine.installedApps.count) Installed Applications")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        engine.loadInstalledApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Search Bar & Sort Picker
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextField("Search applications…", text: $engine.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Picker("Sort", selection: $sortOption) {
                        ForEach(AppSortOption.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)

                Divider().opacity(0.4)

                if engine.isLoadingApps {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView("Scanning sizes & leftovers…")
                            .font(.caption)
                        Spacer()
                    }
                    Spacer()
                } else {
                    List(filteredApps, selection: Binding(
                        get: { engine.selectedApp?.id },
                        set: { newID in
                            if let found = engine.installedApps.first(where: { $0.id == newID }) {
                                engine.selectApp(found)
                            }
                        }
                    )) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(app.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)

                                    if app.isSystemApp {
                                        Text("System")
                                            .font(.system(size: 9))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(app.bundleID)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(ByteFormat.string(app.totalSizeBytes))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .tag(app.id)
                        .padding(.vertical, 2)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(width: 280)
            .background(Color.primary.opacity(0.02))

            Divider().opacity(0.5)

            // Right Pane: Deep Leftover Breakdown & Actions
            if let app = engine.selectedApp {
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

                        Button {
                            showConfirmDialog = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Uninstall App")
                            }
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.regular)
                        .disabled(app.selectedItemsCount == 0 || engine.isDeleting)
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

                        Button {
                            FileActions.reveal(app.bundleURL)
                        } label: {
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

                        Button("Select All") {
                            engine.selectAllItems(true)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)

                        Text("•").foregroundStyle(.secondary)

                        Button("Deselect All") {
                            engine.selectAllItems(false)
                        }
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
                                            set: { _ in engine.toggleItemSelection(item) }
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
                                    .glassCard(tint: item.isSelected ? item.category.color : .secondary, opacity: item.isSelected ? 0.08 : 0.03)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Select an application from the list on the left to inspect its root files.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Uninstall & Move to Trash?",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Move \(engine.selectedApp?.name ?? "App") to Trash", role: .destructive) {
                engine.uninstallSelectedApp()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All selected main application bundles, Application Support, Caches, and Preferences will be safely moved to the Trash. You can restore them anytime from macOS Trash if needed.")
        }
    }
}
