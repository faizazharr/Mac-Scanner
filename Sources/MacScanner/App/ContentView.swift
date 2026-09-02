// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// The primary navigation tabs the app is organized into.
enum ScreenerTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case designerBrowsers = "Designer & Browsers"
    case browser = "Folder Browser"
    case recommendations = "Recommendations"
    case largeFiles = "Large Files"
    case performance = "Performance"
    case appUninstaller = "App Uninstaller"
    case screening = "Screen Time & Usage"
    case deviceTesting = "Hardware Test"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .designerBrowsers: return "paintbrush.pointed.fill"
        case .browser: return "folder.fill"
        case .recommendations: return "sparkles"
        case .largeFiles: return "doc.badge.gearshape.fill"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .appUninstaller: return "trash.circle.fill"
        case .screening: return "hourglass.bottomhalf.filled"
        case .deviceTesting: return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: return .blue
        case .designerBrowsers: return .pink
        case .browser: return .cyan
        case .recommendations: return .green
        case .largeFiles: return .purple
        case .performance: return .orange
        case .appUninstaller: return .indigo
        case .screening: return .purple
        case .deviceTesting: return .teal
        }
    }
}

/// Root view: A sleek macOS Sidebar layout with glassmorphic styling,
/// lazy tab activations, and global toast feedback overlay.
struct ContentView: View {
    @ObservedObject var deviceVM: DeviceInfoViewModel
    @ObservedObject var performanceVM: PerformanceViewModel

    @State private var selection: ScreenerTab = .home
    @StateObject private var designerBrowserVM = DesignerBrowserViewModel()
    @StateObject private var recommendationsVM = RecommendationsViewModel()
    @StateObject private var deviceTestingEngine = DeviceTestingEngine()

    init(deviceVM: DeviceInfoViewModel, performanceVM: PerformanceViewModel) {
        self.deviceVM = deviceVM
        self.performanceVM = performanceVM
    }

    public var body: some View {
        ZStack {
            NavigationSplitView {
                sidebar
                    .navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 285)
            } detail: {
                detailView
                    .frame(minWidth: 780, minHeight: 600)
                    .background(Color(nsColor: .windowBackgroundColor))
            }

            if deviceTestingEngine.isScreenTestActive {
                DeadPixelFullscreenView(engine: deviceTestingEngine)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(99999)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: deviceTestingEngine.isScreenTestActive)
        .withToastOverlay()
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .designerBrowsers {
                designerBrowserVM.send(.appearIfNeeded)
            }
            if newValue == .recommendations {
                recommendationsVM.send(.appearIfNeeded)
            }
            if newValue == .performance {
                performanceVM.send(.appear)
            }
            if oldValue == .performance {
                performanceVM.send(.disappear)
            }
        }
    }

    // MARK: - Modern Sidebar Navigation

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            // App Branding Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("MacScanner")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Disk & Health Monitor")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Divider().opacity(0.4)

            // Nav Links
            List(ScreenerTab.allCases, selection: $selection) { tab in
                HStack(spacing: 10) {
                    Image(systemName: tab.icon)
                        .font(.body)
                        .foregroundStyle(selection == tab ? tab.color : .secondary)
                        .frame(width: 22)

                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selection == tab ? .semibold : .regular)

                    Spacer()

                    if tab == .recommendations && recommendationsVM.totalReclaimable > 0 {
                        Pill(text: ByteFormat.string(recommendationsVM.totalReclaimable), color: .green)
                    } else if tab == .designerBrowsers && designerBrowserVM.totalDesignCacheBytes > 0 {
                        Pill(text: ByteFormat.string(designerBrowserVM.totalDesignCacheBytes), color: .pink)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .tag(tab)
            }
            .listStyle(.sidebar)

            Spacer()

            // Quick Status Footer
            if let device = deviceVM.device {
                HStack(spacing: 8) {
                    Image(systemName: "laptopcomputer")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(device.chip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Pill(text: "OK", color: .green)
                }
                .padding(10)
                .glassCard()
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .home:
            HomeView(deviceVM: deviceVM) { selection = $0 }
        case .designerBrowsers:
            DesignerBrowserView(vm: designerBrowserVM)
        case .browser:
            BrowserView()
        case .recommendations:
            RecommendationsView(vm: recommendationsVM)
        case .largeFiles:
            LargeFilesView()
        case .performance:
            PerformanceView(vm: performanceVM, deviceVM: deviceVM)
        case .appUninstaller:
            AppUninstallerView()
        case .screening:
            ScreeningView(deviceVM: deviceVM)
        case .deviceTesting:
            DeviceTestingView(engine: deviceTestingEngine, deviceVM: deviceVM)
        }
    }
}

// MARK: - Shared File Actions

@MainActor
public enum FileActions {
    public static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        ToastManager.shared.show("Path copied to Clipboard", icon: "doc.on.doc.fill", tint: .blue)
    }
}

