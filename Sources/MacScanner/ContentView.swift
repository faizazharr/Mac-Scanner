// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// The three tabs the app is organized into.
enum ScreenerTab { case browser, recommendations, largeFiles }

/// Root view: a tab bar over the three scanning modes. Owns the
/// Recommendations view model directly (rather than letting `RecommendationsView`
/// own it) so it can trigger that tab's first scan lazily, only once the tab
/// is actually opened — scanning every tab up front pegs CPU hard enough
/// that macOS can flag the app for excessive background CPU use.
struct ContentView: View {
    @State private var selection: ScreenerTab = .browser
    @StateObject private var recommendationsVM = RecommendationsViewModel()

    var body: some View {
        TabView(selection: $selection) {
            BrowserView()
                .tabItem { Label("Folder Browser", systemImage: "folder") }
                .tag(ScreenerTab.browser)

            RecommendationsView(vm: recommendationsVM)
                .tabItem { Label("Cleanup Recommendations", systemImage: "sparkles") }
                .tag(ScreenerTab.recommendations)

            LargeFilesView()
                .tabItem { Label("Large Files", systemImage: "doc.badge.gearshape") }
                .tag(ScreenerTab.largeFiles)
        }
        .padding()
        .onChange(of: selection) { _, newValue in
            if newValue == .recommendations {
                recommendationsVM.send(.appearIfNeeded)
            }
        }
    }
}

// MARK: - Shared row actions

/// Finder-adjacent actions any file/folder row can offer.
enum FileActions {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// Confirmation sheet shown before moving anything to the Trash. Reused by
/// all three tabs; the actual deletion is delegated to the caller's
/// `onConfirm` closure so each tab can route it through its own view model.
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
            Text("This is reversible — the item goes to Trash, not permanently deleted.")
        }
    }
}

/// Compact search box: magnifying-glass icon, plain text field, and a clear
/// button that only appears once there's something to clear. Shared by the
/// Folder Browser and Large Files tabs.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Browser

/// Folder Browser tab: drill into any folder, see a size breakdown (list +
/// donut chart), search within the current folder, and act on any row
/// (reveal in Finder / move to Trash).
struct BrowserView: View {
    @StateObject private var vm = BrowserViewModel()
    @State private var pendingTrash: URL?
    @State private var searchQuery = ""

    private var filteredEntries: [FileEntry] {
        guard !searchQuery.isEmpty else { return vm.entries }
        return vm.entries.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    vm.send(.navigateUp)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(vm.currentDirectory.path == "/")
                .help("Go up one level")

                Button {
                    vm.send(.navigate(to: FileManager.default.homeDirectoryForCurrentUser))
                } label: {
                    Image(systemName: "house")
                }
                .help("Go to Home folder")

                Spacer()
                Button {
                    chooseFolder()
                } label: {
                    Label("Choose Folder…", systemImage: "folder.badge.plus")
                }
                Button {
                    vm.send(.rescan)
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
            }

            breadcrumbBar

            Text(vm.currentDirectory.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            if vm.volumeTotal > 0 {
                let used = vm.volumeTotal - vm.volumeFree
                HStack {
                    Text("Volume: \(ByteFormat.string(used)) used of \(ByteFormat.string(vm.volumeTotal)) — \(ByteFormat.string(vm.volumeFree)) free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if vm.isScanning {
                        ProgressView().controlSize(.small)
                        Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if !vm.entries.isEmpty {
                SizeDonutChart(entries: vm.entries)
            }

            SearchField(placeholder: "Search in this folder", text: $searchQuery)

            if !filteredEntries.isEmpty {
                let maxSize = filteredEntries.map(\.sizeBytes).max() ?? 1
                List(filteredEntries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            .frame(width: 18)

                        Text(entry.name)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if entry.isDirectory {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Relative-size bar so the biggest space users pop out visually.
                        let barWidth = 100 * CGFloat(entry.sizeBytes) / CGFloat(maxSize)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 100, height: 8)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(0.35))
                                .frame(width: max(barWidth, 2), height: 8)
                        }
                        .frame(width: 100, height: 8)

                        Text(entry.sizeString)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { open(entry) }
                    .contextMenu {
                        if entry.isDirectory {
                            Button("Open") { open(entry) }
                        }
                        Button("Reveal in Finder") { FileActions.reveal(entry.url) }
                        Button("Move to Trash", role: .destructive) { pendingTrash = entry.url }
                    }
                }
                .listStyle(.inset)
            } else if !vm.isScanning {
                ContentUnavailableIfSupported(
                    text: searchQuery.isEmpty ? "No items found here." : "No matches for \"\(searchQuery)\"."
                )
                Spacer()
            } else {
                Spacer()
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

    /// Clickable path bar: every folder from the volume root down to the current
    /// one, so it's always clear exactly where you are and how to jump back up.
    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(vm.pathChain, id: \.self) { url in
                    let isCurrent = url.path == vm.currentDirectory.path
                    Button {
                        vm.send(.navigate(to: url))
                    } label: {
                        Text(url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent)
                            .fontWeight(isCurrent ? .semibold : .regular)
                            .foregroundStyle(isCurrent ? Color.primary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrent)

                    if url.path != vm.pathChain.last?.path {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
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

/// Falls back to a plain Text on macOS versions without ContentUnavailableView.
struct ContentUnavailableIfSupported: View {
    let text: String
    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView(text, systemImage: "tray")
        } else {
            Text(text).foregroundStyle(.secondary).padding()
        }
    }
}

// MARK: - Recommendations

/// Cleanup Recommendations tab: a risk-tagged list of known cleanup targets
/// (caches, build artifacts, backups, ...) that actually exist on this Mac.
struct RecommendationsView: View {
    @ObservedObject var vm: RecommendationsViewModel
    @State private var pendingTrash: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Common cleanup targets, checked against this Mac")
                    .font(.headline)
                Spacer()
                if vm.isScanning {
                    ProgressView().controlSize(.small)
                }
                Button("Rescan") { vm.send(.rescan) }
            }

            if !vm.results.isEmpty {
                Text("Up to \(ByteFormat.string(vm.totalReclaimable)) reclaimable from Safe/Review items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            List(vm.results) { rec in
                HStack(alignment: .top) {
                    riskDot(rec.risk)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(rec.title).bold()
                            Text(rec.risk.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(rec.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(rec.path.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(rec.sizeBytes > 0 ? ByteFormat.string(rec.sizeBytes) : "—")
                        .font(.system(.body, design: .monospaced))
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Reveal in Finder") { FileActions.reveal(rec.path) }
                    if rec.risk != .manual {
                        Button("Move to Trash", role: .destructive) { pendingTrash = rec.path }
                    }
                }
            }
            .listStyle(.inset)
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
    }

    private func riskDot(_ risk: RiskLevel) -> some View {
        Circle()
            .fill(color(for: risk))
            .frame(width: 10, height: 10)
            .padding(.top, 4)
    }

    private func color(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return .green
        case .caution: return .orange
        case .manual: return .red
        }
    }
}

// MARK: - Large Files

/// Large Files tab: every individual file at or above a chosen size
/// threshold anywhere under the home folder (excluding Library/Trash, which
/// the Recommendations tab already covers in aggregate).
struct LargeFilesView: View {
    @StateObject private var vm = LargeFilesViewModel()
    @State private var pendingTrash: URL?
    @State private var searchQuery = ""

    private var filteredFiles: [FileEntry] {
        guard !searchQuery.isEmpty else { return vm.files }
        return vm.files.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
                || $0.url.path.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Files ≥").font(.subheadline)
                Stepper(value: $vm.minMB, in: 50...5000, step: 50) {
                    Text("\(vm.minMB) MB")
                }
                .frame(width: 160)
                Spacer()
                if vm.isScanning {
                    ProgressView().controlSize(.small)
                    Text("Searching your home folder…").font(.caption).foregroundStyle(.secondary)
                }
                Button("Scan") { vm.send(.rescan) }
            }
            Text("Searches your home folder, excluding ~/Library and Trash (covered under Recommendations).")
                .font(.caption)
                .foregroundStyle(.secondary)

            SearchField(placeholder: "Search by name or path", text: $searchQuery)

            List(filteredFiles) { file in
                HStack {
                    Image(systemName: "doc")
                    VStack(alignment: .leading) {
                        Text(file.name)
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(file.sizeString)
                        .font(.system(.body, design: .monospaced))
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Reveal in Finder") { FileActions.reveal(file.url) }
                    Button("Move to Trash", role: .destructive) { pendingTrash = file.url }
                }
            }
            .listStyle(.inset)
        }
        .modifier(TrashConfirmation(pendingURL: $pendingTrash) { url in
            vm.send(.moveToTrash(url))
        })
    }
}
