// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

// MARK: - Browser Tab View

@MainActor
struct BrowserView: View {
    @StateObject private var vm = BrowserViewModel()
    @State private var pendingTrash: URL?
    @State private var hoveredEntryID: UUID?

    init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Action Toolbar & Breadcrumbs
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        vm.send(.navigateUp)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(vm.currentDirectory.path == "/")
                    .help("Go up one directory level")

                    Button {
                        vm.send(.navigate(to: FileManager.default.homeDirectoryForCurrentUser))
                    } label: {
                        Image(systemName: "house.fill")
                    }
                    .help("Go to Home folder")

                    breadcrumbBar

                    Spacer()

                    Button {
                        chooseFolder()
                    } label: {
                        Label("Choose Folder…", systemImage: "folder.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        vm.send(.rescan)
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Volume Usage & Scan Status
                if vm.volumeTotal > 0 {
                    let used = vm.volumeTotal - vm.volumeFree
                    HStack {
                        Text("Volume Capacity: \(ByteFormat.string(used)) used / \(ByteFormat.string(vm.volumeFree)) free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if vm.isScanning {
                            ProgressView().controlSize(.small)
                            Text("Calculating folder sizes…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            // Visual Size Donut Breakdown
            if !vm.entries.isEmpty {
                SizeDonutChart(entries: vm.entries)
                    .padding(.horizontal, 18)
            }

            // Search & Category Filters
            HStack(spacing: 12) {
                SearchField(placeholder: "Search items in this directory…", text: $vm.searchQuery)
                    .frame(maxWidth: 320)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FileCategory.allCases, id: \.self) { cat in
                            Button {
                                vm.selectedCategory = cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text(cat.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    vm.selectedCategory == cat
                                        ? cat.color.opacity(0.2)
                                        : Color.secondary.opacity(0.08)
                                )
                                .foregroundStyle(vm.selectedCategory == cat ? cat.color : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(vm.selectedCategory == cat ? cat.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)

            // Items List
            if !vm.filteredEntries.isEmpty {
                let maxSize = vm.filteredEntries.map(\.sizeBytes).max() ?? 1
                List(vm.filteredEntries) { entry in
                    let isHovered = hoveredEntryID == entry.id
                    HStack(spacing: 12) {
                        // Category Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(entry.category.color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: entry.isDirectory ? "folder.fill" : entry.category.icon)
                                .font(.caption.bold())
                                .foregroundStyle(entry.category.color)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(entry.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                if entry.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(entry.isDirectory ? "Folder" : entry.category.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Proportional Gradient Size Bar
                        let barWidth = 110 * CGFloat(entry.sizeBytes) / CGFloat(maxSize)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 110, height: 7)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [entry.category.color.opacity(0.7), entry.category.color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(barWidth, 3), height: 7)
                        }
                        .frame(width: 110, height: 7)

                        Text(entry.sizeString)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(width: 95, alignment: .trailing)

                        // Quick Actions on Hover
                        HStack(spacing: 4) {
                            Button {
                                FileActions.reveal(entry.url)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button {
                                FileActions.copyPath(entry.url)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Copy Path")

                            Button {
                                pendingTrash = entry.url
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Move to Trash")
                        }
                        .opacity(isHovered ? 1.0 : 0.25)
                        .frame(width: 75)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onHover { hoveredEntryID = $0 ? entry.id : nil }
                    .onTapGesture { open(entry) }
                    .contextMenu {
                        if entry.isDirectory {
                            Button("Open Folder") { open(entry) }
                        }
                        Button("Reveal in Finder") { FileActions.reveal(entry.url) }
                        Button("Copy Full Path") { FileActions.copyPath(entry.url) }
                        Divider()
                        Button("Move to Trash", role: .destructive) { pendingTrash = entry.url }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else if vm.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.blue)
                    }
                    VStack(spacing: 6) {
                        Text("Analyzing Folder Contents…")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Computing directory sizes and calculating storage breakdowns…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(vm.searchQuery.isEmpty ? "No items found in this directory." : "No matches found for \"\(vm.searchQuery)\".")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
        .onAppear { vm.send(.appear) }
    }

    private func open(_ entry: FileEntry) {
        guard entry.isDirectory else { return }
        vm.send(.navigate(to: entry.url))
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(vm.pathChain, id: \.self) { url in
                    let isCurrent = url.path == vm.currentDirectory.path
                    Button {
                        vm.send(.navigate(to: url))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: url.path == "/" ? "internaldrive" : "folder")
                                .font(.caption2)
                            Text(url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent)
                                .font(.caption)
                                .fontWeight(isCurrent ? .bold : .medium)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isCurrent ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrent)

                    if url.path != vm.pathChain.last?.path {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.send(.navigate(to: url))
        }
    }
}
