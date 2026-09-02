// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import SwiftUI
import AppKit

/// Hardware Diagnostics & Device Functionality Suite:
/// Tests Screen Dead Pixels, Stereo Speakers, Microphone, Keyboard Matrix, Trackpad Haptics, and Battery.
struct DeviceTestingView: View {
    @ObservedObject var engine: DeviceTestingEngine
    @ObservedObject var deviceVM: DeviceInfoViewModel

    @State private var trackpadClickCount = 0
    @State private var lastTrackpadAction = "Click / Force Touch here to test"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                // Diagnostics Cards Grid (Adaptive 1 or 2 columns based on window width)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 16)], spacing: 16) {
                    screenTestCard
                    speakerTestCard
                    micTestCard
                    trackpadTestCard
                }

                // Keyboard Matrix Test
                keyboardTestCard

                // Battery Diagnostics
                if let device = deviceVM.device, device.batteryCycleCount != nil || device.batteryMaxCapacityPercent != nil {
                    batteryCard(device)
                }
            }
            .padding(20)
        }
        .onDisappear {
            engine.stopAudio()
            engine.stopMicSampling()
            engine.exitDeadPixelTester()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware Diagnostics & Device Test")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Comprehensive diagnostics for screen, stereo speakers, microphone, keyboard, trackpad, and battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let device = deviceVM.device {
                Pill(text: device.chip, color: .blue)
            }
        }
    }

    // MARK: - 1. Display & Monitor Diagnostics Suite

    private var screenTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("1. Display & Monitor Diagnostics", systemImage: "display")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Pill(text: "7 Test Suites", color: .purple)
            }

            Text("Comprehensive display diagnostics: Defective Pixels, Luminance Uniformity, 10-bit Gradients, Dynamic Range, Sharpness & Typography, Gamma 2.2, and 120Hz Motion Response.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Category Chips Preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ScreenTestCategory.allCases) { cat in
                        Button {
                            engine.launchDeadPixelTester(category: cat)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                engine.launchDeadPixelTester(category: .defectivePixels)
            } label: {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Launch Fullscreen Monitor Suite")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .glassCard()
    }

    // MARK: - 2. Stereo Speaker Test

    private var speakerTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("2. Stereo Speaker L/R Test", systemImage: "speaker.wave.3.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if let current = engine.currentlyTestingSpeaker {
                    Pill(text: "Playing: \(current)", color: .blue)
                }
            }

            Text("Test independent Left & Right audio channels and frequency sweeps to detect crackling, distortion, or chassis rattle.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    engine.playTone(frequency: 440, pan: -1.0, channelName: "Left Speaker")
                } label: {
                    Label("Left Speaker", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    engine.playTone(frequency: 440, pan: 1.0, channelName: "Right Speaker")
                } label: {
                    Label("Right Speaker", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Button {
                engine.playFrequencySweep()
            } label: {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("Frequency Sweep Test (60Hz – 8000Hz)")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.regular)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .glassCard()
    }

    // MARK: - 3. Microphone Test

    private var micTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("3. Microphone & Loopback Test", systemImage: "mic.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if engine.isRecordingMic {
                    Pill(text: "Recording (3s)…", color: .red)
                } else if engine.isPlayingLoopback {
                    Pill(text: "Playing Back…", color: .green)
                }
            }

            Text("Test microphone audio sensitivity and immediately listen to playback to verify clear acoustic input.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Audio Level Meter Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Input Level:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(engine.micAudioLevel * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(engine.micAudioLevel > 0.7 ? .red : engine.micAudioLevel > 0.3 ? .green : .secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(engine.micAudioLevel)), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(8)
            .glassCard()

            Button {
                engine.startMicSampling()
            } label: {
                HStack {
                    Image(systemName: engine.isRecordingMic ? "record.circle.fill" : "mic.fill")
                    Text(engine.isRecordingMic ? "Recording Audio…" : "Record 3-Second Audio & Playback")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.isRecordingMic ? .red : .orange)
            .controlSize(.regular)
            .disabled(engine.isRecordingMic || engine.isPlayingLoopback)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .glassCard()
    }

    // MARK: - 4. Trackpad & Force Touch Haptics

    private var trackpadTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("4. Trackpad & Force Touch Test", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Pill(text: "\(trackpadClickCount) Clicks", color: .cyan)
            }

            Text("Test click responsiveness, right-click gestures, and multi-pattern haptic vibration feedback.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Click Target Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cyan.opacity(0.08))
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.cyan.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    )

                Text(lastTrackpadAction)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                trackpadClickCount += 1
                lastTrackpadAction = "Left Click Detected ✓"
                engine.triggerHapticFeedback(pattern: .generic)
            }

            HStack(spacing: 10) {
                Button("Test Haptic (Alignment)") {
                    engine.triggerHapticFeedback(pattern: .alignment)
                    lastTrackpadAction = "Haptic: Alignment Click ✓"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

                Button("Test Haptic (Level Change)") {
                    engine.triggerHapticFeedback(pattern: .levelChange)
                    lastTrackpadAction = "Haptic: Deep Force Click ✓"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .glassCard()
    }

    // MARK: - 5. Keyboard Keypress Matrix

    private var keyboardTestCard: some View {
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

    // MARK: - 6. Battery Diagnostic Card

    private func batteryCard(_ device: DeviceInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("6. Battery Health & Power Status", systemImage: "battery.100.bolt")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if let condition = device.batteryCondition {
                    Pill(text: condition, color: condition.localizedCaseInsensitiveContains("Normal") ? .green : .orange)
                }
            }

            HStack(spacing: 12) {
                if let cycles = device.batteryCycleCount {
                    diagnosticSpecTile(title: "Cycle Count", value: "\(cycles)", sub: "Charge cycles")
                }
                if let maxCap = device.batteryMaxCapacityPercent {
                    diagnosticSpecTile(title: "Maximum Capacity", value: "\(maxCap)%", sub: "Battery health")
                }
                diagnosticSpecTile(title: "Condition", value: device.batteryCondition ?? "Normal", sub: "Health status")
                diagnosticSpecTile(title: "Platform", value: device.chip, sub: device.modelName)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func diagnosticSpecTile(title: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(sub)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
