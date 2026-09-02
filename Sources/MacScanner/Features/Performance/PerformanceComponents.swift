// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

// MARK: - Performance Gauge Card

struct GaugeCard: View, Equatable {
    let title: String
    let icon: String
    let valueLabel: String
    let subLabel: String
    let fraction: Double
    let risk: LoadRisk
    let redLineFraction: Double?

    static func == (lhs: GaugeCard, rhs: GaugeCard) -> Bool {
        lhs.valueLabel == rhs.valueLabel && lhs.subLabel == rhs.subLabel && lhs.fraction == rhs.fraction && lhs.risk == rhs.risk
    }

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

// MARK: - Performance Thermal Card

struct ThermalCard: View, Equatable {
    let state: ProcessInfo.ThermalState
    let risk: LoadRisk

    static func == (lhs: ThermalCard, rhs: ThermalCard) -> Bool {
        lhs.state == rhs.state && lhs.risk == rhs.risk
    }

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
