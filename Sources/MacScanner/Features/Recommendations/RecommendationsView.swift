// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

// MARK: - Recommendations Tab View

struct RecommendationsView: View {
    @ObservedObject var vm: RecommendationsViewModel
    @State private var pendingTrash: URL?
    @State private var showBatchConfirm = false

    init(vm: RecommendationsViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reclaim Hero Banner
            heroReclaimBanner

            // Search & Controls Bar
            HStack(spacing: 10) {
                SearchField(placeholder: "Search targets (e.g. docker, xcode, figma)…", text: $vm.searchQuery)
                    .frame(maxWidth: 320)

                Picker("Sort by", selection: $vm.sortOption) {
                    ForEach(RecommendationsViewModel.SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 150)

                Spacer()

                if vm.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scanning targets…").font(.caption).foregroundStyle(.secondary)
                }

                Button {
                    vm.send(.toggleSelectAllSafe)
                } label: {
                    Label("Select All Safe", systemImage: "checklist")
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
            .padding(.horizontal, 18)

            // Category & Risk Filters Row
            VStack(alignment: .leading, spacing: 8) {
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Category:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        filterChip(title: "All Categories", isSelected: vm.selectedCategory == nil, icon: "square.grid.2x2") {
                            vm.selectedCategory = nil
                        }
                        ForEach(RecommendationCategory.allCases, id: \.self) { cat in
                            filterChip(title: cat.rawValue, isSelected: vm.selectedCategory == cat, color: .purple, icon: cat.icon) {
                                vm.selectedCategory = (vm.selectedCategory == cat ? nil : cat)
                            }
                        }
                    }
                }

                // Safety Risks
                HStack(spacing: 6) {
                    Text("Safety:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    filterChip(title: "All Safety Levels", isSelected: vm.selectedRisk == nil) {
                        vm.selectedRisk = nil
                    }
                    ForEach(RiskLevel.allCases, id: \.self) { risk in
                        filterChip(title: risk.rawValue, isSelected: vm.selectedRisk == risk, color: risk.color, icon: risk.icon) {
                            vm.selectedRisk = (vm.selectedRisk == risk ? nil : risk)
                        }
                    }

                    Spacer()

                    Pill(text: "\(vm.filteredResults.count) Targets", color: .secondary)
                }
            }
            .padding(.horizontal, 18)

            // Recommendation Cards List
            if !vm.filteredResults.isEmpty {
                List(vm.filteredResults) { rec in
                    let isSelected = vm.selectedIDs.contains(rec.id)
                    HStack(alignment: .top, spacing: 14) {
                        // Multi-select Checkbox
                        if rec.risk != .manual {
                            Button {
                                if isSelected {
                                    vm.selectedIDs.remove(rec.id)
                                } else {
                                    vm.selectedIDs.insert(rec.id)
                                }
                            } label: {
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
                                .fill(rec.risk.color.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: rec.iconName)
                                .font(.body.bold())
                                .foregroundStyle(rec.risk.color)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(rec.title)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Pill(text: rec.risk.rawValue, color: rec.risk.color, icon: rec.risk.icon)
                                Pill(text: rec.category.rawValue, color: .secondary, icon: rec.category.icon)
                            }
                            Text(rec.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(rec.path.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        // Size & Action Buttons
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(rec.sizeBytes > 0 ? ByteFormat.string(rec.sizeBytes) : "—")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)

                            HStack(spacing: 6) {
                                Button {
                                    FileActions.reveal(rec.path)
                                } label: {
                                    Label("Reveal", systemImage: "arrow.up.forward.app")
                                        .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                if rec.title.contains("Docker Data") {
                                    Button {
                                        vm.send(.dockerSmartPrune)
                                    } label: {
                                        Label("Smart Prune", systemImage: "sparkles")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .controlSize(.mini)
                                } else if rec.title.contains("iOS/Simulator") {
                                    Button {
                                        vm.send(.simulatorCleanUnavailable)
                                    } label: {
                                        Label("Clean Old", systemImage: "sparkles")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.mini)
                                } else if rec.risk != .manual {
                                    Button {
                                        pendingTrash = rec.path
                                    } label: {
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
                        Button("Reveal in Finder") { FileActions.reveal(rec.path) }
                        Button("Copy Path") { FileActions.copyPath(rec.path) }
                        if rec.risk != .manual {
                            Button("Move to Trash", role: .destructive) { pendingTrash = rec.path }
                        }
                    }
                }
                .listStyle(.plain)
            } else if vm.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.green)
                    }
                    VStack(spacing: 6) {
                        Text("Scanning Cleanup Targets & Disk Junk…")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Analyzing Xcode DerivedData, Docker VM storage, simulator runtime caches, user logs, and Trash…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 450)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("No cleanup targets found in this category.")
                        .font(.headline)
                    Text("Your Mac is clean and organized.")
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
            "Clean \(vm.selectedIDs.count) Selected Targets (\(ByteFormat.string(vm.totalSelectedBytes)))?",
            isPresented: $showBatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Move Selected to Trash", role: .destructive) {
                vm.send(.moveSelectedToTrash)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These items will be moved to your Trash. Reversible anytime.")
        }
    }

    private var heroReclaimBanner: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 54, height: 54)
                Image(systemName: "sparkles")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(ByteFormat.string(vm.totalSafeReclaimable))
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("100% Safe to Clean")
                        .font(.headline)
                        .fontWeight(.semibold)

                    if vm.totalCautionReclaimable > 0 {
                        Pill(text: "\(ByteFormat.string(vm.totalCautionReclaimable)) Review First", color: .orange, icon: "exclamationmark.triangle.fill")
                    }
                }
                Text("App & web caches, build artifacts, designer canvas caches, and temp logs. (Docker & Simulator terlindungi oleh Smart Clean).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if vm.totalSelectedBytes > 0 {
                Button {
                    showBatchConfirm = true
                } label: {
                    Label("Clean Selected (\(ByteFormat.string(vm.totalSelectedBytes)))", systemImage: "trash.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
            }
        }
        .padding(18)
        .glassCard(tint: .green, opacity: 0.10)
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private func filterChip(title: String, isSelected: Bool, color: Color = .blue, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
