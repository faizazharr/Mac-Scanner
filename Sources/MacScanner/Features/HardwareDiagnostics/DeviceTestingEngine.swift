// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI
import AppKit
import AVFoundation

/// Key definition for Apple Mac keyboard layout.
struct KeyDef: Identifiable, Hashable {
    let id: String
    let label: String
    let sub: String?
    let keyCode: UInt16
    let widthRatio: CGFloat

    init(_ id: String, _ label: String, sub: String? = nil, code: UInt16, width: CGFloat = 1.0) {
        self.id = id
        self.label = label
        self.sub = sub
        self.keyCode = code
        self.widthRatio = width
    }
}

// Hardware Key definition for Apple Mac keyboard layout.

/// Native focusable NSView that intercepts keyboard events cleanly and safely.
final class KeyboardResponderNSView: NSView {
    var onKeyDown: ((UInt16, NSEvent.ModifierFlags, String?) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    var onFlagsChanged: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode, event.modifierFlags, event.charactersIgnoringModifiers)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        onFlagsChanged?(event.keyCode, event.modifierFlags)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// SwiftUI wrapper for KeyboardResponderNSView using standard AppKit Coordinator pattern.
struct KeyboardResponderRepresentable: NSViewRepresentable {
    @ObservedObject var engine: DeviceTestingEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeNSView(context: Context) -> KeyboardResponderNSView {
        let view = KeyboardResponderNSView()
        view.onKeyDown = { [weak coordinator = context.coordinator] code, flags, chars in
            coordinator?.engine.handleKeyDown(code: code, flags: flags, chars: chars)
        }
        view.onKeyUp = { [weak coordinator = context.coordinator] code in
            coordinator?.engine.handleKeyUp(code: code)
        }
        view.onFlagsChanged = { [weak coordinator = context.coordinator] code, flags in
            coordinator?.engine.handleFlagsChanged(code: code, flags: flags)
        }
        return view
    }

    func updateNSView(_ nsView: KeyboardResponderNSView, context: Context) {
        context.coordinator.engine = engine
    }

    final class Coordinator {
        var engine: DeviceTestingEngine
        init(engine: DeviceTestingEngine) {
            self.engine = engine
        }
    }
}

/// Backend engine for hardware testing: Audio synthesis, Mic sampling,
/// Fullscreen Dead Pixel Window, Keyboard event monitoring, and Trackpad Haptics.
@MainActor
final class DeviceTestingEngine: ObservableObject {

    // MARK: - Audio Test State

    @Published private(set) var isPlayingAudio = false
    @Published private(set) var currentlyTestingSpeaker: String? = nil

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioStopTimer: Timer?

    // MARK: - Microphone Test State

    @Published private(set) var isRecordingMic = false
    @Published private(set) var micAudioLevel: Float = 0.0
    @Published private(set) var isPlayingLoopback = false

    private var micRecorder: AVAudioRecorder?
    private var loopbackPlayer: AVAudioPlayer?
    private var micLevelTimer: Timer?
    private let micTempURL = FileManager.default.temporaryDirectory.appendingPathComponent("macscanner_mic_test.m4a")

    // MARK: - Keyboard Test State (KeyCodes, Shortcut Interception & Multi-Key Rollover)

    @Published var pressedKeyCodes: Set<UInt16> = []
    @Published var testedKeyCodes: Set<UInt16> = []
    @Published var lastKeyPressedInfo: String = "Click keyboard area and press any key or shortcut..."
    @Published var detectedShortcutName: String? = nil
    @Published var totalKeystrokes: Int = 0

    // Full Apple Mac Keyboard Layout Definition
    static let functionRow: [KeyDef] = [
        KeyDef("ESC", "esc", code: 53, width: 1.3),
        KeyDef("F1", "F1", sub: "🔅", code: 122),
        KeyDef("F2", "F2", sub: "🔆", code: 120),
        KeyDef("F3", "F3", sub: "🪟", code: 99),
        KeyDef("F4", "F4", sub: "🔍", code: 118),
        KeyDef("F5", "F5", sub: "🎙️", code: 96),
        KeyDef("F6", "F6", sub: "🌙", code: 97),
        KeyDef("F7", "F7", sub: "⏮", code: 98),
        KeyDef("F8", "F8", sub: "⏯", code: 100),
        KeyDef("F9", "F9", sub: "⏭", code: 101),
        KeyDef("F10", "F10", sub: "🔇", code: 109),
        KeyDef("F11", "F11", sub: "🔉", code: 103),
        KeyDef("F12", "F12", sub: "🔊", code: 111),
        KeyDef("PWR", "⏻", code: 108, width: 1.3)
    ]

    static let numberRow: [KeyDef] = [
        KeyDef("Tilde", "`", sub: "~", code: 50),
        KeyDef("1", "1", sub: "!", code: 18),
        KeyDef("2", "2", sub: "@", code: 19),
        KeyDef("3", "3", sub: "#", code: 20),
        KeyDef("4", "4", sub: "$", code: 21),
        KeyDef("5", "5", sub: "%", code: 23),
        KeyDef("6", "6", sub: "^", code: 22),
        KeyDef("7", "7", sub: "&", code: 26),
        KeyDef("8", "8", sub: "*", code: 28),
        KeyDef("9", "9", sub: "(", code: 25),
        KeyDef("0", "0", sub: ")", code: 29),
        KeyDef("Minus", "-", sub: "_", code: 27),
        KeyDef("Equal", "=", sub: "+", code: 24),
        KeyDef("Delete", "delete", code: 51, width: 1.6)
    ]

    static let qwertyRow: [KeyDef] = [
        KeyDef("Tab", "tab", code: 48, width: 1.5),
        KeyDef("Q", "Q", code: 12),
        KeyDef("W", "W", code: 13),
        KeyDef("E", "E", code: 14),
        KeyDef("R", "R", code: 15),
        KeyDef("T", "T", code: 17),
        KeyDef("Y", "Y", code: 16),
        KeyDef("U", "U", code: 32),
        KeyDef("I", "I", code: 34),
        KeyDef("O", "O", code: 31),
        KeyDef("P", "P", code: 35),
        KeyDef("LBracket", "[", sub: "{", code: 33),
        KeyDef("RBracket", "]", sub: "}", code: 30),
        KeyDef("Backslash", "\\", sub: "|", code: 42, width: 1.2)
    ]

    static let asdfRow: [KeyDef] = [
        KeyDef("Caps", "caps lock", code: 57, width: 1.8),
        KeyDef("A", "A", code: 0),
        KeyDef("S", "S", code: 1),
        KeyDef("D", "D", code: 2),
        KeyDef("F", "F", code: 3),
        KeyDef("G", "G", code: 5),
        KeyDef("H", "H", code: 4),
        KeyDef("J", "J", code: 38),
        KeyDef("K", "K", code: 40),
        KeyDef("L", "L", code: 37),
        KeyDef("Semicolon", ";", sub: ":", code: 41),
        KeyDef("Quote", "'", sub: "\"", code: 39),
        KeyDef("Return", "return", code: 36, width: 1.8)
    ]

    static let zxcvRow: [KeyDef] = [
        KeyDef("Shift_L", "shift", code: 56, width: 2.2),
        KeyDef("Z", "Z", code: 6),
        KeyDef("X", "X", code: 7),
        KeyDef("C", "C", code: 8),
        KeyDef("V", "V", code: 9),
        KeyDef("B", "B", code: 11),
        KeyDef("N", "N", code: 45),
        KeyDef("M", "M", code: 46),
        KeyDef("Comma", ",", sub: "<", code: 43),
        KeyDef("Dot", ".", sub: ">", code: 47),
        KeyDef("Slash", "/", sub: "?", code: 44),
        KeyDef("Shift_R", "shift", code: 60, width: 2.2)
    ]

    static let bottomRow: [KeyDef] = [
        KeyDef("Fn", "fn 🌐", code: 63, width: 1.1),
        KeyDef("Ctrl_L", "⌃ control", code: 59, width: 1.2),
        KeyDef("Opt_L", "⌥ option", code: 58, width: 1.2),
        KeyDef("Cmd_L", "⌘ command", code: 55, width: 1.4),
        KeyDef("Space", "space", code: 49, width: 5.5),
        KeyDef("Cmd_R", "⌘ command", code: 54, width: 1.4),
        KeyDef("Opt_R", "⌥ option", code: 61, width: 1.2),
        KeyDef("Left", "◀", code: 123, width: 1.0),
        KeyDef("Down", "▼", code: 125, width: 1.0),
        KeyDef("Up", "▲", code: 126, width: 1.0),
        KeyDef("Right", "▶", code: 124, width: 1.0)
    ]

    static var totalStandardKeyCount: Int {
        functionRow.count + numberRow.count + qwertyRow.count + asdfRow.count + zxcvRow.count + bottomRow.count
    }

    // MARK: - Dead Pixel Colors

    struct TestColor: Identifiable {
        let id = UUID()
        let name: String
        let color: NSColor
        let purpose: String
    }

    static let screenColors: [TestColor] = [
        TestColor(name: "Pure White", color: .white, purpose: "Detects black dead pixels & panel dust."),
        TestColor(name: "Pure Black", color: .black, purpose: "Detects bright stuck pixels & backlight bleed."),
        TestColor(name: "Pure Red", color: .red, purpose: "Detects defective red sub-pixels."),
        TestColor(name: "Pure Green", color: .green, purpose: "Detects defective green sub-pixels."),
        TestColor(name: "Pure Blue", color: .blue, purpose: "Detects defective blue sub-pixels."),
        TestColor(name: "50% Neutral Gray", color: NSColor(white: 0.5, alpha: 1.0), purpose: "Detects panel uniformity and dirty screen effect (DSE)."),
        TestColor(name: "Magenta", color: .magenta, purpose: "Detects color calibration consistency."),
        TestColor(name: "Cyan", color: .cyan, purpose: "Detects color calibration consistency.")
    ]

    @Published var currentColorIndex = 0

    deinit {
        audioStopTimer?.invalidate()
        micLevelTimer?.invalidate()
    }

    // MARK: - 1. Speaker Stereo & Frequency Test

    func playTone(frequency: Double, pan: Float, duration: Double = 1.0, channelName: String) {
        stopAudio()

        isPlayingAudio = true
        currentlyTestingSpeaker = channelName

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        player.pan = pan

        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            stopAudio()
            return
        }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData!
        let theta = 2.0 * .pi * frequency / sampleRate

        for frame in 0..<Int(frameCount) {
            let progress = Double(frame) / Double(frameCount)
            let envelope: Double
            if progress < 0.05 {
                envelope = progress / 0.05
            } else if progress > 0.85 {
                envelope = (1.0 - progress) / 0.15
            } else {
                envelope = 1.0
            }

            let val = Float(sin(theta * Double(frame)) * 0.4 * envelope)
            channels[0][frame] = val
            channels[1][frame] = val
        }

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

            self.audioEngine = engine
            self.playerNode = player

            audioStopTimer = Timer.scheduledTimer(withTimeInterval: duration + 0.1, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stopAudio()
                }
            }
        } catch {
            stopAudio()
        }
    }

    func playFrequencySweep() {
        stopAudio()
        isPlayingAudio = true
        currentlyTestingSpeaker = "Sweep (60Hz – 8000Hz)"

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let duration = 2.5
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            stopAudio()
            return
        }
        buffer.frameLength = frameCount

        let channels = buffer.floatChannelData!
        let startFreq = 60.0
        let endFreq = 8000.0

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let freq = startFreq * pow(endFreq / startFreq, t / duration)
            let val = Float(sin(2.0 * .pi * freq * t) * 0.35)
            channels[0][frame] = val
            channels[1][frame] = val
        }

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

            self.audioEngine = engine
            self.playerNode = player

            audioStopTimer = Timer.scheduledTimer(withTimeInterval: duration + 0.1, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stopAudio()
                }
            }
        } catch {
            stopAudio()
        }
    }

    func stopAudio() {
        audioStopTimer?.invalidate()
        audioStopTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        isPlayingAudio = false
        currentlyTestingSpeaker = nil
    }

    // MARK: - 2. Microphone Test & Loopback

    func startMicSampling() {
        stopMicSampling()

        try? FileManager.default.removeItem(at: micTempURL)

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard granted else {
                    ToastManager.shared.show("Microphone permission required", icon: "mic.slash.fill", tint: .orange)
                    return
                }
                self.beginMicRecording()
            }
        }
    }

    private func beginMicRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: micTempURL, settings: settings)
            recorder.isMeteringEnabled = true
            let started = recorder.record(forDuration: 3.0)
            guard started else {
                ToastManager.shared.show("Unable to start audio recording", icon: "mic.slash.fill", tint: .orange)
                return
            }

            self.micRecorder = recorder
            self.isRecordingMic = true

            micLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard let rec = self.micRecorder, rec.isRecording else {
                        self.finishMicRecording()
                        return
                    }
                    rec.updateMeters()
                    let power = rec.averagePower(forChannel: 0)
                    let normalized = max(0.0, min(1.0, (power + 50.0) / 50.0))
                    self.micAudioLevel = normalized
                }
            }
        } catch {
            ToastManager.shared.show("Microphone access error", icon: "mic.slash.fill", tint: .red)
        }
    }

    private func finishMicRecording() {
        micLevelTimer?.invalidate()
        micLevelTimer = nil
        micRecorder?.stop()
        micRecorder = nil
        isRecordingMic = false
        micAudioLevel = 0.0

        do {
            let player = try AVAudioPlayer(contentsOf: micTempURL)
            self.loopbackPlayer = player
            self.isPlayingLoopback = true
            player.play()

            Timer.scheduledTimer(withTimeInterval: player.duration + 0.2, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isPlayingLoopback = false
                    self?.loopbackPlayer = nil
                }
            }
            ToastManager.shared.show("Playing back 3-second recording", icon: "waveform", tint: .green)
        } catch {
            // Player failed
        }
    }

    func stopMicSampling() {
        micLevelTimer?.invalidate()
        micLevelTimer = nil
        micRecorder?.stop()
        micRecorder = nil
        loopbackPlayer?.stop()
        loopbackPlayer = nil
        isRecordingMic = false
        isPlayingLoopback = false
        micAudioLevel = 0.0
    }

    // MARK: - 3. EIZO-Grade Screen Diagnostics Suite

    @Published var isScreenTestActive: Bool = false
    @Published var selectedScreenCategory: ScreenTestCategory = .defectivePixels
    @Published var currentPatternIndex: Int = 0
    @Published var isHUDVisible: Bool = true
    @Published var motionSpeed: Double = 480.0 // pixels per second

    private var wasWindowOriginallyFullscreen: Bool = false
    private var keyEventMonitor: Any?

    var currentCategoryPatterns: [ScreenTestItem] {
        ScreenTestCatalog.patterns(for: selectedScreenCategory)
    }

    var currentPattern: ScreenTestItem {
        let patterns = currentCategoryPatterns
        guard !patterns.isEmpty else {
            return ScreenTestCatalog.allPatterns[0]
        }
        let safeIndex = max(0, min(currentPatternIndex, patterns.count - 1))
        return patterns[safeIndex]
    }

    func launchDeadPixelTester(category: ScreenTestCategory = .defectivePixels) {
        selectedScreenCategory = category
        currentPatternIndex = 0
        isHUDVisible = true
        isScreenTestActive = true

        // Seamlessly enter native macOS Fullscreen on the main app window
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

    func exitDeadPixelTester() {
        isScreenTestActive = false
        stopKeyEventMonitoring()

        // Seamlessly restore normal window state if entered for the test
        if let window = NSApp.windows.first(where: { $0.canBecomeKey && $0.isVisible }),
           window.styleMask.contains(.fullScreen),
           !wasWindowOriginallyFullscreen {
            window.toggleFullScreen(nil)
        }
    }

    func selectCategory(_ category: ScreenTestCategory) {
        selectedScreenCategory = category
        currentPatternIndex = 0
        flashHUD()
    }

    func nextPattern() {
        let count = currentCategoryPatterns.count
        guard count > 0 else { return }
        currentPatternIndex = (currentPatternIndex + 1) % count
        flashHUD()
    }

    func previousPattern() {
        let count = currentCategoryPatterns.count
        guard count > 0 else { return }
        currentPatternIndex = (currentPatternIndex - 1 + count) % count
        flashHUD()
    }

    func toggleHUD() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHUDVisible.toggle()
        }
    }

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

    func handleFullscreenKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // ESC
            exitDeadPixelTester()
            return true
        case 49, 36, 124: // Space, Enter, Right Arrow
            nextPattern()
            return true
        case 123: // Left Arrow
            previousPattern()
            return true
        case 4: // 'H' Key
            toggleHUD()
            return true
        case 18: // '1'
            selectCategory(.defectivePixels)
            return true
        case 19: // '2'
            selectCategory(.uniformity)
            return true
        case 20: // '3'
            selectCategory(.gradients)
            return true
        case 21: // '4'
            selectCategory(.colorDistances)
            return true
        case 23: // '5'
            selectCategory(.sharpness)
            return true
        case 22: // '6'
            selectCategory(.gamma)
            return true
        case 26: // '7'
            selectCategory(.motion)
            return true
        default:
            return false
        }
    }

    // MARK: - 4. Direct First-Responder Keyboard Event Handlers

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
        case 56, 60: // Shift L / R
            isDown = flags.contains(.shift)
        case 55, 54: // Command L / R
            isDown = flags.contains(.command)
        case 58, 61: // Option L / R
            isDown = flags.contains(.option)
        case 59, 62: // Control L / R
            isDown = flags.contains(.control)
        case 57: // Caps Lock
            isDown = flags.contains(.capsLock)
        case 63: // Fn / Globe
            isDown = flags.contains(.function)
        default:
            isDown = false
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

    /// Identifies and describes standard macOS shortcut combinations when pressed.
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

    func humanName(for code: UInt16, chars: String?) -> String {
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
            if let chars = chars, !chars.isEmpty {
                return chars.uppercased()
            }
            return "Key #\(code)"
        }
    }

    func resetKeyboardTest() {
        pressedKeyCodes.removeAll()
        testedKeyCodes.removeAll()
        detectedShortcutName = nil
        totalKeystrokes = 0
        lastKeyPressedInfo = "Matrix reset. Press any key or shortcut to test..."
    }

    // MARK: - 5. Trackpad & Haptic Feedback

    func triggerHapticFeedback(pattern: NSHapticFeedbackManager.FeedbackPattern = .generic) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

/// Fullscreen EIZO-Grade Display & Monitor Diagnostics Suite View
struct DeadPixelFullscreenView: View {
    @ObservedObject var engine: DeviceTestingEngine
    @State private var hideHUDTimer: Timer?

    var body: some View {
        let pattern = engine.currentPattern

        ZStack {
            // Pattern Canvas Renderer
            ScreenTestCanvasView(pattern: pattern, motionSpeed: engine.motionSpeed)
                .ignoresSafeArea()

            // Floating EIZO Navigation & Status HUD
            if engine.isHUDVisible {
                VStack(spacing: 12) {
                    // Category Selection Pills
                    HStack(spacing: 8) {
                        ForEach(ScreenTestCategory.allCases) { cat in
                            Button {
                                engine.selectCategory(cat)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text(cat.rawValue)
                                        .font(.caption)
                                        .fontWeight(engine.selectedScreenCategory == cat ? .bold : .medium)
                                    Text("[\(cat.shortcutNumber)]")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .opacity(0.7)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    engine.selectedScreenCategory == cat
                                        ? Color.blue
                                        : Color.black.opacity(0.65)
                                )
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(engine.selectedScreenCategory == cat ? 0.8 : 0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Pattern Info & Dismiss Toolbar
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(pattern.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)

                                let items = engine.currentCategoryPatterns
                                if items.count > 1 {
                                    Text("(\(engine.currentPatternIndex + 1) / \(items.count))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }

                            Text(pattern.purpose)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))

                            Text(pattern.instructions)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Spacer()

                        // Previous / Next Buttons
                        if engine.currentCategoryPatterns.count > 1 {
                            Button {
                                engine.previousPattern()
                            } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)

                            Button {
                                engine.nextPattern()
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }

                        // Exit Fullscreen Button
                        Button {
                            engine.exitDeadPixelTester()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Exit (ESC)")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom Hotkey Reference
                    HStack {
                        Text("Click / [Space / →] Next • [←] Prev • [1-7] Category • [H] Toggle HUD • [ESC] Exit")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Color.black
                        .opacity(0.85)
                        .blur(radius: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(18)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            engine.nextPattern()
            flashHUD()
        }
        .onHover { isHovered in
            if isHovered {
                flashHUD()
            }
        }
        .onAppear {
            scheduleHUDAutoHide()
        }
    }

    private func flashHUD() {
        withAnimation(.easeInOut(duration: 0.2)) {
            engine.isHUDVisible = true
        }
        scheduleHUDAutoHide()
    }

    private func scheduleHUDAutoHide() {
        hideHUDTimer?.invalidate()
        hideHUDTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    engine.isHUDVisible = false
                }
            }
        }
    }
}

/// Canvas rendering individual EIZO test patterns
struct ScreenTestCanvasView: View {
    let pattern: ScreenTestItem
    let motionSpeed: Double

    var body: some View {
        switch pattern.category {
        case .defectivePixels:
            solidColorView(for: pattern.id)

        case .uniformity:
            uniformityView(for: pattern.id)

        case .gradients:
            gradientView(for: pattern.id)

        case .colorDistances:
            colorDistancesView(for: pattern.id)

        case .sharpness:
            sharpnessView(for: pattern.id)

        case .gamma:
            gammaView(for: pattern.id)

        case .motion:
            motionResponseView()
        }
    }

    // 1. Defective Pixels
    @ViewBuilder
    private func solidColorView(for id: String) -> some View {
        switch id {
        case "pixel_white": Color.white
        case "pixel_black": Color.black
        case "pixel_red": Color(red: 1, green: 0, blue: 0)
        case "pixel_green": Color(red: 0, green: 1, blue: 0)
        case "pixel_blue": Color(red: 0, green: 0, blue: 1)
        case "pixel_cyan": Color(red: 0, green: 1, blue: 1)
        case "pixel_magenta": Color(red: 1, green: 0, blue: 1)
        case "pixel_yellow": Color(red: 1, green: 1, blue: 0)
        case "pixel_gray50": Color(white: 0.5)
        default: Color.white
        }
    }

    // 2. Uniformity
    @ViewBuilder
    private func uniformityView(for id: String) -> some View {
        switch id {
        case "unif_100": Color(white: 1.0)
        case "unif_75": Color(white: 0.75)
        case "unif_50": Color(white: 0.50)
        case "unif_25": Color(white: 0.25)
        default: Color(white: 0.5)
        }
    }

    // 3. Gradients
    @ViewBuilder
    private func gradientView(for id: String) -> some View {
        switch id {
        case "grad_gray_h":
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)

        case "grad_gray_v":
            LinearGradient(colors: [.black, .white], startPoint: .top, endPoint: .bottom)

        case "grad_rgb_bars":
            VStack(spacing: 0) {
                LinearGradient(colors: [.black, .red], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .green], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .blue], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
            }

        case "grad_spectrum":
            LinearGradient(
                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                startPoint: .leading,
                endPoint: .trailing
            )

        default:
            LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
        }
    }

    // 4. Color Distances & Dynamic Range
    @ViewBuilder
    private func colorDistancesView(for id: String) -> some View {
        if id == "dist_near_black" {
            // 10 near-black tiles (0% to 10%) on black field
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    Text("Near-Black Shadow Range Steps")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(0..<10) { step in
                            let val = Double(step) * 0.01 + 0.01 // 1% to 10%
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: val))
                                    .frame(width: 80, height: 80)
                                Text("\(Int(val * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
        } else if id == "dist_near_white" {
            // 10 near-white tiles (90% to 100%) on white field
            ZStack {
                Color.white
                VStack(spacing: 20) {
                    Text("Near-White Highlight Steps")
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.8))

                    HStack(spacing: 12) {
                        ForEach(0..<10) { step in
                            let val = 0.90 + Double(step) * 0.01 // 90% to 99%
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(white: val))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                    )
                                Text("\(Int(val * 100))%")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.7))
                            }
                        }
                    }
                }
            }
        } else {
            // Saturation Step Matrix
            ZStack {
                Color.black
                VStack(spacing: 16) {
                    Text("Saturation Distinguishability Matrix")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    let colors: [Color] = [.red, .green, .blue, .cyan, .purple, .yellow]
                    VStack(spacing: 10) {
                        ForEach(colors.indices, id: \.self) { cIdx in
                            HStack(spacing: 8) {
                                ForEach([0.80, 0.88, 0.94, 1.0], id: \.self) { sat in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colors[cIdx].opacity(sat))
                                        .frame(width: 100, height: 42)
                                        .overlay(
                                            Text("\(Int(sat * 100))%")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.white)
                                        )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Sharpness & Lines
    @ViewBuilder
    private func sharpnessView(for id: String) -> some View {
        if id == "sharp_1px_grid" {
            GeometryReader { geo in
                Canvas { context, size in
                    let step: CGFloat = 16
                    var path = Path()
                    for x in stride(from: 0, to: size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, to: size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
                }
                .drawingGroup()
                .background(Color.black)
            }
        } else if id == "sharp_convergence" {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    // Center and 4-corner convergence crosshairs
                    Canvas { context, size in
                        let centers = [
                            CGPoint(x: size.width / 2, y: size.height / 2),
                            CGPoint(x: 100, y: 100),
                            CGPoint(x: size.width - 100, y: 100),
                            CGPoint(x: 100, y: size.height - 100),
                            CGPoint(x: size.width - 100, y: size.height - 100)
                        ]
                        var path = Path()
                        for c in centers {
                            for r in stride(from: 10, through: 70, by: 15) {
                                path.addEllipse(in: CGRect(x: c.x - CGFloat(r), y: c.y - CGFloat(r), width: CGFloat(r * 2), height: CGFloat(r * 2)))
                            }
                        }
                        context.stroke(path, with: .color(.white), lineWidth: 1)
                    }
                    .drawingGroup()
                }
            }
        } else {
            // Multi-scale typography
            ZStack {
                Color.white
                VStack(alignment: .leading, spacing: 14) {
                    Text("MacScanner Display Typography & Subpixel Antialiasing Scale:")
                        .font(.headline)
                        .foregroundStyle(.black)

                    Divider()

                    ForEach([8, 10, 12, 14, 18, 24, 28], id: \.self) { pts in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(pts)pt:")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 45, alignment: .leading)
                            Text("The quick brown fox jumps over the lazy dog • 1234567890 • QWERTYUIOPASDFGHJKLZXCVBNM")
                                .font(.system(size: CGFloat(pts)))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(40)
            }
        }
    }

    // 6. Gamma 2.2
    @ViewBuilder
    private func gammaView(for id: String) -> some View {
        if id == "gamma_ramp" {
            // 16-step luminance grayscale ramp
            ZStack {
                Color.black
                VStack(spacing: 20) {
                    Text("Gamma 2.2 16-Step Grayscale Ramp")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        ForEach(0..<16) { step in
                            let norm = Double(step) / 15.0
                            let lum = pow(norm, 2.2)
                            VStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color(white: lum))
                                    .frame(maxWidth: .infinity, maxHeight: 240)
                                Text(String(format: "%.2f", lum))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        } else {
            // Gamma 2.2 Checkerboard target
            ZStack {
                Color(white: 0.5)
                VStack(spacing: 16) {
                    Text("Gamma 2.2 Optical Blending Target")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ZStack {
                        Rectangle()
                            .fill(Color(white: 0.5))
                            .frame(width: 200, height: 200)

                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 200, height: 200)

                        Text("2.2")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.6))
                    }
                    Text("Step back 2-3 meters: the inner box should blend into the 50% neutral gray field.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    // 7. Motion Response & Ghosting (Smooth 60/120Hz Animation)
    @ViewBuilder
    private func motionResponseView() -> some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let width = geo.size.width
                let time = timeline.date.timeIntervalSinceReferenceDate
                let period = max(1.0, width / motionSpeed)
                let progress = (time.truncatingRemainder(dividingBy: period)) / period
                let posX = progress * width

                ZStack {
                    Color.black

                    // Background track guidelines
                    VStack(spacing: 80) {
                        Divider().background(Color.white.opacity(0.2))
                        Divider().background(Color.white.opacity(0.2))
                        Divider().background(Color.white.opacity(0.2))
                    }

                    // Track 1: High Contrast White Block (Testing Black -> White -> Black response)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 80, height: 50)
                        .position(x: posX, y: geo.size.height * 0.35)

                    // Track 2: Saturated Red Block (Testing Color Shift & Overdrive Trails)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 80, height: 50)
                        .position(x: (posX + width * 0.3).truncatingRemainder(dividingBy: width), y: geo.size.height * 0.50)

                    // Track 3: High Contrast Cyan Block
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan)
                        .frame(width: 80, height: 50)
                        .position(x: (posX + width * 0.6).truncatingRemainder(dividingBy: width), y: geo.size.height * 0.65)
                }
            }
        }
        .drawingGroup()
    }
}

