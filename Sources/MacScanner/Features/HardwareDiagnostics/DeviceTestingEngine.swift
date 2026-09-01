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

    // MARK: - 3. Screen Dead Pixel In-App Tester

    @Published var isScreenTestActive: Bool = false
    private var fullscreenWindow: NSWindow?
    private var keyEventMonitor: Any?

    func launchDeadPixelTester() {
        currentColorIndex = 0
        isScreenTestActive = true
        presentFullscreenWindow()
    }

    func exitDeadPixelTester() {
        isScreenTestActive = false
        closeFullscreenWindow()
    }

    private func presentFullscreenWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: DeadPixelFullscreenView(engine: self))
        window.makeKeyAndOrderFront(nil)

        self.fullscreenWindow = window

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isScreenTestActive else { return event }
            if event.keyCode == 53 { // ESC
                self.exitDeadPixelTester()
                return nil
            } else if event.keyCode == 49 || event.keyCode == 36 || event.keyCode == 124 { // Space, Enter, Right Arrow
                self.nextDeadPixelColor()
                return nil
            } else if event.keyCode == 123 { // Left Arrow
                self.previousDeadPixelColor()
                return nil
            }
            return event
        }
    }

    private func closeFullscreenWindow() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        fullscreenWindow?.close()
        fullscreenWindow = nil
    }

    func nextDeadPixelColor() {
        currentColorIndex = (currentColorIndex + 1) % Self.screenColors.count
    }

    func previousDeadPixelColor() {
        currentColorIndex = (currentColorIndex - 1 + Self.screenColors.count) % Self.screenColors.count
    }

    var currentScreenTestColor: TestColor {
        Self.screenColors[currentColorIndex]
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

/// In-App Fullscreen Overlay view for Dead Pixel & Backlight Bleed inspection.
struct DeadPixelFullscreenView: View {
    @ObservedObject var engine: DeviceTestingEngine
    @State private var showHUD: Bool = true
    @State private var hideHUDTimer: Timer?

    var body: some View {
        let testColor = engine.currentScreenTestColor
        let isLight = testColor.name == "Pure White" || testColor.name == "Cyan"

        ZStack {
            Color(nsColor: testColor.color)
                .ignoresSafeArea()

            if showHUD {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Text(testColor.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(isLight ? .black : .white)

                        Text("•")
                            .foregroundStyle(isLight ? .black : .white)

                        Text(testColor.purpose)
                            .font(.subheadline)
                            .foregroundStyle(isLight ? .black.opacity(0.8) : .white.opacity(0.8))

                        Spacer()

                        Button {
                            engine.exitDeadPixelTester()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Exit Fullscreen (ESC)")
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

                    HStack {
                        Text("Click screen / press [Space] to switch color • [← / →] previous/next • [ESC] exit")
                            .font(.caption)
                            .foregroundStyle(isLight ? .black.opacity(0.6) : .white.opacity(0.6))
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    (isLight ? Color.white : Color.black)
                        .opacity(0.75)
                        .blur(radius: 10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            engine.nextDeadPixelColor()
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
            showHUD = true
        }
        scheduleHUDAutoHide()
    }

    private func scheduleHUDAutoHide() {
        hideHUDTimer?.invalidate()
        hideHUDTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showHUD = false
                }
            }
        }
    }
}
