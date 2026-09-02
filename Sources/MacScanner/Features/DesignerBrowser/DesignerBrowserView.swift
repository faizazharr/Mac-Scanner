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

                if vm.isScanning && vm.designCaches.isEmpty && vm.browsers.isEmpty {
                    loadingView
                } else {
                    metricsHub

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 420)

                    switch selectedMode {
                    case .overview: overviewSection
                    case .designCaches: designCachesSection
                    case .browsers: browsersSection
                    }
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

    // MARK: - Header & Metrics

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
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

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.pink.opacity(0.12)).frame(width: 80, height: 80)
                ProgressView().controlSize(.large).tint(.pink)
            }
            VStack(spacing: 6) {
                Text("Scanning Design Apps & Browser Footprints…")
                    .font(.headline).fontWeight(.bold)
                Text("Inspecting Figma, Adobe Creative Cloud, Sketch, Chrome, Safari, Brave, and Arc caches & extensions…")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 450)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    private var metricsHub: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            metricCard(title: "Design Apps Cache", value: ByteFormat.string(vm.totalDesignCacheBytes), subtitle: "\(vm.designCaches.count) target locations", icon: "paintbrush.fill", color: .pink)
            metricCard(title: "Browsers Cache", value: ByteFormat.string(vm.totalBrowserCacheBytes), subtitle: "From \(vm.browsers.count) browsers", icon: "globe", color: .blue)
            metricCard(title: "Total Browser Extensions", value: "\(vm.totalExtensionsCount) Extensions", subtitle: "Across all browsers", icon: "puzzlepiece.extension.fill", color: .purple)
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
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: color, opacity: 0.08)
    }

    // MARK: - Sections

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(vm.insights) { (insight: DesignerDiagnosticInsight) in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle().fill(insight.color.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: insight.icon).font(.caption.bold()).foregroundStyle(insight.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title).font(.subheadline).fontWeight(.bold)
                        Text(insight.summary).font(.caption).foregroundStyle(.secondary)
                        Text(insight.explanation).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .glassCard(tint: insight.color, opacity: 0.05)
            }
        }
    }

    private var designCachesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Installed Design Tool Caches", systemImage: "paintbrush.pointed")
                    .font(.headline).fontWeight(.bold)
                Spacer()
                if vm.totalDesignCacheBytes > 0 {
                    Button {
                        showCleanAllDesignConfirm = true
                    } label: {
                        Label("Clean All (\(ByteFormat.string(vm.totalDesignCacheBytes)))", systemImage: "sparkles")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.small)
                }
            }

            ForEach(vm.designCaches) { item in
                DesignerAppCard(item: item) {
                    pendingCleanURL = (item.path, item.appName)
                }
            }
        }
    }

    private var browsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Detected Browsers & Extensions", systemImage: "safari")
                    .font(.headline).fontWeight(.bold)
                Spacer()
            }

            ForEach(vm.browsers) { browser in
                BrowserExtensionCard(browser: browser) {
                    if let cacheURL = browser.cacheURL {
                        pendingCleanURL = (cacheURL, "\(browser.name) Cache")
                    }
                }
            }
        }
    }
}
