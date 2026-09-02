// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI
import AppKit

/// Central hardware diagnostics coordinator engine.
///
/// Coordinates specialized sub-engines for audio synthesis, microphone sampling,
/// fullscreen monitor test patterns, and AppKit hardware keyboard event interception.
@MainActor
final class DeviceTestingEngine: ObservableObject {

    // MARK: - Specialized Sub-Engines

    /// Dedicated audio diagnostics tone and frequency sweep synthesizer.
    let audio = AudioDiagnosticEngine()

    /// Dedicated microphone decibel sampling and loopback recorder.
    let mic = MicrophoneDiagnosticEngine()

    // MARK: - Keyboard Test State (KeyCodes, Shortcut Interception & Multi-Key Rollover)

    /// Set of hardware key codes currently depressed in real-time.
    @Published var pressedKeyCodes: Set<UInt16> = []

    /// Set of all unique hardware key codes successfully tested during this session.
    @Published var testedKeyCodes: Set<UInt16> = []

    /// Human-readable telemetry description of the last keystroke event.
    @Published var lastKeyPressedInfo: String = "Click keyboard area and press any key or shortcut..."

    /// Detected macOS shortcut combination name if a hotkey was pressed.
    @Published var detectedShortcutName: String? = nil

    /// Total cumulative keystroke count recorded during this test session.
    @Published var totalKeystrokes: Int = 0

    // Forwarding convenience properties
    static var functionRow: [KeyDef] { KeyboardLayoutCatalog.functionRow }
    static var numberRow: [KeyDef] { KeyboardLayoutCatalog.numberRow }
    static var qwertyRow: [KeyDef] { KeyboardLayoutCatalog.qwertyRow }
    static var asdfRow: [KeyDef] { KeyboardLayoutCatalog.asdfRow }
    static var zxcvRow: [KeyDef] { KeyboardLayoutCatalog.zxcvRow }
    static var bottomRow: [KeyDef] { KeyboardLayoutCatalog.bottomRow }
    static var totalStandardKeyCount: Int { KeyboardLayoutCatalog.totalStandardKeyCount }

    var isPlayingAudio: Bool { audio.isPlayingAudio }
    var currentlyTestingSpeaker: String? { audio.currentlyTestingSpeaker }
    var isRecordingMic: Bool { mic.isRecordingMic }
    var micAudioLevel: Float { mic.micAudioLevel }
    var isPlayingLoopback: Bool { mic.isPlayingLoopback }

    // MARK: - Audio & Mic Delegations

    /// Plays a test tone on a specific stereo channel.
    func playTone(frequency: Double = 440.0, pan: Float = 0.0, duration: Double = 1.0, channelName: String) {
        audio.playTone(frequency: frequency, pan: pan, duration: duration, channelName: channelName)
    }

    /// Plays a logarithmic frequency sweep from 60 Hz to 8000 Hz across both stereo channels.
    func playFrequencySweep() {
        audio.playFrequencySweep()
    }

    /// Immediately stops any ongoing audio tests.
    func stopAudio() {
        audio.stopAudio()
    }

    /// Starts a 3-second microphone sample test with real-time decibel metering.
    func startMicSampling() {
        mic.startMicSampling()
    }

    /// Stops active microphone recording and loopback playback.
    func stopMicSampling() {
        mic.stopMicSampling()
    }

    // MARK: - Display Diagnostics Suite

    /// True if the fullscreen display diagnostic suite is active.
    @Published var isScreenTestActive: Bool = false

    /// Currently active display test category.
    @Published var selectedScreenCategory: ScreenTestCategory = .defectivePixels

    /// Index of the current test pattern within the active category.
    @Published var currentPatternIndex: Int = 0

    /// Visibility state of the floating fullscreen HUD toolbar.
    @Published var isHUDVisible: Bool = true

    /// Movement speed for the 120Hz ProMotion motion response test pattern (pixels/second).
    @Published var motionSpeed: Double = 480.0

    private var wasWindowOriginallyFullscreen: Bool = false
    private var keyEventMonitor: Any?

    var currentCategoryPatterns: [ScreenTestItem] {
        ScreenTestCatalog.patterns(for: selectedScreenCategory)
    }

    var currentPattern: ScreenTestItem {
        let patterns = currentCategoryPatterns
        guard !patterns.isEmpty else { return ScreenTestCatalog.allPatterns[0] }
        let safeIndex = max(0, min(currentPatternIndex, patterns.count - 1))
        return patterns[safeIndex]
    }

    /// Enters native macOS fullscreen mode and starts the display diagnostic suite.
    func launchDeadPixelTester(category: ScreenTestCategory = .defectivePixels) {
        selectedScreenCategory = category
        currentPatternIndex = 0
        isHUDVisible = true
        isScreenTestActive = true

        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible }) {
            if !window.styleMask.contains(.fullScreen) {
                wasWindowOriginallyFullscreen = false
                window.toggleFullScreen(nil)
            } else {
                wasWindowOriginallyFullscreen = true
            }
        }

        startKeyEventMonitoring()
    }

    /// Exits the fullscreen display diagnostic mode and restores normal window dimensions.
    func exitDeadPixelTester() {
        isScreenTestActive = false
        stopKeyEventMonitoring()

        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible }),
           window.styleMask.contains(.fullScreen),
           !wasWindowOriginallyFullscreen {
            window.toggleFullScreen(nil)
        }
    }

    /// Selects a specific display diagnostic category and resets pattern index.
    func selectCategory(_ category: ScreenTestCategory) {
        selectedScreenCategory = category
        currentPatternIndex = 0
        flashHUD()
    }

    /// Advances to the next test pattern in the current category.
    func nextPattern() {
        let count = currentCategoryPatterns.count
        guard count > 0 else { return }
        currentPatternIndex = (currentPatternIndex + 1) % count
        flashHUD()
    }

    /// Returns to the previous test pattern in the current category.
    func previousPattern() {
        let count = currentCategoryPatterns.count
        guard count > 0 else { return }
        currentPatternIndex = (currentPatternIndex - 1 + count) % count
        flashHUD()
    }

    /// Temporarily shows the HUD navigation bar.
    func flashHUD() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHUDVisible = true
        }
    }

    private func startKeyEventMonitoring() {
        stopKeyEventMonitoring()
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isScreenTestActive else { return event }
            return self.handleFullscreenKeyDown(event) ? nil : event
        }
    }

    private func stopKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    private func handleFullscreenKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: exitDeadPixelTester(); return true
        case 49, 36, 124: nextPattern(); return true
        case 123: previousPattern(); return true
        case 4: isHUDVisible.toggle(); return true
        case 18: selectCategory(.defectivePixels); return true
        case 19: selectCategory(.uniformity); return true
        case 20: selectCategory(.gradients); return true
        case 21: selectCategory(.colorDistances); return true
        case 23: selectCategory(.sharpness); return true
        case 22: selectCategory(.gamma); return true
        case 26: selectCategory(.motion); return true
        default: return false
        }
    }

    // MARK: - Keyboard Event Handling

    func handleKeyDown(code: UInt16, flags: NSEvent.ModifierFlags, chars: String?) {
        pressedKeyCodes.insert(code)
        testedKeyCodes.insert(code)
        totalKeystrokes += 1

        let keyName = humanName(for: code, chars: chars)
        let shortcut = detectShortcut(flags: flags, keyCode: code, chars: chars)

        if let shortcut = shortcut {
            detectedShortcutName = shortcut
            lastKeyPressedInfo = "⚡ Shortcut: \(shortcut) • KeyCode: \(code)"
        } else {
            detectedShortcutName = nil
            lastKeyPressedInfo = "Key: \(keyName) • Hardware KeyCode: \(code)"
        }
    }

    func handleKeyUp(code: UInt16) {
        pressedKeyCodes.remove(code)
    }

    func handleFlagsChanged(code: UInt16, flags: NSEvent.ModifierFlags) {
        let isDown: Bool
        switch code {
        case 56, 60: isDown = flags.contains(.shift)
        case 55, 54: isDown = flags.contains(.command)
        case 58, 61: isDown = flags.contains(.option)
        case 59, 62: isDown = flags.contains(.control)
        case 57: isDown = flags.contains(.capsLock)
        case 63: isDown = flags.contains(.function)
        default: isDown = false
        }

        if isDown {
            pressedKeyCodes.insert(code)
            testedKeyCodes.insert(code)
            totalKeystrokes += 1
            let name = humanName(for: code, chars: nil)
            lastKeyPressedInfo = "Modifier: \(name) • KeyCode: \(code)"
        } else {
            pressedKeyCodes.remove(code)
        }
    }

    private func detectShortcut(flags: NSEvent.ModifierFlags, keyCode: UInt16, chars: String?) -> String? {
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)
        let isOpt = flags.contains(.option)
        let isCtrl = flags.contains(.control)

        guard isCmd || isOpt || isCtrl || isShift else { return nil }
        let char = (chars ?? "").uppercased()

        if isCmd {
            if isShift {
                switch char {
                case "Z": return "⌘⇧Z (Redo)"
                case "3": return "⌘⇧3 (Fullscreen Screenshot)"
                case "4": return "⌘⇧4 (Selection Screenshot)"
                case "5": return "⌘⇧5 (Screenshot & Screen Record)"
                case "N": return "⌘⇧N (New Folder / Window)"
                default: return "⌘ ⇧ \(char)"
                }
            } else if isOpt {
                if keyCode == 53 { return "⌥⌘ESC (Force Quit Applications)" }
                return "⌥ ⌘ \(char)"
            } else if isCtrl {
                if char == "Q" { return "⌃⌘Q (Lock Screen)" }
                if char == "F" { return "⌃⌘F (Toggle Fullscreen)" }
                return "⌃ ⌘ \(char)"
            } else {
                switch char {
                case "Q": return "⌘Q (Quit Application — Intercepted)"
                case "W": return "⌘W (Close Window — Intercepted)"
                case "H": return "⌘H (Hide Application — Intercepted)"
                case "M": return "⌘M (Minimize Window — Intercepted)"
                case "C": return "⌘C (Copy)"
                case "V": return "⌘V (Paste)"
                case "X": return "⌘X (Cut)"
                case "Z": return "⌘Z (Undo)"
                case "A": return "⌘A (Select All)"
                case "S": return "⌘S (Save)"
                case "F": return "⌘F (Find)"
                case "O": return "⌘O (Open File)"
                case "P": return "⌘P (Print)"
                case "T": return "⌘T (New Tab)"
                case "R": return "⌘R (Refresh / Reload)"
                default:
                    if keyCode == 49 { return "⌘Space (Spotlight Search)" }
                    return "⌘\(char)"
                }
            }
        }

        if isCtrl && keyCode == 48 { return "⌃Tab (Switch Tabs)" }
        if isOpt && keyCode == 49 { return "⌥Space (Alternative Search)" }

        var parts: [String] = []
        if isCtrl { parts.append("⌃") }
        if isOpt { parts.append("⌥") }
        if isShift { parts.append("⇧") }
        if isCmd { parts.append("⌘") }
        if !char.isEmpty { parts.append(char) }
        return parts.joined(separator: " ")
    }

    private func humanName(for code: UInt16, chars: String?) -> String {
        switch code {
        case 53: return "ESC"
        case 48: return "Tab"
        case 57: return "Caps Lock"
        case 56: return "Left Shift"
        case 60: return "Right Shift"
        case 59: return "Left Control"
        case 62: return "Right Control"
        case 58: return "Left Option"
        case 61: return "Right Option"
        case 55: return "Left Command"
        case 54: return "Right Command"
        case 49: return "Spacebar"
        case 36: return "Return / Enter"
        case 51: return "Delete / Backspace"
        case 63: return "Fn / Globe"
        case 123: return "Left Arrow (◀)"
        case 124: return "Right Arrow (▶)"
        case 125: return "Down Arrow (▼)"
        case 126: return "Up Arrow (▲)"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let chars = chars, !chars.isEmpty { return chars.uppercased() }
            return "Key #\(code)"
        }
    }

    /// Resets the keyboard test session and clears pressed/tested key caches.
    func resetKeyboardTest() {
        pressedKeyCodes.removeAll()
        testedKeyCodes.removeAll()
        detectedShortcutName = nil
        totalKeystrokes = 0
        lastKeyPressedInfo = "Matrix reset. Press any key or shortcut to test..."
    }

    /// Triggers physical trackpad haptic vibration feedback.
    func triggerHapticFeedback(pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
