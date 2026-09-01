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
        case size = "Ukuran"
        case name = "Nama"
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
                        Text("\(engine.installedApps.count) Aplikasi Terinstal")
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
                        TextField("Cari aplikasi…", text: $engine.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Picker("Urutkan", selection: $sortOption) {
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
                        ProgressView("Memindai ukuran & file sisa…")
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
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(app.name)
                                        .font(.subheadline)
                                        .fontWeight(engine.selectedApp?.id == app.id ? .bold : .medium)
                                        .lineLimit(1)

                                    if app.isSystemApp {
                                        Pill(text: "System", color: .secondary)
                                    }
                                }

                                Text("v\(app.version)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Text(ByteFormat.string(app.totalSizeBytes))
                                .font(.system(size: 11, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(app.totalSizeBytes >= 1024 * 1024 * 1024 ? .blue : .secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .tag(app.id)
                        .onTapGesture {
                            engine.selectApp(app)
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(width: 310)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            Divider()

            // Right Pane: Deep Root Breakdown & Clean
            if let app = engine.selectedApp {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Bar
                    HStack(spacing: 14) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(app.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Pill(text: "v\(app.version)", color: .blue)
                                if app.isSystemApp {
                                    Pill(text: "Dilindungi Sistem", color: .orange)
                                }
                            }

                            Text(app.bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Text("Total Ukuran Bersih: \(ByteFormat.string(app.totalSizeBytes)) • Terpilih: \(ByteFormat.string(app.selectedSizeBytes))")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        if !app.isSystemApp {
                            Button {
                                showConfirmDialog = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Uninstall Bersih (\(ByteFormat.string(app.selectedSizeBytes)))")
                                }
                                .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(app.selectedItemsCount == 0 || engine.isDeleting)
                        }
                    }
                    .padding(16)
                    .glassCard()

                    // Selection Control Toolbar
                    HStack {
                        Text("Akar & Sisa File Ditemukan (\(app.items.count) Komponen):")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Pilih Semua") {
                            engine.selectAllItems(true)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.blue)

                        Text("•").foregroundStyle(.secondary)

                        Button("Batal Pilih") {
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
                            ProgressView("Memindai direktori Library & Sandbox…")
                            Spacer()
                        }
                        Spacer()
                    } else if app.items.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("Tidak ada file sisa tersembunyi.")
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
                                        .help("Buka di Finder")
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
                    Text("Pilih aplikasi dari daftar di sebelah kiri untuk melihat rincian akar filenya.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog(
            "Copot & Pindahkan ke Trash?",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Pindahkan \(engine.selectedApp?.name ?? "Aplikasi") ke Trash", role: .destructive) {
                engine.uninstallSelectedApp()
            }
            Button("Batal", role: .cancel) { }
        } message: {
            Text("Seluruh file utama beserta folder Application Support, Caches, dan Preferences yang dipilih akan dipindahkan ke Trash. Anda tetap dapat mengembalikannya dari Keranjang Sampah macOS jika diperlukan.")
        }
    }
}
