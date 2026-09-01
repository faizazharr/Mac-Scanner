// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// View for Designer & Browser screening: plain-language diagnostics,
/// design apps cache cleaner, and browser extension inspector.
struct DesignerBrowserView: View {
    @ObservedObject var vm: DesignerBrowserViewModel

    private enum Mode: String, CaseIterable {
        case overview = "Diagnosis & Solusi"
        case designCaches = "Design Caches"
        case browsers = "Browser & Ekstensi"
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
                .frame(maxWidth: 380)

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
            "Bersihkan \(pendingCleanURL?.title ?? "Cache")?",
            isPresented: Binding(
                get: { pendingCleanURL != nil },
                set: { if !$0 { pendingCleanURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Pindahkan ke Trash", role: .destructive) {
                if let target = pendingCleanURL {
                    vm.send(.cleanDesignCache(target.url))
                }
                pendingCleanURL = nil
            }
            Button("Batal", role: .cancel) { pendingCleanURL = nil }
        } message: {
            Text("File cache akan dipindahkan ke Trash. Aplikasi akan mengunduh atau menyinkronkan ulang data yang diperlukan secara otomatis.")
        }
        .confirmationDialog(
            "Bersihkan Seluruh Cache Desain (\(ByteFormat.string(vm.totalDesignCacheBytes)))?",
            isPresented: $showCleanAllDesignConfirm,
            titleVisibility: .visible
        ) {
            Button("Bersihkan Semua Cache Aman", role: .destructive) {
                vm.send(.cleanAllSafeDesignCaches)
            }
            Button("Batal", role: .cancel) { }
        } message: {
            Text("Ini akan memindahkan seluruh cache Figma, Adobe, dan Sketch yang aman ke Trash.")
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
                    Text("Diagnosis awam penyebab Mac lambat, cache aplikasi kreatif, dan beban ekstensi browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if vm.isScanning {
                ProgressView().controlSize(.small)
                Text("Memindai…").font(.caption).foregroundStyle(.secondary)
            }

            Button {
                vm.send(.rescan)
            } label: {
                Label("Pindai Ulang", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Metrics Hub

    private var metricsHub: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "Cache Aplikasi Desain",
                value: ByteFormat.string(vm.totalDesignCacheBytes),
                subtitle: "\(vm.designCaches.count) target terdeteksi",
                icon: "paintbrush.fill",
                color: .pink
            )

            metricCard(
                title: "Cache Web Peramban",
                value: ByteFormat.string(vm.totalBrowserCacheBytes),
                subtitle: "Dari \(vm.browsers.count) browser",
                icon: "globe",
                color: .blue
            )

            metricCard(
                title: "Ekstensi Browser Terpasang",
                value: "\(vm.totalExtensionsCount) Ekstensi",
                subtitle: "Potensi konsumsi RAM",
                icon: "puzzlepiece.extension.fill",
                color: .orange
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

    // MARK: - Overview Section (Plain Language Diagnostics)

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("💡 Kenapa Mac Saya Terasa Berat / Lag?", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                Spacer()
            }

            ForEach(vm.insights) { insight in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(insight.color.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: insight.icon)
                            .font(.callout.bold())
                            .foregroundStyle(insight.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(insight.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        Text(insight.summary)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(insight.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let actionTitle = insight.actionTitle {
                        VStack(alignment: .trailing, spacing: 6) {
                            Button(actionTitle) {
                                if let browser = insight.browserName {
                                    DesignerBrowserScanner.openBrowserExtensionPage(browserName: browser)
                                } else if actionTitle.contains("Bersihkan"), let targetURL = insight.targetURL {
                                    pendingCleanURL = (targetURL, insight.title)
                                } else if let targetURL = insight.targetURL {
                                    NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(insight.color)

                            if insight.browserName != nil {
                                Button("Lihat Daftar Ekstensi") {
                                    withAnimation { selectedMode = .browsers }
                                }
                                .font(.caption2)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
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
            Label("Tips Mengoptimalkan Mac untuk Desain & Browser", systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 4) {
                tipRow("1. Tutup tab file Figma / Photoshop yang sudah tidak diedit agar RAM tidak terikat.")
                tipRow("2. Hindari menggunakan lebih dari satu extension ad-blocker sekaligus di browser.")
                tipRow("3. Bersihkan Adobe Media Cache secara berkala setelah menyelesaikan proyek video/motion.")
                tipRow("4. Matikan extension browser screen-recorder / video downloader saat tidak digunakan.")
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
                    Text("Target Cache Aplikasi Desain Terpasang")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Cache kanvas, preview frame render, dan autosave yang dapat dibersihkan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if vm.totalDesignCacheBytes > 0 {
                    Button {
                        showCleanAllDesignConfirm = true
                    } label: {
                        Label("Bersihkan Semua (\(ByteFormat.string(vm.totalDesignCacheBytes)))", systemImage: "trash.fill")
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
                                    Pill(text: "Aman Dibersihkan", color: .green, icon: "checkmark.shield.fill")
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
                                    Label("Bersihkan", systemImage: "trash")
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
                    Text("Tidak ada cache desain yang menumpuk.")
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
            Text("Peramban Web & Ekstensi Terpasang")
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
                    Text("Cache web: \(ByteFormat.string(browser.cacheBytes)) • \(browser.extensionsCount) Ekstensi terpasang")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let cacheURL = browser.cacheURL, browser.cacheBytes > 0 {
                    Button {
                        pendingCleanURL = (cacheURL, "\(browser.name) Cache")
                    } label: {
                        Label("Bersihkan Cache Web", systemImage: "trash")
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
                        Label("Kelola di \(browser.name)", systemImage: "gearshape.fill")
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
                    Text("Daftar Ekstensi / Add-on:")
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
                                        Pill(text: "Potensi Berat", color: .orange, icon: "flame.fill")
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
                Text("Tidak ada ekstensi yang terpasang pada browser ini.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
        }
    }
}
