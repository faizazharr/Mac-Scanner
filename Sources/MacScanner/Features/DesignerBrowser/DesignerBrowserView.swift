// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// View for Designer & Browser screening: plain-language diagnostics,
/// design apps cache cleaner, and browser extension inspector.
struct DesignerBrowserView: View {
    @ObservedObject var vm: DesignerBrowserViewModel

    private enum Mode: String, CaseIterable {
        case overview = "Diagnostics & Insights"
        case designCaches = "Design Caches"
        case browsers = "Browsers & Extensions"
    }

    @State private var selectedMode: Mode = .overview
    @State private var pendingCleanURL: (url: URL, title: String)?
    @State private var showCleanAllDesignConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                // Top Metrics Hub
                metricsHub

                // Mode Selector
                Picker("Mode", selection: $selectedMode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                // Sub-view Content
                switch selectedMode {
                case .overview:
                    overviewSection
                case .designCaches:
                    designCachesSection
                case .browsers:
                    browsersSection
                }
            }
            .padding(20)
        }
        .confirmationDialog(
            "Clean \(pendingCleanURL?.title ?? "Cache")?",
            isPresented: Binding(
                get: { pendingCleanURL != nil },
                set: { if !$0 { pendingCleanURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let target = pendingCleanURL {
                    vm.send(.cleanDesignCache(target.url))
                }
                pendingCleanURL = nil
            }
            Button("Cancel", role: .cancel) { pendingCleanURL = nil }
        } message: {
            Text("Cache files will be safely moved to Trash. Applications will automatically re-download or recreate required assets as needed.")
        }
        .confirmationDialog(
            "Clean All Design Caches (\(ByteFormat.string(vm.totalDesignCacheBytes)))?",
            isPresented: $showCleanAllDesignConfirm,
            titleVisibility: .visible
        ) {
            Button("Clean All Safe Caches", role: .destructive) {
                vm.send(.cleanAllSafeDesignCaches)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will move all safe Figma, Adobe, and Sketch temporary caches to the Trash.")
        }
        .onAppear {
            vm.send(.appearIfNeeded)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Designer & Browser Screener")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Plain-language diagnostics for creative design app caches and browser extension overhead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if vm.isScanning {
                ProgressView().controlSize(.small)
                Text("Scanning…").font(.caption).foregroundStyle(.secondary)
            }

            Button {
                vm.send(.rescan)
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Metrics Hub

    private var metricsHub: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            metricCard(
                title: "Design Apps Cache",
                value: ByteFormat.string(vm.totalDesignCacheBytes),
                subtitle: "\(vm.designCaches.count) target locations",
                icon: "paintbrush.fill",
                color: .pink
            )

            metricCard(
                title: "Browsers Cache",
                value: ByteFormat.string(vm.totalBrowserCacheBytes),
                subtitle: "From \(vm.browsers.count) browsers",
                icon: "globe",
                color: .blue
            )

            metricCard(
                title: "Total Browser Extensions",
                value: "\(vm.totalExtensionsCount) Extensions",
                subtitle: "Across all browsers",
                icon: "puzzlepiece.extension.fill",
                color: .purple
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: color, opacity: 0.08)
    }

    // MARK: - Overview Insights Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Diagnostic Plain-Language Insights
            Text("Smart Diagnostic Insights")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(vm.insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(insight.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: insight.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(insight.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text(insight.summary)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Text(insight.explanation)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 1)
                    }

                    Spacer()

                    if let action = insight.actionTitle {
                        Button {
                            if let bName = insight.browserName {
                                DesignerBrowserScanner.openBrowserExtensionPage(browserName: bName)
                            } else if let target = insight.targetURL {
                                vm.send(.cleanDesignCache(target))
                            }
                        } label: {
                            Text(action)
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(insight.color)
                        .controlSize(.small)
                    }
                }
                .padding(14)
                .glassCard(tint: insight.color, opacity: 0.07)
            }

            // Quick Tips for Designers
            designerTipsCard
        }
    }

    private var designerTipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mac Optimization Tips for Designers & Creators", systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 4) {
                tipRow("1. Close unused Figma / Photoshop project tabs so RAM is released to macOS.")
                tipRow("2. Avoid running multiple redundant ad-blocker extensions simultaneously.")
                tipRow("3. Periodically purge Adobe Media Cache after completing heavy motion/video edits.")
                tipRow("4. Disable browser screen-recording or video downloading extensions when not actively in use.")
            }
        }
        .padding(14)
        .glassCard(tint: .purple, opacity: 0.07)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.purple)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Design Caches Section

    private var designCachesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installed Design Apps Cache Targets")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Canvas caches, rendered frame previews, and autosave scratch files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if vm.totalDesignCacheBytes > 0 {
                    Button {
                        showCleanAllDesignConfirm = true
                    } label: {
                        Label("Clean All (\(ByteFormat.string(vm.totalDesignCacheBytes)))", systemImage: "trash.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.small)
                }
            }

            if !vm.designCaches.isEmpty {
                ForEach(vm.designCaches) { cache in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.pink.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: cache.icon)
                                .font(.body.bold())
                                .foregroundStyle(.pink)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(cache.appName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Pill(text: cache.category, color: .pink)
                                if cache.safeToClean {
                                    Pill(text: "Safe to Clean", color: .green, icon: "checkmark.shield.fill")
                                }
                            }
                            Text(cache.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(cache.path.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(ByteFormat.string(cache.sizeBytes))
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)

                            HStack(spacing: 6) {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([cache.path])
                                } label: {
                                    Label("Reveal", systemImage: "arrow.up.forward.app")
                                        .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button {
                                    pendingCleanURL = (cache.path, cache.appName)
                                } label: {
                                    Label("Clean", systemImage: "trash")
                                        .font(.caption2)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(12)
                    .glassCard()
                }
            } else if !vm.isScanning {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("No design caches accumulated.")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .glassCard()
            }
        }
    }

    // MARK: - Browsers & Extensions Section

    private var browsersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Installed Web Browsers & Extensions")
                .font(.headline)
                .fontWeight(.bold)

            // Browser selector pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.browsers) { browser in
                        Button {
                            vm.selectedBrowserID = browser.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: browser.icon)
                                Text(browser.name)
                                    .fontWeight(vm.selectedBrowserID == browser.id ? .bold : .regular)
                                Pill(text: "\(browser.extensionsCount) Ext", color: browser.tintColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                vm.selectedBrowserID == browser.id
                                    ? browser.tintColor.opacity(0.2)
                                    : Color.secondary.opacity(0.08)
                            )
                            .foregroundStyle(vm.selectedBrowserID == browser.id ? browser.tintColor : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(vm.selectedBrowserID == browser.id ? browser.tintColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Selected Browser Details
            if let selectedID = vm.selectedBrowserID, let browser = vm.browsers.first(where: { $0.id == selectedID }) {
                browserDetailCard(browser)
            }
        }
    }

    private func browserDetailCard(_ browser: BrowserInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Browser Summary Bar
            HStack(spacing: 12) {
                Image(systemName: browser.icon)
                    .font(.title2)
                    .foregroundStyle(browser.tintColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(browser.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Web cache: \(ByteFormat.string(browser.cacheBytes)) • \(browser.extensionsCount) extensions installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let cacheURL = browser.cacheURL, browser.cacheBytes > 0 {
                    Button {
                        pendingCleanURL = (cacheURL, "\(browser.name) Cache")
                    } label: {
                        Label("Clear Web Cache", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }

                if browser.extensionsCount > 0 {
                    Button {
                        DesignerBrowserScanner.openBrowserExtensionPage(browserName: browser.name)
                    } label: {
                        Label("Manage in \(browser.name)", systemImage: "gearshape.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .glassCard(tint: browser.tintColor, opacity: 0.10)

            // Extension List
            if !browser.extensions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extensions / Add-ons List:")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(browser.extensions) { ext in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: ext.isHeavyCandidate ? "exclamationmark.triangle.fill" : "puzzlepiece.extension.fill")
                                .font(.caption)
                                .foregroundStyle(ext.isHeavyCandidate ? .orange : browser.tintColor)
                                .frame(width: 18)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(ext.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("v\(ext.version)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)

                                    if ext.isHeavyCandidate {
                                        Pill(text: "High Overhead", color: .orange, icon: "flame.fill")
                                    }
                                }
                                Text(ext.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .glassCard()
                    }
                }
            } else {
                Text("No extensions installed on this browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
        }
    }
}
