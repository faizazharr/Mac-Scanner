// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import Combine

/// Manages temporary visual toast alerts (e.g., "Moved to Trash", "Copied to Clipboard").
@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
        let tint: Color
    }

    @Published private(set) var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, icon: String = "checkmark.circle.fill", tint: Color = .green) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            currentToast = Toast(message: message, icon: icon, tint: tint)
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self.currentToast = nil
            }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = toastManager.currentToast {
                HStack(spacing: 8) {
                    Image(systemName: toast.icon)
                        .foregroundStyle(toast.tint)
                        .font(.body.bold())
                    Text(toast.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(toast.tint.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
