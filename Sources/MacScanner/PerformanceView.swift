// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts
import AppKit

/// Performance tab: live RAM/CPU/GPU/thermal/swap gauges, Swift Charts sparklines,
/// actionable recommendations, and process inspection.
struct PerformanceView: View {
    @ObservedObject var vm: PerformanceViewModel
    @ObservedObject var deviceVM: DeviceInfoViewModel

    @State private var processSort: ProcessSortMode = .cpu
    @State private var pendingKillPID: (pid: Int32, name: String)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let snapshot = vm.snapshot {
                    gaugesRow(snapshot)

                    // Live Telemetry Sparkline Charts
                    if vm.history.count >= 2 {
                        sparklineChartSection
                    }
                } else {
                    HStack {
                        Spacer()
                        ProgressView("Capturing live system performance…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                    .glassCard()
                }

                if !vm.stableRecommendations.isEmpty {
                    recommendationsSection(vm.stableRecommendations)
                }

                if let snapshot = vm.snapshot, !snapshot.heavyAppsRunning.isEmpty {
                    heavyAppsSection(snapshot.heavyAppsRunning)
                }

                if let snapshot = vm.snapshot {
                    let processes = (processSort == .cpu ? snapshot.topProcesses : snapshot.topProcessesByMemory)
                        .filter { p in
                            vm.processSearchQuery.isEmpty || p.name.localizedCaseInsensitiveContains(vm.processSearchQuery)
                        }
                    processListSection(processes)
                }
            }
            .padding(20)
        }
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
            Text("This sends a SIGTERM signal to terminate the process immediately. Unsaved work in this application may be lost.")
        }
        .onChange(of: processSort) { _, newValue in
            vm.send(.setProcessSort(newValue))
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.4), lineWidth: 3)
                    )
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

    private func gaugesRow(_ snapshot: PerformanceMonitor.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
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
    }

    // MARK: - Live Sparkline Charts

    private var sparklineChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Realtime Activity Trends", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.cyan).frame(width: 7, height: 7)
                        Text("CPU %").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.purple).frame(width: 7, height: 7)
                        Text("RAM %").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Chart(vm.history) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Color.cyan)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.2), Color.cyan.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Memory", point.memoryPercent),
                    series: .value("Metric", "RAM")
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)%").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 110)
        }
        .padding(14)
        .glassCard()
    }

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

    private func heavyAppsSection(_ apps: [ProcessStats]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Resource-Heavy Background Applications", systemImage: "flame.fill")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                Spacer()
                Pill(text: "\(apps.count) Apps Active", color: .orange)
            }

            ForEach(apps) { app in
                HStack {
                    Image(systemName: "app.dashed")
                        .foregroundStyle(.orange)
                    Text(app.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(app.cpuPercent))% CPU")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(ByteFormat.string(app.memoryBytes))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button("Quit") {
                        pendingKillPID = (app.pid, app.name)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(14)
        .glassCard(tint: .orange, opacity: 0.08)
    }

    private func processListSection(_ processes: [ProcessStats]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Top Active Processes", systemImage: "list.bullet.rectangle.portrait.fill")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Process Search
                HStack {
                    Image(systemName: "magnifyingglass").font(.caption2).foregroundStyle(.secondary)
                    TextField("Filter processes…", text: $vm.processSearchQuery)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 160)

                Picker("Sort by", selection: $processSort) {
                    ForEach(ProcessSortMode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .labelsHidden()
            }

            ForEach(processes) { process in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: process.isKnownHeavy ? "flame.fill" : "gearshape.2.fill")
                        .font(.caption)
                        .foregroundStyle(process.isKnownHeavy ? .orange : .secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(process.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text("PID: \(process.pid)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        if let parent = process.parentAppName {
                            Text("Belongs to \(parent)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Mini CPU bar
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(process.cpuPercent, specifier: "%.1f")% CPU")
                            .font(.system(.caption2, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundStyle(process.cpuPercent >= 40 ? .red : .primary)
                    }
                    .frame(width: 80, alignment: .trailing)

                    // RAM usage
                    Text(ByteFormat.string(process.memoryBytes))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 75, alignment: .trailing)

                    Button {
                        pendingKillPID = (process.pid, process.name)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Terminate process (SIGTERM)")
                }
                .padding(.vertical, 3)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func color(for risk: LoadRisk) -> Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Gauge Card Component

private struct GaugeCard: View {
    let title: String
    let icon: String
    let valueLabel: String
    let subLabel: String
    let fraction: Double
    let risk: LoadRisk
    let redLineFraction: Double?

    private let barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(valueLabel)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: w, height: barHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, w * CGFloat(min(max(fraction, 0), 1))), height: barHeight)

                    if let redLineFraction {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: barHeight + 4)
                            .offset(x: w * CGFloat(redLineFraction) - 1)
                    }
                }
            }
            .frame(height: barHeight + 4)

            Text(subLabel)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: risk == .ok ? .secondary : color, opacity: risk == .ok ? 0.06 : 0.12)
    }

    private var color: Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

private struct ThermalCard: View {
    let state: ProcessInfo.ThermalState
    let risk: LoadRisk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Thermal State", systemImage: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(state.label)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)

            Spacer()

            Text("System temp level")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: risk == .ok ? .secondary : color, opacity: risk == .ok ? 0.06 : 0.12)
    }

    private var color: Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var icon: String {
        switch state {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "flame.fill"
        @unknown default: return "thermometer.medium"
        }
    }
}
