// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// The always-visible status bar label: a compact live CPU & health indicator.
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

/// Mini gauge tile rendered inside the MenuBar dropdown.
struct MenuBarMiniGauge: View {
    let title: String
    let value: String
    let subtitle: String
    let fraction: Double
    let risk: LoadRisk
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color(for: risk))
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color(for: risk))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color(for: risk)).frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(fraction))))
                }
            }
            .frame(height: 3)

            Text(subtitle)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .glassCard(tint: color(for: risk), opacity: 0.05)
    }

    private func color(for risk: LoadRisk) -> Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// Mini thermal state tile rendered inside the MenuBar dropdown.
struct MenuBarThermalTile: View {
    let state: ProcessInfo.ThermalState
    let risk: LoadRisk

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: "thermometer.medium").font(.system(size: 9)).foregroundStyle(color(for: risk))
                Text("Temp").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }

            Text(state.label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color(for: risk))
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color(for: risk)).frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(thermalFraction))))
                }
            }
            .frame(height: 3)

            Text(deviceModelLabel)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .glassCard(tint: color(for: risk), opacity: 0.05)
    }

    private var thermalFraction: Double {
        switch state {
        case .nominal: return 0.25
        case .fair: return 0.50
        case .serious: return 0.75
        case .critical: return 1.00
        @unknown default: return 0.25
        }
    }

    private var deviceModelLabel: String {
        let model = PerformanceMonitor.sysctlString("hw.model")
        return model.lowercased().contains("macbookair") ? "Fanless" : "Active Fan"
    }

    private func color(for risk: LoadRisk) -> Color {
        switch risk {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
