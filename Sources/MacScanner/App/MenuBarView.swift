// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// The always-visible menu bar label: a compact live CPU & health reading.
struct MenuBarLabel: View {
    @ObservedObject var vm: PerformanceViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tintColor)
            if let snapshot = vm.snapshot {
                Text("\(Int(snapshot.cpuPercent))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tintColor)
            }
        }
    }

    private var icon: String {
        guard let snapshot = vm.snapshot else { return "gauge.with.dots.needle.0percent" }
        switch snapshot.overallRisk {
        case .ok: return "gauge.with.dots.needle.33percent"
        case .warning: return "gauge.with.dots.needle.67percent"
        case .critical: return "gauge.with.dots.needle.100percent"
        }
    }

    private var tintColor: Color {
        guard let snapshot = vm.snapshot else { return .primary }
        switch snapshot.overallRisk {
        case .ok: return .primary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// The dropdown panel content shown when the menu bar item is clicked —
/// a beautiful, glanceable, Apple Glassmorphic dashboard.
struct MenuBarContentView: View {
    @ObservedObject var vm: PerformanceViewModel
    @ObservedObject var deviceVM: DeviceInfoViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            headerBar

            if let snapshot = vm.snapshot {
                // 4 Interactive Mini Gauges
                gaugesGrid(snapshot)

                // Smart Alert / Advice Card
                let concerning = vm.stableRecommendations.filter { $0.risk != .ok }
                if let worst = concerning.first {
                    smartAlertCard(worst)
                }

                // Top User Applications Impact
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

            // Footer Toolbar
            footerToolbar
        }
        .padding(14)
        .frame(width: 320)
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
                Pill(
                    text: snapshot.overallRisk == .ok ? "Optimal" : snapshot.overallRisk == .warning ? "Warning" : "Critical",
                    color: color(for: snapshot.overallRisk)
                )
            }
        }
    }

    // MARK: - 4 Mini Gauges

    private func gaugesGrid(_ snapshot: PerformanceMonitor.Snapshot) -> some View {
        HStack(spacing: 8) {
            miniGaugeTile(
                title: "RAM",
                value: "\(Int(snapshot.memory.usedFraction * 100))%",
                subtitle: ByteFormat.string(snapshot.memory.usedBytes),
                fraction: snapshot.memory.usedFraction,
                risk: snapshot.memoryRisk,
                icon: "memorychip.fill"
            )

            miniGaugeTile(
                title: "CPU",
                value: "\(Int(snapshot.cpuPercent))%",
                subtitle: "Load",
                fraction: snapshot.cpuPercent / 100,
                risk: snapshot.cpuRisk,
                icon: "cpu.fill"
            )

            if let gpu = snapshot.gpuPercent {
                miniGaugeTile(
                    title: "GPU",
                    value: "\(Int(gpu))%",
                    subtitle: "Load",
                    fraction: gpu / 100,
                    risk: snapshot.gpuRisk,
                    icon: "square.stack.3d.up.fill"
                )
            }

            miniThermalTile(state: snapshot.thermalState, risk: snapshot.thermalRisk)
        }
    }

    private func miniGaugeTile(title: String, value: String, subtitle: String, fraction: Double, risk: LoadRisk, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            // Mini Ring Dial
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 3.5)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                    .stroke(color(for: risk), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))

                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Text(subtitle)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .glassCard(tint: color(for: risk), opacity: risk == .ok ? 0.04 : 0.10)
    }

    private func miniThermalTile(state: ProcessInfo.ThermalState, risk: LoadRisk) -> some View {
        VStack(spacing: 4) {
            Text("TEMP")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(color(for: risk).opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: state == .nominal ? "thermometer.low" : state == .fair ? "thermometer.medium" : "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color(for: risk))
            }

            Text(state.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color(for: risk))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .glassCard(tint: color(for: risk), opacity: risk == .ok ? 0.04 : 0.10)
    }

    // MARK: - Smart Alert Card

    private func smartAlertCard(_ rec: PerformanceRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundStyle(color(for: rec.risk))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title + " Alert")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color(for: rec.risk))

                Text(rec.advice)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .glassCard(tint: color(for: rec.risk), opacity: 0.14)
    }

    // MARK: - Heaviest Apps Section

    private func heaviestAppsSection(_ apps: [AppImpactRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Heaviest Apps This Session")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Avg CPU")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            ForEach(apps.prefix(3)) { app in
                HStack(spacing: 8) {
                    Image(systemName: appIcon(for: app.name))
                        .font(.caption)
                        .foregroundStyle(app.avgCPUPercent >= 30 ? .orange : .blue)
                        .frame(width: 16)

                    Text(app.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    // Mini CPU percentage with visual bar
                    Text("\(Int(app.avgCPUPercent))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(app.avgCPUPercent >= 30 ? .orange : .secondary)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 36, height: 4)
                        Capsule()
                            .fill(app.avgCPUPercent >= 30 ? Color.orange : Color.blue)
                            .frame(width: max(2, 36 * CGFloat(min(app.avgCPUPercent / 100, 1))), height: 4)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .glassCard()
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

    // MARK: - Footer Toolbar

    private var footerToolbar: some View {
        HStack(spacing: 10) {
            Button {
                openWindow(id: MacScannerApp.mainWindowID)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.caption)
                    Text("Open MacScanner")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
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
