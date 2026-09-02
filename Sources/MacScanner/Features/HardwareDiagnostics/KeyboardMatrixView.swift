// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI

/// Keyboard matrix visual test card with live multi-key rollover indicator.
struct KeyboardMatrixView: View {
    @ObservedObject var engine: DeviceTestingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Invisible native keyboard responder
            KeyboardResponderRepresentable(engine: engine)
                .frame(width: 0, height: 0)

            HStack {
                Label("5. Mac Keyboard Matrix & Shortcut Test", systemImage: "keyboard.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()

                let percentage = Int(Double(engine.testedKeyCodes.count) / Double(DeviceTestingEngine.totalStandardKeyCount) * 100)
                Pill(text: "\(engine.testedKeyCodes.count)/\(DeviceTestingEngine.totalStandardKeyCount) Keys (\(percentage)%)", color: percentage == 100 ? .green : .blue)
                Pill(text: "\(engine.totalKeystrokes) Clicks", color: .purple)

                Button {
                    engine.resetKeyboardTest()
                } label: {
                    Label("Reset Matrix", systemImage: "arrow.counterclockwise")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Real-time Keypress Telemetry Bar
            HStack(spacing: 10) {
                Circle()
                    .fill(!engine.pressedKeyCodes.isEmpty ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(engine.lastKeyPressedInfo)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(!engine.pressedKeyCodes.isEmpty ? Color.green : Color.primary)

                Spacer()

                if let shortcut = engine.detectedShortcutName {
                    Pill(text: shortcut, color: .orange, icon: "command")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(!engine.pressedKeyCodes.isEmpty ? Color.green.opacity(0.6) : Color.secondary.opacity(0.15), lineWidth: 1)
            )

            // Full Apple Keyboard Matrix (6 Rows)
            VStack(spacing: 4) {
                renderKeyRow(DeviceTestingEngine.functionRow, height: 22)
                renderKeyRow(DeviceTestingEngine.numberRow, height: 32)
                renderKeyRow(DeviceTestingEngine.qwertyRow, height: 32)
                renderKeyRow(DeviceTestingEngine.asdfRow, height: 32)
                renderKeyRow(DeviceTestingEngine.zxcvRow, height: 32)
                renderKeyRow(DeviceTestingEngine.bottomRow, height: 32)
            }
            .padding(14)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(16)
        .glassCard()
    }

    private func renderKeyRow(_ keys: [KeyDef], height: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(keys) { key in
                let isPressed = engine.pressedKeyCodes.contains(key.keyCode)
                let isTested = engine.testedKeyCodes.contains(key.keyCode)

                VStack(spacing: 0) {
                    if let sub = key.sub {
                        Text(sub)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(isPressed ? Color.black.opacity(0.8) : isTested ? Color.green.opacity(0.8) : Color.secondary)
                    }
                    Text(key.label)
                        .font(.system(size: key.label.count > 3 ? 9 : 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isPressed ? Color.black : isTested ? Color.green : Color.primary)
                }
                .frame(maxWidth: key.widthRatio * 52, minHeight: height)
                .frame(maxWidth: .infinity)
                .background(
                    isPressed
                        ? Color.green
                        : isTested
                            ? Color.green.opacity(0.28)
                            : Color.secondary.opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            isPressed
                                ? Color.green
                                : isTested
                                    ? Color.green.opacity(0.6)
                                    : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
            }
        }
    }
}
