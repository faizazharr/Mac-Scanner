// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// View for Deep Root App Uninstaller.
@MainActor
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
                    VStack(spacing: 16) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 70, height: 70)
                            ProgressView()
                                .controlSize(.large)
                                .tint(.blue)
                        }
                        VStack(spacing: 6) {
                            Text("Scanning Applications…")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Discovering bundles, library leftovers, and sizes…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
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
                AppUninstallerAppCard(
                    app: app,
                    isDeleting: engine.isDeleting,
                    onUninstall: { showConfirmDialog = true },
                    onSelectAll: { engine.selectAllItems($0) },
                    onToggleItem: { engine.toggleItemSelection($0) },
                    onRevealBundle: { FileActions.reveal(app.bundleURL) }
                )
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Select an Application")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Choose an app from the list to scan for leftover caches, logs, and support directories.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
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
