// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

// MARK: - Large Files Tab View

struct LargeFilesView: View {
    @StateObject private var vm = LargeFilesViewModel()
    @State private var pendingTrash: URL?
    @State private var showBatchConfirm = false

    private let sizePresets: [Int] = [100, 250, 500, 1000, 2500, 5000]

    init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Controls: Scope, Threshold & Scan Action
            VStack(alignment: .leading, spacing: 10) {
                // Top Row: Scope, Thresholds & Actions
                HStack(spacing: 10) {
                    // Scope Picker
                    Menu {
                        ForEach(LargeFilesViewModel.ScanScope.allCases) { scope in
                            Button {
                                if scope == .custom {
                                    chooseCustomFolder()
                                } else {
                                    vm.scanScope = scope
                                    vm.send(.rescan)
                                }
                            } label: {
                                Label(scope.rawValue, systemImage: scope.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: vm.scanScope.icon)
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text(vm.scanScope == .custom && vm.customScopeURL != nil ? vm.customScopeURL!.lastPathComponent : vm.scanScope.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassCard()
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Divider().frame(height: 18)

                    // Size Threshold Presets in a scrollable horizontal container
                    Text("Threshold:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sizePresets, id: \.self) { mb in
                                Button {
                                    vm.minMB = mb
                                    vm.send(.rescan)
                                } label: {
                                    Text(presetLabel(for: mb))
                                        .font(.caption2)
                                        .fontWeight(vm.minMB == mb ? .bold : .medium)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(vm.minMB == mb ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.08))
                                        .foregroundStyle(vm.minMB == mb ? Color.purple : Color.primary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(vm.minMB == mb ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // Sort Picker
                    Picker("Sort", selection: $vm.sortOption) {
                        ForEach(LargeFilesViewModel.SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 145)

                    // Scan / Refresh Button
                    Button {
                        vm.send(.rescan)
                    } label: {
                        HStack(spacing: 5) {
                            if vm.isScanning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(vm.isScanning ? "Scanning…" : "Scan Now")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .disabled(vm.isScanning)
                    .fixedSize()
                }

                // Filter & Search Row
                HStack(spacing: 12) {
                    SearchField(placeholder: "Search file name or extension…", text: $vm.searchQuery)
                        .frame(maxWidth: 280)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(FileCategory.allCases, id: \.self) { cat in
                                Button {
                                    vm.selectedCategory = cat
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon).font(.caption2)
                                        Text(cat.rawValue)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
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
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // Category Summary Analytics Bar
            if !vm.categoryBreakdown.isEmpty && !vm.isScanning {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.categoryBreakdown, id: \.category) { item in
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(item.category.color.opacity(0.15))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(item.category.color)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.category.rawValue)
                                        .font(.system(size: 11, weight: .bold))
                                    Text("\(item.count) files • \(ByteFormat.string(item.totalBytes))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassCard(tint: item.category.color, opacity: 0.08)
                            .onTapGesture {
                                vm.selectedCategory = (vm.selectedCategory == item.category ? .all : item.category)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }

            // Status & Batch Actions Bar
            if !vm.filteredFiles.isEmpty && !vm.isScanning {
                HStack {
                    HStack(spacing: 8) {
                        Text("\(vm.filteredFiles.count) Large Files Found")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("• Total: \(ByteFormat.string(vm.totalFilteredBytes))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if vm.totalSelectedBytes > 0 {
                        Button {
                            showBatchConfirm = true
                        } label: {
                            Label("Trash Selected (\(ByteFormat.string(vm.totalSelectedBytes)))", systemImage: "trash.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }

                    Button {
                        vm.send(.toggleSelectAll)
                    } label: {
                        Text(vm.selectedIDs.count == vm.filteredFiles.count ? "Deselect All" : "Select All")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 18)
            }

            // Content Area: Scanning State, Results List, or Empty State
            if vm.isScanning {
                scanningHeroView
            } else if !vm.filteredFiles.isEmpty {
                List(vm.filteredFiles) { file in
                    LargeFileRow(
                        file: file,
                        isSelected: vm.selectedIDs.contains(file.id),
                        onToggleSelect: { vm.send(.toggleSelect(file.id)) },
                        onReveal: { FileActions.reveal(file.url) },
                        onCopyPath: { FileActions.copyPath(file.url) },
                        onTrash: { pendingTrash = file.url }
                    )
                    .equatable()
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.purple.opacity(0.8))
                    Text("No large files found matching your filter.")
                        .font(.headline)
                    Text("Try choosing a lower threshold (e.g. 100 MB) or changing the search scope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
        .confirmationDialog(
            "Move \(vm.selectedIDs.count) Files to Trash (\(ByteFormat.string(vm.totalSelectedBytes)))?",
            isPresented: $showBatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                vm.send(.moveSelectedToTrash)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These items will be moved to macOS Trash and can be restored anytime.")
        }
        .onAppear {
            vm.send(.appear)
        }
    }

    // MARK: - Animated Scanning Hero State

    private var scanningHeroView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .controlSize(.large)
                    .tint(.purple)
            }

            VStack(spacing: 4) {
                Text("Scanning for Files ≥ \(vm.minMB >= 1000 ? "\(vm.minMB / 1000) GB" : "\(vm.minMB) MB")…")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("Searching \(vm.scanScope.rawValue) using fast Spotlight index…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        if panel.runModal() == .OK, let url = panel.url {
            vm.send(.setCustomScope(url))
        }
    }

    private func presetLabel(for mb: Int) -> String {
        mb >= 1000 ? "\(mb / 1000) GB" : "\(mb) MB"
    }
}
