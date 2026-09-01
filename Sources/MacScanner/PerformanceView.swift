// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Charts
import AppKit

/// Performance tab: live RAM/CPU/GPU/thermal/swap gauges, Swift Charts sparklines,
/// actionable recommendations, and the Interactive Root-Cause Inspector.
struct PerformanceView: View {
    @ObservedObject var vm: PerformanceViewModel
    @ObservedObject var deviceVM: DeviceInfoViewModel

    private enum ProcessSort: String, CaseIterable { case cpu = "CPU", memory = "RAM" }
    @State private var processSort: ProcessSort = .cpu
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
                        sparklineChartSection
                    }

                    // Recommendations & Diagnostics
                    if !vm.stableRecommendations.isEmpty {
                        recommendationsSection(vm.stableRecommendations)
                    }

                    // Interactive Root-Cause Inspector (Anatomy Breakdown)
                    if let inspected = vm.inspectedApp {
                        rootCauseInspectorCard(inspected)
                    }

                    // What's Making This Mac Heavy (Clickable to Inspect)
                    let userApps = vm.heaviestAppsThisSession.filter { !$0.isSystemDaemon }
                    if !userApps.isEmpty {
                        heaviestAppsSection(userApps)
                    }

                    // Process List
                    let processes = (processSort == .cpu ? snapshot.topProcesses : snapshot.topProcessesByMemory)
                        .filter { p in
                            vm.processSearchQuery.isEmpty || p.name.localizedCaseInsensitiveContains(vm.processSearchQuery)
                        }
                    processListSection(processes)
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

    // MARK: - Gauges Row

    private func gaugesRow(_ snapshot: PerformanceMonitor.Snapshot) -> some View {
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

    // MARK: - Root-Cause Inspector (App Anatomy Breakdown)

    private func rootCauseInspectorCard(_ app: AppInspectionDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(app.color.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: app.icon)
                        .font(.title3)
                        .foregroundStyle(app.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Root-Cause Deep Dive: \(app.appName)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Pill(text: "Inspecting Anatomy", color: app.color)
                    }
                    Text(app.rootCauseSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let main = app.mainProcess {
                    Button {
                        pendingKillPID = (main.pid, app.appName)
                    } label: {
                        Label("Quit \(app.appName)", systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }

            // Visual Resource Composition Bar
            if app.totalRAMBytes > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Memory & Process Composition:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Total: \(ByteFormat.string(app.totalRAMBytes)) RAM • \(Int(app.totalCPUPercent))% CPU")
                            .font(.caption2.bold())
                            .foregroundStyle(.primary)
                    }

                    GeometryReader { geo in
                        let w = geo.size.width
                        let total = CGFloat(max(1, app.totalRAMBytes))
                        let rendererW = w * (CGFloat(app.rendererRAMBytes) / total)
                        let gpuW = w * (CGFloat(app.gpuRAMBytes) / total)
                        let baseW = max(0, w - rendererW - gpuW)

                        HStack(spacing: 2) {
                            if rendererW > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue)
                                    .frame(width: rendererW, height: 10)
                            }
                            if gpuW > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.purple)
                                    .frame(width: gpuW, height: 10)
                            }
                            if baseW > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.cyan)
                                    .frame(width: baseW, height: 10)
                            }
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 14) {
                        legendItem(title: "Tabs / Renderers: \(ByteFormat.string(app.rendererRAMBytes))", color: .blue)
                        if app.gpuRAMBytes > 0 {
                            legendItem(title: "GPU Accelerator: \(ByteFormat.string(app.gpuRAMBytes))", color: .purple)
                        }
                        legendItem(title: "Core App: \(ByteFormat.string(app.baseAppRAMBytes))", color: .cyan)
                    }
                }
                .padding(10)
                .glassCard(tint: app.color, opacity: 0.05)
            }

            // 3-Column Diagnostic Tiles
            HStack(alignment: .top, spacing: 10) {
                // Column 1: Tabs & Renderers
                diagnosticTile(
                    title: "Tabs & Workers",
                    icon: "square.stack.3d.down.right.fill",
                    color: .blue
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(app.rendererProcesses.count) Active Renderers")
                            .font(.subheadline.bold())
                        Text("Consuming \(ByteFormat.string(app.rendererRAMBytes)) RAM across background tabs.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let heaviest = app.heaviestWorker, heaviest.memoryBytes > 300 * 1024 * 1024 {
                            Divider().padding(.vertical, 2)
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Heaviest Tab (PID \(heaviest.pid))")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(ByteFormat.string(heaviest.memoryBytes)) RAM")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                                Button("Close Tab") {
                                    pendingKillPID = (heaviest.pid, "\(app.appName) Tab (PID \(heaviest.pid))")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                }

                // Column 2: Installed Extensions
                diagnosticTile(
                    title: "Browser Extensions",
                    icon: "puzzlepiece.extension.fill",
                    color: .orange
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !app.extensions.isEmpty {
                            Text("\(app.extensions.count) Extensions Installed")
                                .font(.subheadline.bold())
                            let heavyCount = app.extensions.filter(\.isHeavyCandidate).count
                            Text(heavyCount > 0 ? "\(heavyCount) potentially heavy extensions running." : "All extensions look lightweight.")
                                .font(.caption2)
                                .foregroundStyle(heavyCount > 0 ? .orange : .secondary)

                            Button("Kelola di \(app.appName)") {
                                DesignerBrowserScanner.openBrowserExtensionPage(browserName: app.appName)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .padding(.top, 4)
                        } else {
                            Text("No Extensions")
                                .font(.subheadline.bold())
                            Text("This application does not load browser extension scripts.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Column 3: Disk & Web Cache
                diagnosticTile(
                    title: "Disk & Cache Bloat",
                    icon: "externaldrive.fill",
                    color: .purple
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ByteFormat.string(app.diskCacheBytes))
                            .font(.subheadline.bold())
                        Text("Web thumbnail, shader, and temporary cache stored on disk.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let cacheURL = app.diskCacheURL, app.diskCacheBytes > 10 * 1024 * 1024 {
                            Button("Bersihkan Cache") {
                                pendingCleanCache = (cacheURL, app.appName)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.mini)
                            .padding(.top, 4)
                        }
                    }
                }
            }

            // Actionable Suggestion Banner
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text(app.primaryActionSuggestion)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(10)
            .background(Color.orange.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .glassCard(tint: app.color, opacity: 0.10)
    }

    private func diagnosticTile<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .glassCard()
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Sparklines

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
                    Text("What's Making This Mac Heavy (Click to Inspect)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Ranked by sustained CPU & memory impact over this session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Pill(text: "\(apps.count) Apps Active", color: .orange)
            }

            ForEach(apps) { app in
                let isSelected = vm.inspectedApp?.appName.lowercased() == app.name.lowercased()
                Button {
                    vm.send(.inspectApp(app.name))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: appIcon(for: app.name))
                            .font(.body)
                            .foregroundStyle(app.avgCPUPercent >= 30 ? .orange : .blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                if isSelected {
                                    Pill(text: "Selected", color: .blue)
                                }
                            }
                            Text("Observed across \(app.sampleCount) telemetry checks")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
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

                        Image(systemName: "chevron.right")
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

    private func appIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("arc") || lower.contains("firefox") {
            return "globe"
        }
        if lower.contains("figma") || lower.contains("photoshop") || lower.contains("illustrator") || lower.contains("sketch") {
            return "paintbrush.fill"
        }
        if lower.contains("xcode") || lower.contains("code") || lower.contains("terminal") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if lower.contains("slack") || lower.contains("discord") || lower.contains("zoom") || lower.contains("teams") {
            return "bubble.left.and.bubble.right.fill"
        }
        return "app.fill"
    }

    // MARK: - Process List

    private func processListSection(_ processes: [ProcessStats]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("All Active Processes", systemImage: "list.bullet.rectangle.portrait.fill")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

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
                    ForEach(ProcessSort.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .labelsHidden()
            }

            ForEach(processes.prefix(15)) { process in
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

                    Text("\(process.cpuPercent, specifier: "%.1f")% CPU")
                        .font(.system(.caption2, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(process.cpuPercent >= 40 ? .red : .primary)
                        .frame(width: 80, alignment: .trailing)

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
