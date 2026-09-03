// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Background Services Monitor — shows all Launch Agents, Launch Daemons,
/// and active background processes, grouped by risk and ownership.
@MainActor
struct BackgroundServicesView: View {
    @ObservedObject var vm: BackgroundServicesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            headerBar
                .padding(16)
                .padding(.bottom, 4)

            Divider().opacity(0.4)

            // ── Summary Cards ──
            summaryRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider().opacity(0.3)

            // ── Filter Bar ──
            filterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider().opacity(0.3)

            // ── Service List ──
            if vm.isScanning && vm.services.isEmpty {
                scanningHero
            } else if vm.filteredServices.isEmpty {
                emptyState
            } else {
                serviceList
                Divider().opacity(0.3)
                pagerBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .onAppear { vm.appear() }
        .onDisappear { vm.disappear() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Background Services")
                    .font(.title3.bold())
                Text("Live monitoring of all Launch Agents, Daemons, and XPC services")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                vm.scanNow()
            } label: {
                HStack(spacing: 5) {
                    if vm.isScanning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(vm.isScanning)
        }
    }

    // MARK: - Summary Cards

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryCard(
                icon: "circle.fill",
                iconColor: .green,
                label: "Running",
                value: "\(vm.totalRunning)"
            )
            summaryCard(
                icon: "person.3.fill",
                iconColor: .blue,
                label: "Third-Party",
                value: "\(vm.thirdPartyCount)"
            )
            summaryCard(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                label: "High-Load",
                value: "\(vm.heavyCount)"
            )
            summaryCard(
                icon: "cpu",
                iconColor: .purple,
                label: "Total CPU",
                value: String(format: "%.1f%%", vm.totalCPU)
            )
            summaryCard(
                icon: "memorychip",
                iconColor: .indigo,
                label: "Total RAM",
                value: ByteFormat.string(vm.totalMemory)
            )
        }
    }

    private func summaryCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(ServiceFilter.allCases, id: \.self) { f in
                Button {
                    vm.filter = f
                } label: {
                    Text(f.rawValue)
                        .font(.caption)
                        .fontWeight(vm.filter == f ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(vm.filter == f ? Color.mint.opacity(0.2) : Color.secondary.opacity(0.08))
                        .foregroundStyle(vm.filter == f ? Color.mint : Color.secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(vm.filteredServices.count) services")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Service List

    private var serviceList: some View {
        ScrollView {
            LazyVStack(spacing: 5) {
                ForEach(vm.pagedServices) { service in
                    BackgroundServiceRow(service: service) {
                        if let url = service.plistURL {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .equatable()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Pager

    private var pagerBar: some View {
        HStack {
            let start = vm.currentPage * vm.pageSize + 1
            let end = min(start + vm.pageSize - 1, vm.filteredServices.count)
            Text("\(start)–\(end) of \(vm.filteredServices.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    vm.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(vm.currentPage == 0)

                Text("Page \(vm.currentPage + 1) of \(vm.totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 90)

                Button {
                    vm.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(vm.currentPage + 1 >= vm.totalPages)
            }
        }
    }

    // MARK: - Placeholders

    private var scanningHero: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.12))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .controlSize(.large)
                    .tint(.mint)
            }
            VStack(spacing: 4) {
                Text("Scanning Background Services…")
                    .font(.headline.bold())
                Text("Reading launchctl, process table, and plist directories…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green.opacity(0.6))
            Text("No services match this filter")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try switching to All or a different filter category.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
