// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Helper for macOS Full Disk Access detection and guidance.
@MainActor
enum PermissionHelper {

    /// Checks whether the app has Full Disk Access (FDA) by attempting to read a protected path.
    static var hasFullDiskAccess: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // ~/Library/Safari or ~/Library/Containers/com.apple.mail is TCC protected
        let testPath = home.appendingPathComponent("Library/Safari")
        let fm = FileManager.default
        return (try? fm.contentsOfDirectory(atPath: testPath.path)) != nil
    }

    /// Opens System Settings directly to Privacy & Security ▸ Full Disk Access.
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
            ToastManager.shared.show("Opened System Settings ▸ Full Disk Access", icon: "gearshape.fill", tint: .blue)
        }
    }
}

/// A non-intrusive banner that prompts the user to grant Full Disk Access once
/// so they never have to press "Allow" repeatedly for every single folder.
struct FullDiskAccessBanner: View {
    @State private var hasAccess: Bool = PermissionHelper.hasFullDiskAccess
    @State private var isDismissed: Bool = false

    var body: some View {
        if !hasAccess && !isDismissed {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bebas Izin Berulang: Aktifkan Full Disk Access")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Aktifkan sekali di System Settings agar MacScanner dapat memindai semua folder tanpa perlu menekan tombol 'Allow' berkali-kali.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    PermissionHelper.openFullDiskAccessSettings()
                } label: {
                    Label("Buka Pengaturan", systemImage: "arrow.up.forward.app")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    withAnimation { isDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .glassCard(tint: .blue, opacity: 0.10)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                hasAccess = PermissionHelper.hasFullDiskAccess
            }
        }
    }
}
