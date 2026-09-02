// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Visual card inspecting web browser footprints: on-disk cache bloat and installed extension manifests.
///
/// Evaluates memory-heavy extension candidates and provides direct links to native browser extension management tabs.
struct BrowserExtensionCard: View {
    let browser: BrowserInfo
    let onCleanCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(browser.tintColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: browser.icon)
                        .font(.body.bold())
                        .foregroundStyle(browser.tintColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(browser.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        Pill(text: "\(browser.extensions.count) Extensions", color: browser.tintColor)
                    }

                    Text("Cache Footprint: \(ByteFormat.string(browser.cacheBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Open Extensions") {
                    DesignerBrowserScanner.openBrowserExtensionPage(browserName: browser.name)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if browser.cacheBytes > 10 * 1024 * 1024 {
                    Button {
                        onCleanCache()
                    } label: {
                        Label("Clean Cache", systemImage: "trash")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                }
            }

            if !browser.extensions.isEmpty {
                Divider().opacity(0.4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Installed Extensions:")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                        ForEach(browser.extensions) { ext in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(ext.isHeavyCandidate ? Color.orange : Color.blue.opacity(0.6))
                                    .frame(width: 6, height: 6)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ext.name)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                    if !ext.version.isEmpty {
                                        Text("v\(ext.version)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                if ext.isHeavyCandidate {
                                    Pill(text: "Heavy", color: .orange)
                                }
                            }
                            .padding(8)
                            .glassCard(tint: ext.isHeavyCandidate ? .orange : .secondary, opacity: 0.05)
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassCard(tint: browser.tintColor, opacity: 0.06)
    }
}
