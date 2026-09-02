// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// The seven primary modes the app is organized into.
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

    var body: some View {
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

// MARK: - Shared Actions

@MainActor
enum FileActions {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        ToastManager.shared.show("Path copied to Clipboard", icon: "doc.on.doc.fill", tint: .blue)
    }
}

struct TrashConfirmation: ViewModifier {
    @Binding var pendingURL: URL?
    var onConfirm: (URL) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Move \"\(pendingURL?.lastPathComponent ?? "")\" to Trash?",
            isPresented: Binding(
                get: { pendingURL != nil },
                set: { if !$0 { pendingURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let url = pendingURL { onConfirm(url) }
                pendingURL = nil
            }
            Button("Cancel", role: .cancel) { pendingURL = nil }
        } message: {
            Text("This is completely reversible — the item goes to macOS Trash and is not permanently deleted.")
        }
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassCard()
    }
}

// MARK: - Browser Tab

struct BrowserView: View {
    @StateObject private var vm = BrowserViewModel()
    @State private var pendingTrash: URL?
    @State private var hoveredEntryID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Action Toolbar & Breadcrumbs
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        vm.send(.navigateUp)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(vm.currentDirectory.path == "/")
                    .help("Go up one directory level")

                    Button {
                        vm.send(.navigate(to: FileManager.default.homeDirectoryForCurrentUser))
                    } label: {
                        Image(systemName: "house.fill")
                    }
                    .help("Go to Home folder")

                    breadcrumbBar

                    Spacer()

                    Button {
                        chooseFolder()
                    } label: {
                        Label("Choose Folder…", systemImage: "folder.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        vm.send(.rescan)
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Volume Usage & Scan Status
                if vm.volumeTotal > 0 {
                    let used = vm.volumeTotal - vm.volumeFree
                    HStack {
                        Text("Volume Capacity: \(ByteFormat.string(used)) used / \(ByteFormat.string(vm.volumeFree)) free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if vm.isScanning {
                            ProgressView().controlSize(.small)
                            Text("Calculating folder sizes…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            // Visual Size Donut Breakdown
            if !vm.entries.isEmpty {
                SizeDonutChart(entries: vm.entries)
                    .padding(.horizontal, 18)
            }

            // Search & Category Filters
            HStack(spacing: 12) {
                SearchField(placeholder: "Search items in this directory…", text: $vm.searchQuery)
                    .frame(maxWidth: 320)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FileCategory.allCases, id: \.self) { cat in
                            Button {
                                vm.selectedCategory = cat
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text(cat.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    vm.selectedCategory == cat
                                        ? cat.color.opacity(0.2)
                                        : Color.secondary.opacity(0.08)
                                )
                                .foregroundStyle(vm.selectedCategory == cat ? cat.color : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(vm.selectedCategory == cat ? cat.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)

            // Items List
            if !vm.filteredEntries.isEmpty {
                let maxSize = vm.filteredEntries.map(\.sizeBytes).max() ?? 1
                List(vm.filteredEntries) { entry in
                    let isHovered = hoveredEntryID == entry.id
                    HStack(spacing: 12) {
                        // Category Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(entry.category.color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: entry.isDirectory ? "folder.fill" : entry.category.icon)
                                .font(.caption.bold())
                                .foregroundStyle(entry.category.color)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(entry.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                if entry.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Text(entry.isDirectory ? "Folder" : entry.category.rawValue)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Proportional Gradient Size Bar
                        let barWidth = 110 * CGFloat(entry.sizeBytes) / CGFloat(maxSize)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 110, height: 7)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [entry.category.color.opacity(0.7), entry.category.color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(barWidth, 3), height: 7)
                        }
                        .frame(width: 110, height: 7)

                        Text(entry.sizeString)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(width: 95, alignment: .trailing)

                        // Quick Actions on Hover
                        HStack(spacing: 4) {
                            Button {
                                FileActions.reveal(entry.url)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button {
                                FileActions.copyPath(entry.url)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Copy Path")

                            Button {
                                pendingTrash = entry.url
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Move to Trash")
                        }
                        .opacity(isHovered ? 1.0 : 0.25)
                        .frame(width: 75)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onHover { hoveredEntryID = $0 ? entry.id : nil }
                    .onTapGesture { open(entry) }
                    .contextMenu {
                        if entry.isDirectory {
                            Button("Open Folder") { open(entry) }
                        }
                        Button("Reveal in Finder") { FileActions.reveal(entry.url) }
                        Button("Copy Full Path") { FileActions.copyPath(entry.url) }
                        Divider()
                        Button("Move to Trash", role: .destructive) { pendingTrash = entry.url }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else if vm.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.blue)
                    }
                    VStack(spacing: 6) {
                        Text("Analyzing Folder Contents…")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Computing directory sizes and calculating storage breakdowns…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(vm.searchQuery.isEmpty ? "No items found in this directory." : "No matches found for \"\(vm.searchQuery)\".")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
        .onAppear { vm.send(.appear) }
    }

    private func open(_ entry: FileEntry) {
        guard entry.isDirectory else { return }
        vm.send(.navigate(to: entry.url))
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(vm.pathChain, id: \.self) { url in
                    let isCurrent = url.path == vm.currentDirectory.path
                    Button {
                        vm.send(.navigate(to: url))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: url.path == "/" ? "internaldrive" : "folder")
                                .font(.caption2)
                            Text(url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent)
                                .font(.caption)
                                .fontWeight(isCurrent ? .bold : .medium)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isCurrent ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrent)

                    if url.path != vm.pathChain.last?.path {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            vm.send(.navigate(to: url))
        }
    }
}

// MARK: - Recommendations Tab

struct RecommendationsView: View {
    @ObservedObject var vm: RecommendationsViewModel
    @State private var pendingTrash: URL?
    @State private var showBatchConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Reclaim Hero Banner
            heroReclaimBanner

            // Search & Controls Bar
            HStack(spacing: 10) {
                SearchField(placeholder: "Search targets (e.g. docker, xcode, figma)…", text: $vm.searchQuery)
                    .frame(maxWidth: 320)

                Picker("Sort by", selection: $vm.sortOption) {
                    ForEach(RecommendationsViewModel.SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 150)

                Spacer()

                if vm.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Scanning targets…").font(.caption).foregroundStyle(.secondary)
                }

                Button {
                    vm.send(.toggleSelectAllSafe)
                } label: {
                    Label("Select All Safe", systemImage: "checklist")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    vm.send(.rescan)
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)

            // Category & Risk Filters Row
            VStack(alignment: .leading, spacing: 8) {
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Category:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        filterChip(title: "All Categories", isSelected: vm.selectedCategory == nil, icon: "square.grid.2x2") {
                            vm.selectedCategory = nil
                        }
                        ForEach(RecommendationCategory.allCases, id: \.self) { cat in
                            filterChip(title: cat.rawValue, isSelected: vm.selectedCategory == cat, color: .purple, icon: cat.icon) {
                                vm.selectedCategory = (vm.selectedCategory == cat ? nil : cat)
                            }
                        }
                    }
                }

                // Safety Risks
                HStack(spacing: 6) {
                    Text("Safety:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    filterChip(title: "All Safety Levels", isSelected: vm.selectedRisk == nil) {
                        vm.selectedRisk = nil
                    }
                    ForEach(RiskLevel.allCases, id: \.self) { risk in
                        filterChip(title: risk.rawValue, isSelected: vm.selectedRisk == risk, color: risk.color, icon: risk.icon) {
                            vm.selectedRisk = (vm.selectedRisk == risk ? nil : risk)
                        }
                    }

                    Spacer()

                    Pill(text: "\(vm.filteredResults.count) Targets", color: .secondary)
                }
            }
            .padding(.horizontal, 18)

            // Recommendation Cards List
            if !vm.filteredResults.isEmpty {
                List(vm.filteredResults) { rec in
                    let isSelected = vm.selectedIDs.contains(rec.id)
                    HStack(alignment: .top, spacing: 14) {
                        // Multi-select Checkbox
                        if rec.risk != .manual {
                            Button {
                                if isSelected {
                                    vm.selectedIDs.remove(rec.id)
                                } else {
                                    vm.selectedIDs.insert(rec.id)
                                }
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        } else {
                            Image(systemName: "hand.raised.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                                .frame(width: 22)
                                .padding(.top, 2)
                        }

                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(rec.risk.color.opacity(0.14))
                                .frame(width: 34, height: 34)
                            Image(systemName: rec.iconName)
                                .font(.body.bold())
                                .foregroundStyle(rec.risk.color)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(rec.title)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Pill(text: rec.risk.rawValue, color: rec.risk.color, icon: rec.risk.icon)
                                Pill(text: rec.category.rawValue, color: .secondary, icon: rec.category.icon)
                            }
                            Text(rec.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(rec.path.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        // Size & Action Buttons
                        VStack(alignment: .trailing, spacing: 6) {
                            Text(rec.sizeBytes > 0 ? ByteFormat.string(rec.sizeBytes) : "—")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)

                            HStack(spacing: 6) {
                                Button {
                                    FileActions.reveal(rec.path)
                                } label: {
                                    Label("Reveal", systemImage: "arrow.up.forward.app")
                                        .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                if rec.title.contains("Docker Data") {
                                    Button {
                                        vm.send(.dockerSmartPrune)
                                    } label: {
                                        Label("Smart Prune", systemImage: "sparkles")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                    .controlSize(.mini)
                                } else if rec.title.contains("iOS/Simulator") {
                                    Button {
                                        vm.send(.simulatorCleanUnavailable)
                                    } label: {
                                        Label("Clean Old", systemImage: "sparkles")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .controlSize(.mini)
                                } else if rec.risk != .manual {
                                    Button {
                                        pendingTrash = rec.path
                                    } label: {
                                        Label("Trash", systemImage: "trash")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.mini)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .glassCard(tint: isSelected ? .green : .secondary, opacity: isSelected ? 0.12 : 0.05)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button("Reveal in Finder") { FileActions.reveal(rec.path) }
                        Button("Copy Path") { FileActions.copyPath(rec.path) }
                        if rec.risk != .manual {
                            Button("Move to Trash", role: .destructive) { pendingTrash = rec.path }
                        }
                    }
                }
                .listStyle(.plain)
            } else if vm.isScanning {
                VStack(spacing: 16) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .controlSize(.large)
                            .tint(.green)
                    }
                    VStack(spacing: 6) {
                        Text("Scanning Cleanup Targets & Disk Junk…")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Analyzing Xcode DerivedData, Docker VM storage, simulator runtime caches, user logs, and Trash…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 450)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("No cleanup targets found in this category.")
                        .font(.headline)
                    Text("Your Mac is clean and organized.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
        .confirmationDialog(
            "Clean \(vm.selectedIDs.count) Selected Targets (\(ByteFormat.string(vm.totalSelectedBytes)))?",
            isPresented: $showBatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Move Selected to Trash", role: .destructive) {
                vm.send(.moveSelectedToTrash)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These items will be moved to your Trash. Reversible anytime.")
        }
    }

    private var heroReclaimBanner: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 54, height: 54)
                Image(systemName: "sparkles")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(ByteFormat.string(vm.totalSafeReclaimable))
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("100% Safe to Clean")
                        .font(.headline)
                        .fontWeight(.semibold)

                    if vm.totalCautionReclaimable > 0 {
                        Pill(text: "\(ByteFormat.string(vm.totalCautionReclaimable)) Review First", color: .orange, icon: "exclamationmark.triangle.fill")
                    }
                }
                Text("App & web caches, build artifacts, designer canvas caches, and temp logs. (Docker & Simulator terlindungi oleh Smart Clean).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if vm.totalSelectedBytes > 0 {
                Button {
                    showBatchConfirm = true
                } label: {
                    Label("Clean Selected (\(ByteFormat.string(vm.totalSelectedBytes)))", systemImage: "trash.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
            }
        }
        .padding(18)
        .glassCard(tint: .green, opacity: 0.10)
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private func filterChip(title: String, isSelected: Bool, color: Color = .blue, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Large Files Tab

struct LargeFilesView: View {
    @StateObject private var vm = LargeFilesViewModel()
    @State private var pendingTrash: URL?
    @State private var showBatchConfirm = false

    private let sizePresets: [Int] = [100, 250, 500, 1000, 2500, 5000]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Controls: Scope, Threshold & Scan Action
            VStack(alignment: .leading, spacing: 10) {
                // Top Row: Scope, Thresholds & Actions
                HStack(spacing: 10) {
                    // Scope Picker
                    Menu {
                        ForEach(LargeFilesViewModel.ScanScope.allCases) { scope in
                            Button {
                                if scope == .custom {
                                    chooseCustomFolder()
                                } else {
                                    vm.scanScope = scope
                                    vm.send(.rescan)
                                }
                            } label: {
                                Label(scope.rawValue, systemImage: scope.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: vm.scanScope.icon)
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text(vm.scanScope == .custom && vm.customScopeURL != nil ? vm.customScopeURL!.lastPathComponent : vm.scanScope.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassCard()
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Divider().frame(height: 18)

                    // Size Threshold Presets in a scrollable horizontal container
                    Text("Threshold:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sizePresets, id: \.self) { mb in
                                Button {
                                    vm.minMB = mb
                                    vm.send(.rescan)
                                } label: {
                                    Text(mb >= 1000 ? "\(mb / 1000) GB" : "\(mb) MB")
                                        .font(.caption2)
                                        .fontWeight(vm.minMB == mb ? .bold : .medium)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(vm.minMB == mb ? Color.purple.opacity(0.2) : Color.secondary.opacity(0.08))
                                        .foregroundStyle(vm.minMB == mb ? Color.purple : Color.primary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(vm.minMB == mb ? Color.purple.opacity(0.4) : Color.clear, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // Sort Picker
                    Picker("Sort", selection: $vm.sortOption) {
                        ForEach(LargeFilesViewModel.SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 145)

                    // Scan / Refresh Button
                    Button {
                        vm.send(.rescan)
                    } label: {
                        HStack(spacing: 5) {
                            if vm.isScanning {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(vm.isScanning ? "Scanning…" : "Scan Now")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .disabled(vm.isScanning)
                    .fixedSize()
                }

                // Filter & Search Row
                HStack(spacing: 12) {
                    SearchField(placeholder: "Search file name or extension…", text: $vm.searchQuery)
                        .frame(maxWidth: 280)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(FileCategory.allCases, id: \.self) { cat in
                                Button {
                                    vm.selectedCategory = cat
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon).font(.caption2)
                                        Text(cat.rawValue)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        vm.selectedCategory == cat
                                            ? cat.color.opacity(0.2)
                                            : Color.secondary.opacity(0.08)
                                    )
                                    .foregroundStyle(vm.selectedCategory == cat ? cat.color : .primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(vm.selectedCategory == cat ? cat.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // Category Summary Analytics Bar
            if !vm.categoryBreakdown.isEmpty && !vm.isScanning {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.categoryBreakdown, id: \.category) { item in
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(item.category.color.opacity(0.15))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(item.category.color)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.category.rawValue)
                                        .font(.system(size: 11, weight: .bold))
                                    Text("\(item.count) files • \(ByteFormat.string(item.totalBytes))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassCard(tint: item.category.color, opacity: 0.08)
                            .onTapGesture {
                                vm.selectedCategory = (vm.selectedCategory == item.category ? .all : item.category)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }

            // Status & Batch Actions Bar
            if !vm.filteredFiles.isEmpty && !vm.isScanning {
                HStack {
                    HStack(spacing: 8) {
                        Text("\(vm.filteredFiles.count) Large Files Found")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("• Total: \(ByteFormat.string(vm.totalFilteredBytes))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if vm.totalSelectedBytes > 0 {
                        Button {
                            showBatchConfirm = true
                        } label: {
                            Label("Trash Selected (\(ByteFormat.string(vm.totalSelectedBytes)))", systemImage: "trash.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }

                    Button {
                        vm.send(.toggleSelectAll)
                    } label: {
                        Text(vm.selectedIDs.count == vm.filteredFiles.count ? "Deselect All" : "Select All")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 18)
            }

            // Content Area: Scanning State, Results List, or Empty State
            if vm.isScanning {
                scanningHeroView
            } else if !vm.filteredFiles.isEmpty {
                List(vm.filteredFiles) { file in
                    let isSelected = vm.selectedIDs.contains(file.id)
                    HStack(spacing: 12) {
                        Button {
                            vm.send(.toggleSelect(file.id))
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Color.purple : Color.secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(file.category.color.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: file.category.icon)
                                .font(.caption.bold())
                                .foregroundStyle(file.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(file.url.deletingLastPathComponent().path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Pill(text: file.url.pathExtension.isEmpty ? "FILE" : file.url.pathExtension.uppercased(), color: file.category.color)

                        Text(file.sizeString)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .frame(width: 90, alignment: .trailing)

                        HStack(spacing: 6) {
                            Button {
                                FileActions.reveal(file.url)
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button {
                                pendingTrash = file.url
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Move to Trash")
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Reveal in Finder") { FileActions.reveal(file.url) }
                        Button("Copy Full Path") { FileActions.copyPath(file.url) }
                        Divider()
                        Button("Move to Trash", role: .destructive) { pendingTrash = file.url }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.purple.opacity(0.8))
                    Text("No large files found matching your filter.")
                        .font(.headline)
                    Text("Try choosing a lower threshold (e.g. 100 MB) or changing the search scope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
        .confirmationDialog(
            "Move \(vm.selectedIDs.count) Files to Trash (\(ByteFormat.string(vm.totalSelectedBytes)))?",
            isPresented: $showBatchConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                vm.send(.moveSelectedToTrash)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These items will be moved to macOS Trash and can be restored anytime.")
        }
        .onAppear {
            vm.send(.appear)
        }
    }

    // MARK: - Animated Scanning Hero State

    private var scanningHeroView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .controlSize(.large)
                    .tint(.purple)
            }

            VStack(spacing: 4) {
                Text("Scanning for Files ≥ \(vm.minMB >= 1000 ? "\(vm.minMB / 1000) GB" : "\(vm.minMB) MB")…")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("Searching \(vm.scanScope.rawValue) using fast Spotlight index…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan Folder"
        if panel.runModal() == .OK, let url = panel.url {
            vm.send(.setCustomScope(url))
        }
    }
}
