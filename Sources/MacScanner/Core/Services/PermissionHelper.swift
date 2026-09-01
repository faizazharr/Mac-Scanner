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
            ToastManager.shared.show("Membuka System Settings ▸ Full Disk Access", icon: "gearshape.fill", tint: .blue)
        }
    }
}

/// An elegant Apple macOS sheet modal popup that guides users to enable Full Disk Access
/// so they can scan all system, Xcode, and browser caches with zero restriction.
struct FullDiskAccessModalView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Icon & Glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.4), radius: 12)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            // Titles
            VStack(spacing: 6) {
                Text("Buka Akses Penuh Disk")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Aktifkan izin Full Disk Access sekali saja di System Settings agar MacScanner dapat memindai folder cache, Xcode, browser, dan Docker secara menyeluruh tanpa perlu meminta izin berulang kali.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }

            // 3-Step Visual Guide
            VStack(alignment: .leading, spacing: 14) {
                stepRow(
                    step: "1",
                    title: "Klik tombol 'Buka System Settings' di bawah",
                    desc: "macOS akan langsung membuka menu Privacy & Security ▸ Full Disk Access."
                )
                stepRow(
                    step: "2",
                    title: "Nyalakan toggle di samping 'MacScanner'",
                    desc: "Gunakan Touch ID atau masukkan kata sandi Mac Anda jika diminta."
                )
                stepRow(
                    step: "3",
                    title: "Selesai & Bebas Hambatan",
                    desc: "MacScanner kini siap memindai dan membersihkan disk dengan performa maksimal."
                )
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 8)

            // Action Buttons
            VStack(spacing: 10) {
                Button {
                    PermissionHelper.openFullDiskAccessSettings()
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app.fill")
                        Text("Buka System Settings")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)

                Button {
                    isPresented = false
                } label: {
                    Text("Nanti Saja (Lanjutkan Pemindaian Terbatas)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .padding(24)
        .frame(width: 480)
    }

    private func stepRow(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                Text(step)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
