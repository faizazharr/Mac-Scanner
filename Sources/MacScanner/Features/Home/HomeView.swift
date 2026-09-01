// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// The landing tab: this Mac's specs and a storage ring overview,
/// then dynamic feature tiles with live status badges.
struct HomeView: View {
    @ObservedObject var deviceVM: DeviceInfoViewModel
    let onSelectTab: (ScreenerTab) -> Void

    @State private var volumeTotal: Int64 = 0
    @State private var volumeFree: Int64 = 0
    @State private var showFDAModal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                // Storage Overview Card
                if volumeTotal > 0 {
                    storageOverviewCard
                }

                // Feature Action Hub
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Navigation & Tools")
                        .font(.headline)
                        .fontWeight(.semibold)

                    navigationGrid
                }

                // Device Specs Hub
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hardware & Software Specification")
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let device = deviceVM.device {
                        DeviceInfoCard(device: device)
                    } else {
                        HStack {
                            Spacer()
                            ProgressView("Reading hardware specs…")
                            Spacer()
                        }
                        .padding(.vertical, 30)
                        .glassCard()
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showFDAModal) {
            FullDiskAccessModalView(isPresented: $showFDAModal)
        }
        .onAppear {
            deviceVM.send(.appearIfNeeded)
            refreshVolume()
        }
    }

    private func refreshVolume() {
        if let info = DiskScanner.volumeInfo(for: FileManager.default.homeDirectoryForCurrentUser) {
            volumeTotal = info.total
            volumeFree = info.free
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("MacScanner")
                        .font(.title2)
                        .fontWeight(.bold)
                    Pill(text: "Ready", color: .green, icon: "checkmark.circle.fill")
                }
                Text("Your Mac's disk space, cleanup recommendations, and performance dashboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !PermissionHelper.hasFullDiskAccess {
                Button {
                    showFDAModal = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                        Text("Buka Full Disk Access")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
            }
        }
    }

    private var storageOverviewCard: some View {
        let used = volumeTotal - volumeFree
        let fraction = volumeTotal > 0 ? Double(used) / Double(volumeTotal) : 0
        let isCritical = fraction >= 0.90
        let isWarning = fraction >= 0.75

        return HStack(spacing: 24) {
            StorageRingGauge(usedBytes: used, totalBytes: volumeTotal, freeBytes: volumeFree, size: 110, lineWidth: 11)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Macintosh HD Storage")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(ByteFormat.string(used)) used out of \(ByteFormat.string(volumeTotal)) total space")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isCritical {
                        Pill(text: "Storage Almost Full", color: .red, icon: "exclamationmark.triangle.fill")
                    } else if isWarning {
                        Pill(text: "Storage Filling Up", color: .orange, icon: "exclamationmark.circle.fill")
                    } else {
                        Pill(text: "Storage Healthy", color: .green, icon: "checkmark.shield.fill")
                    }
                }

                // Storage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isCritical ? [.orange, .red] : isWarning ? [.yellow, .orange] : [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(fraction)), height: 10)
                    }
                }
                .frame(height: 10)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Used: \(ByteFormat.string(used))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                        Text("Free: \(ByteFormat.string(volumeFree))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        onSelectTab(.browser)
                    } label: {
                        Label("Explore Folders", systemImage: "folder.badge.gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(18)
        .glassCard(tint: isCritical ? .red : isWarning ? .orange : .blue, opacity: 0.08)
    }

    private var navigationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            NavCard(
                title: "Designer & Browsers",
                subtitle: "Plain-language Mac slowdown diagnostics, Figma/Adobe caches, and browser extension bloat.",
                icon: "paintbrush.pointed.fill",
                badge: "Creative & Web",
                color: .pink
            ) { onSelectTab(.designerBrowsers) }

            NavCard(
                title: "Folder Browser",
                subtitle: "Drill into folders, interactive percentage donut breakdown, and relative size bars.",
                icon: "folder.fill",
                badge: "Visual Breakdown",
                color: .blue
            ) { onSelectTab(.browser) }

            NavCard(
                title: "Cleanup Recommendations",
                subtitle: "Safe-to-clean junk, build artifacts, caches, and backups with batch removal.",
                icon: "sparkles",
                badge: "Smart Clean",
                color: .green
            ) { onSelectTab(.recommendations) }

            NavCard(
                title: "Large Files Finder",
                subtitle: "Locate oversized files by category (Design, Video, Archives, VM disks) with quick filters.",
                icon: "doc.badge.gearshape.fill",
                badge: "Fast Scan",
                color: .purple
            ) { onSelectTab(.largeFiles) }

            NavCard(
                title: "Performance Telemetry",
                subtitle: "Live CPU, RAM, GPU, and thermal telemetry with sparkline charts and process control.",
                icon: "gauge.with.dots.needle.67percent",
                badge: "Live Telemetry",
                color: .orange
            ) { onSelectTab(.performance) }

            NavCard(
                title: "Hardware Diagnostics",
                subtitle: "Full diagnostic suite for screen dead pixels, stereo L/R speakers, microphone, keyboard, and trackpad.",
                icon: "wrench.and.screwdriver.fill",
                badge: "Device Test",
                color: .teal
            ) { onSelectTab(.deviceTesting) }
        }
    }
}

private struct NavCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let badge: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(color)
                    }

                    Spacer()

                    Pill(text: badge, color: color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                HStack {
                    Text("Open Tool")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.callout)
                        .foregroundStyle(isHovering ? color : Color.secondary.opacity(0.5))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 135, alignment: .topLeading)
            .glassCard(tint: color, opacity: isHovering ? 0.15 : 0.06, isHovered: isHovering)
            .scaleEffect(isHovering ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
