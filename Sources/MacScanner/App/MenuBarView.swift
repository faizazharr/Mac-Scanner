// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Dropdown panel content shown when the menu bar item is clicked:
/// a glanceable Apple Glassmorphic quick telemetry dashboard.
struct MenuBarContentView: View {
    @ObservedObject var vm: PerformanceViewModel
    @ObservedObject var deviceVM: DeviceInfoViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var showStatusHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            if let snapshot = vm.snapshot {
                gaugesGrid(snapshot)

                let concerning = vm.stableRecommendations.filter { $0.risk != .ok }
                if let worst = concerning.first {
                    smartAlertCard(worst)
                }

                let userApps = vm.heaviestAppsThisSession.filter { !$0.isSystemDaemon }
                if !userApps.isEmpty {
                    heaviestAppsSection(userApps)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text("Reading system telemetry…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            }

            Divider().opacity(0.4)
            footerToolbar
        }
        .padding(14)
        .frame(width: 320)
        .popover(isPresented: $showStatusHelp) {
            statusExplanationPopover
        }
        .onAppear {
            vm.send(.appear)
            vm.send(.refreshNow)
        }
        .onDisappear {
            vm.send(.disappear)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 24, height: 24)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("MacScanner")
                .font(.subheadline)
                .fontWeight(.bold)

            Spacer()

            if let device = deviceVM.device {
                Pill(text: device.chip, color: .blue)
            }

            if let snapshot = vm.snapshot {
                Button {
                    showStatusHelp.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Pill(text: snapshot.overallStatusLabel, color: color(for: snapshot.overallRisk))
                        Image(systemName: "questionmark.circle").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Click to understand system status and memory safety")
            }
        }
    }

    private var statusExplanationPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").font(.subheadline).foregroundStyle(.blue)
                Text("Understanding Mac System Status").font(.subheadline).fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 10) {
                statusRow(title: "Optimal (Green)", desc: "CPU, RAM, and temperature are running cool, light, and with peak responsiveness.", color: .green, icon: "checkmark.circle.fill")
                statusRow(title: "Busy / Normal Load (Amber)", desc: "Background tasks, Docker, or open browser tabs are using memory. Your Mac is operating normally.", color: .orange, icon: "chart.bar.fill")
                statusRow(title: "Heavy Load / Swap (Orange-Red)", desc: "macOS is using SSD virtual memory to keep apps open without quitting them. Your hardware is 100% safe. Close unused apps if you experience lag.", color: .red, icon: "arrow.left.arrow.right")
            }

            Divider().opacity(0.3)

            HStack {
                Spacer()
                Button("Got it") { showStatusHelp = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func statusRow(title: String, desc: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.caption.bold()).foregroundStyle(color).frame(width: 16).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).fontWeight(.bold).foregroundStyle(color)
                Text(desc).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Mini Gauges

    private func gaugesGrid(_ snapshot: PerformanceMonitor.Snapshot) -> some View {
        HStack(spacing: 8) {
            MenuBarMiniGauge(title: "RAM", value: "\(Int(snapshot.memory.usedFraction * 100))%", subtitle: ByteFormat.string(snapshot.memory.usedBytes), fraction: snapshot.memory.usedFraction, risk: snapshot.memoryRisk, icon: "memorychip.fill")
            MenuBarMiniGauge(title: "CPU", value: "\(Int(snapshot.cpuPercent))%", subtitle: "Load", fraction: snapshot.cpuPercent / 100, risk: snapshot.cpuRisk, icon: "cpu.fill")
            if let gpu = snapshot.gpuPercent {
                MenuBarMiniGauge(title: "GPU", value: "\(Int(gpu))%", subtitle: "Load", fraction: gpu / 100, risk: snapshot.gpuRisk, icon: "square.stack.3d.up.fill")
            }
            MenuBarThermalTile(state: snapshot.thermalState, risk: snapshot.thermalRisk)
        }
    }

    private func smartAlertCard(_ rec: PerformanceRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.icon).font(.body.bold()).foregroundStyle(color(for: rec.risk)).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title).font(.caption.bold())
                Text(rec.advice).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: color(for: rec.risk), opacity: 0.10)
    }

    private func heaviestAppsSection(_ apps: [AppImpactRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active High-Impact Apps").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            ForEach(apps.prefix(3)) { app in
                let info = AppInspector.friendlyInfo(for: app.name)
                HStack(spacing: 8) {
                    Image(systemName: info.icon).font(.system(size: 11)).foregroundStyle(info.color).frame(width: 14)
                    Text(info.displayName).font(.caption).lineLimit(1)
                    Spacer()
                    Text("avg \(Int(app.avgCPUPercent))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    Text(ByteFormat.string(app.avgMemoryBytes)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var footerToolbar: some View {
        HStack {
            Button {
                openMainWindow()
            } label: {
                Label("Open MacScanner", systemImage: "macwindow")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func openMainWindow() {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            openWindow(id: MacScannerApp.mainWindowID)
            NSApp.activate(ignoringOtherApps: true)
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
