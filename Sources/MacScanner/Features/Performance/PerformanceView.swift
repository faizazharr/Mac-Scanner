// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Performance tab: Live system telemetry gauges, activity sparklines,
/// actionable recommendations, and the Interactive Root-Cause Inspector.
struct PerformanceView: View {
    @ObservedObject var vm: PerformanceViewModel
    @ObservedObject var deviceVM: DeviceInfoViewModel

    @State private var pendingKillPID: (pid: Int32, name: String)?
    @State private var pendingCleanCache: (url: URL, appName: String)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let snapshot = vm.snapshot {
                    // Gauges Grid
                    gaugesRow(snapshot)

                    // Sparkline Charts
                    if vm.history.count >= 2 {
                        SparklineChartView(history: vm.history)
                    }

                    // Recommendations & Diagnostics
                    if !vm.stableRecommendations.isEmpty {
                        recommendationsSection(vm.stableRecommendations)
                    }

                    // Interactive Root-Cause Inspector (Anatomy Breakdown)
                    if let inspected = vm.inspectedApp {
                        RootCauseInspectorCard(
                            app: inspected,
                            vm: vm,
                            pendingKillPID: $pendingKillPID,
                            pendingCleanCache: $pendingCleanCache
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Heaviest User Apps (Clickable to Inspect)
                    let userApps = vm.heaviestAppsThisSession.filter { !$0.isSystemDaemon }
                    if !userApps.isEmpty {
                        heaviestAppsSection(userApps)
                    }

                    // All Active Processes Table
                    ProcessListView(
                        processes: snapshot.topProcesses,
                        vm: vm,
                        pendingKillPID: $pendingKillPID
                    )
                } else {
                    HStack {
                        Spacer()
                        ProgressView("Reading live system telemetry…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                    .glassCard()
                }
            }
            .padding(20)
        }
        .animation(.easeInOut(duration: 0.25), value: vm.inspectedApp?.appName)
        .confirmationDialog(
            "Terminate \(pendingKillPID?.name ?? "Process")?",
            isPresented: Binding(
                get: { pendingKillPID != nil },
                set: { if !$0 { pendingKillPID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Force Quit Process", role: .destructive) {
                if let target = pendingKillPID {
                    vm.send(.terminate(pid: target.pid, name: target.name))
                }
                pendingKillPID = nil
            }
            Button("Cancel", role: .cancel) { pendingKillPID = nil }
        } message: {
            Text("This terminates the process immediately via SIGTERM.")
        }
        .confirmationDialog(
            "Clear \(pendingCleanCache?.appName ?? "App") Disk Cache?",
            isPresented: Binding(
                get: { pendingCleanCache != nil },
                set: { if !$0 { pendingCleanCache = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move Cache to Trash", role: .destructive) {
                if let target = pendingCleanCache {
                    vm.send(.cleanAppCache(target.url, target.appName))
                }
                pendingCleanCache = nil
            }
            Button("Cancel", role: .cancel) { pendingCleanCache = nil }
        } message: {
            Text("Temporary cache files will be moved to Trash. Login credentials and bookmarks are never affected.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.green.opacity(0.4), lineWidth: 3))
                Text("Live System Performance")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            Text("Polling every 4s")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                vm.send(.refreshNow)
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Gauges Row

    private func gaugesRow(_ snapshot: PerformanceMonitor.Snapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
            GaugeCard(
                title: "Memory", icon: "memorychip.fill",
                valueLabel: "\(Int(snapshot.memory.usedFraction * 100))%",
                subLabel: "\(ByteFormat.string(snapshot.memory.usedBytes)) of \(ByteFormat.string(snapshot.memory.totalBytes))",
                fraction: snapshot.memory.usedFraction, risk: snapshot.memoryRisk, redLineFraction: 0.90
            )
            GaugeCard(
                title: "CPU Load", icon: "cpu.fill",
                valueLabel: "\(Int(snapshot.cpuPercent))%",
                subLabel: "System + User busy",
                fraction: snapshot.cpuPercent / 100, risk: snapshot.cpuRisk, redLineFraction: 0.85
            )
            if let gpuPercent = snapshot.gpuPercent {
                GaugeCard(
                    title: "GPU Load", icon: "square.stack.3d.up.fill",
                    valueLabel: "\(Int(gpuPercent))%",
                    subLabel: "Accelerator load",
                    fraction: gpuPercent / 100, risk: snapshot.gpuRisk, redLineFraction: 0.90
                )
            }
            GaugeCard(
                title: "Swap File", icon: "arrow.left.arrow.right",
                valueLabel: ByteFormat.string(snapshot.swap.usedBytes),
                subLabel: "of \(ByteFormat.string(snapshot.swap.totalBytes)) swap total",
                fraction: snapshot.swap.totalBytes > 0
                    ? Double(snapshot.swap.usedBytes) / Double(snapshot.swap.totalBytes) : 0,
                risk: snapshot.swapRisk, redLineFraction: nil
            )
            ThermalCard(state: snapshot.thermalState, risk: snapshot.thermalRisk)
        }
    }

    // MARK: - Recommendations

    private func recommendationsSection(_ recommendations: [PerformanceRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Performance Diagnostics & Advisory", systemImage: "checklist.checked")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            ForEach(recommendations) { rec in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(color(for: rec.risk))
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: rec.icon)
                                .font(.caption.bold())
                                .foregroundStyle(color(for: rec.risk))
                            Text(rec.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Pill(text: rec.statusLabel, color: color(for: rec.risk))
                        }
                        Text(rec.advice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if rec.id != recommendations.last?.id {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Heaviest Apps (Interactive Selection)

    private func heaviestAppsSection(_ apps: [AppImpactRecord]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apps & High-Impact Processes (Click to Inspect)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Ranked by cumulative CPU and RAM consumption during this session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Pill(text: "\(apps.count) Active Processes", color: .orange)
            }

            ForEach(apps) { app in
                let info = AppInspector.friendlyInfo(for: app.name)
                let isSelected = vm.inspectedApp?.appName.lowercased() == app.name.lowercased() ||
                                 vm.inspectedApp?.appName.lowercased() == info.displayName.lowercased()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isSelected {
                            vm.send(.inspectApp(""))
                        } else {
                            vm.send(.inspectApp(app.name))
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(info.color.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: info.icon)
                                .font(.body.bold())
                                .foregroundStyle(info.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(info.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                if isSelected {
                                    Pill(text: "Inspecting", color: .blue)
                                }
                            }
                            Text(info.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("avg \(Int(app.avgCPUPercent))% • peak \(Int(app.peakCPUPercent))%")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(app.avgCPUPercent >= 30 ? .orange : .secondary)

                            Text(ByteFormat.string(app.avgMemoryBytes))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.4))
                    }
                    .padding(12)
                    .glassCard(tint: isSelected ? .blue : .secondary, opacity: isSelected ? 0.14 : 0.05)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(for risk: LoadRisk) -> Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
