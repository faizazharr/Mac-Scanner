// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Single-event-driven Equatable row for one background service entry.
struct BackgroundServiceRow: View, Equatable {
    let service: BackgroundService
    let onReveal: () -> Void

    static func == (lhs: BackgroundServiceRow, rhs: BackgroundServiceRow) -> Bool {
        lhs.service == rhs.service
    }

    var body: some View {
        HStack(spacing: 12) {
            // Risk indicator dot
            Circle()
                .fill(riskColor)
                .frame(width: 8, height: 8)
                .shadow(color: riskColor.opacity(0.5), radius: 3)

            // Type badge
            Text(service.type.rawValue)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(typeBadgeColor.opacity(0.15))
                .foregroundStyle(typeBadgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Name & label
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(service.displayName)
                        .font(.caption.bold())
                        .lineLimit(1)

                    if let owner = service.ownerApp {
                        Text("·  \(owner)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(service.label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Metrics
            HStack(spacing: 12) {
                if service.status.isRunning {
                    metricPill(
                        icon: "cpu",
                        value: String(format: "%.1f%%", service.cpuPercent),
                        color: service.cpuPercent >= 10 ? .orange : .secondary
                    )
                    metricPill(
                        icon: "memorychip",
                        value: ByteFormat.string(service.memoryBytes),
                        color: service.memoryBytes >= 150_000_000 ? .orange : .secondary
                    )
                }

                // Status badge
                statusBadge
            }

            if service.plistURL != nil {
                Button(action: onReveal) {
                    Image(systemName: "folder.badge.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal plist in Finder")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(rowBorder, lineWidth: 1)
        )
    }

    // MARK: - Sub-Views

    private func metricPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch service.status {
        case .running:
            Text("Running")
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        case .idle:
            Text("Idle")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .foregroundStyle(.secondary)
                .clipShape(Capsule())
        case .onDemand:
            Text("On-Demand")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }

    // MARK: - Styling Helpers

    private var riskColor: Color {
        switch service.risk {
        case .ok:       return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    private var typeBadgeColor: Color {
        switch service.type {
        case .launchAgent:  return .blue
        case .launchDaemon: return .purple
        case .xpcService:   return .cyan
        case .system:       return .secondary
        }
    }

    private var rowBackground: Color {
        switch service.risk {
        case .critical: return Color.red.opacity(0.05)
        case .warning:  return Color.orange.opacity(0.04)
        case .ok:       return Color.primary.opacity(0.03)
        }
    }

    private var rowBorder: Color {
        switch service.risk {
        case .critical: return Color.red.opacity(0.18)
        case .warning:  return Color.orange.opacity(0.15)
        case .ok:       return Color.primary.opacity(0.06)
        }
    }
}
