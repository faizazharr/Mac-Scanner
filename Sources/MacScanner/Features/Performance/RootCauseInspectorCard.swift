// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Visual interactive inspection breakdown for resource-heavy applications.
///
/// Dissects high-impact processes into individual components: active renderer tabs,
/// background worker threads, installed browser extensions, and temporary on-disk caches.
struct RootCauseInspectorCard: View {
    let app: AppInspectionDetail
    @ObservedObject var vm: PerformanceViewModel
    @Binding var pendingKillPID: (pid: Int32, name: String)?
    @Binding var pendingCleanCache: (url: URL, appName: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(app.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: app.icon)
                        .font(.title3.bold())
                        .foregroundStyle(app.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Root-Cause Deep Dive: \(app.appName)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Pill(text: "Inspecting", color: app.color)
                    }
                    Text(app.rootCauseSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if let main = app.mainProcess {
                        Button {
                            pendingKillPID = (main.pid, app.appName)
                        } label: {
                            Label("Quit \(app.appName)", systemImage: "xmark.octagon.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }

                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    } label: {
                        Label("Activity Monitor", systemImage: "waveform.path.ecg")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.send(.inspectApp(""))
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Close inspection")
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
                diagnosticTile(title: "Tabs & Workers", icon: "square.stack.3d.down.right.fill", color: .blue) {
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
                diagnosticTile(title: "Browser Extensions", icon: "puzzlepiece.extension.fill", color: .orange) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !app.extensions.isEmpty {
                            Text("\(app.extensions.count) Extensions Installed")
                                .font(.subheadline.bold())
                            let heavyCount = app.extensions.filter(\.isHeavyCandidate).count
                            Text(heavyCount > 0 ? "\(heavyCount) potentially heavy extensions running." : "All extensions look lightweight.")
                                .font(.caption2)
                                .foregroundStyle(heavyCount > 0 ? .orange : .secondary)

                            Button("Manage in \(app.appName)") {
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
                diagnosticTile(title: "Disk & Cache Bloat", icon: "externaldrive.fill", color: .purple) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ByteFormat.string(app.diskCacheBytes))
                            .font(.subheadline.bold())
                        Text("Web thumbnail, shader, and temporary cache stored on disk.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let cacheURL = app.diskCacheURL, app.diskCacheBytes > 10 * 1024 * 1024 {
                            Button("Clean Cache") {
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
}
