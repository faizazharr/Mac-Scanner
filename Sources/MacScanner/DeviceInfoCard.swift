// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// A sleek, modern modular specs card for this Mac.
struct DeviceInfoCard: View {
    let device: DeviceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Apple Silicon / Architecture badge and Copy button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cpu.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(device.chip)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(device.modelName) • \(device.modelIdentifier)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Pill(text: device.architecture.uppercased(), color: .blue, icon: "apple.logo")

                Button {
                    copySpecsReport()
                } label: {
                    Label("Copy Specs", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider().opacity(0.4)

            // Modular Specs Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                specTile(
                    title: "CPU Cores",
                    value: "\(device.totalCores) Cores",
                    subtitle: "\(device.performanceCores) Perf + \(device.efficiencyCores) Eff",
                    icon: "cpu",
                    color: .cyan
                )

                specTile(
                    title: "GPU & Graphics",
                    value: device.gpuCores > 0 ? "\(device.gpuCores) GPU Cores" : "Integrated",
                    subtitle: device.metalSupport,
                    icon: "square.stack.3d.up.fill",
                    color: .purple
                )

                specTile(
                    title: "Unified Memory",
                    value: ByteFormat.string(device.memoryBytes),
                    subtitle: "Fast Unified Architecture",
                    icon: "memorychip.fill",
                    color: .green
                )

                specTile(
                    title: "macOS System",
                    value: "macOS \(device.macOSVersion)",
                    subtitle: "Build \(device.macOSBuild)",
                    icon: "desktopcomputer",
                    color: .blue
                )

                if let capacity = device.batteryMaxCapacityPercent {
                    specTile(
                        title: "Battery Health",
                        value: "\(capacity)%",
                        subtitle: "\(device.batteryCycleCount ?? 0) Cycles (\(device.batteryCondition ?? "Normal"))",
                        icon: "battery.100percent.bolt",
                        color: capacity >= 80 ? .green : .orange
                    )
                } else {
                    specTile(
                        title: "Power Source",
                        value: "AC Desktop Power",
                        subtitle: "Continuous Power",
                        icon: "bolt.fill",
                        color: .yellow
                    )
                }

                specTile(
                    title: "Hardware Architecture",
                    value: device.architecture == "arm64" ? "Apple Silicon (ARM)" : "Intel x86_64",
                    subtitle: "64-bit Native Engine",
                    icon: "shield.lefthalf.filled",
                    color: .indigo
                )
            }
        }
        .padding(16)
        .glassCard()
    }

    private func specTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                Text(value)
                    .font(.caption)
                    .bold()
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copySpecsReport() {
        let report = """
        --- Mac Specs Report ---
        Model: \(device.modelName) (\(device.modelIdentifier))
        Chip: \(device.chip)
        CPU: \(device.totalCores) cores (\(device.performanceCores) Performance + \(device.efficiencyCores) Efficiency)
        GPU: \(device.gpuCores) cores (\(device.metalSupport))
        Memory: \(ByteFormat.string(device.memoryBytes))
        macOS: \(device.macOSVersion) (\(device.macOSBuild))
        Architecture: \(device.architecture)
        \(device.batteryMaxCapacityPercent.map { "Battery: \($0)% capacity, \(device.batteryCycleCount ?? 0) cycles" } ?? "Power: Desktop AC")
        Generated by MacScanner
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        ToastManager.shared.show("System Specs copied to Clipboard", icon: "doc.on.doc.fill", tint: .blue)
    }
}
