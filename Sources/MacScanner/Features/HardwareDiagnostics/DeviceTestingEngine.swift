// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import SwiftUI
import AppKit
import AVFoundation

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
        KeyDef("Ctrl_L", "control", code: 59, width: 1.1),
        KeyDef("Opt_L", "option", code: 58, width: 1.1),
        KeyDef("Cmd_L", "command", code: 55, width: 1.4),
        KeyDef("Space", "", code: 49, width: 5.5),
        KeyDef("Cmd_R", "command", code: 54, width: 1.4),
        KeyDef("Opt_R", "option", code: 61, width: 1.1),
        KeyDef("Arrow_L", "◀", code: 123, width: 0.9),
        KeyDef("Arrow_UD", "▲/▼", code: 126, width: 0.9),
        KeyDef("Arrow_R", "▶", code: 124, width: 0.9)
    ]

    static var totalStandardKeyCount: Int {
        functionRow.count + numberRow.count + qwertyRow.count + asdfRow.count + zxcvRow.count + bottomRow.count
    }

    // MARK: - 1. Professional Stereo Audio Diagnostic Sweep

    func playTone(frequency: Double, pan: Float, duration: Double = 1.0, channelName: String) {
        stopAudio()

        isPlayingAudio = true
        currentlyTestingSpeaker = channelName

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            isPlayingAudio = false
            return
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.pan = pan

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

        let duration = 2.5
        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            stopAudio()
            return
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)

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
        stopAudioTest()
    }

    func playStereoTestTone(channel: String, frequency: Double = 440.0) {
        stopAudioTest()

        isPlayingAudio = true
        currentlyTestingSpeaker = channel

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            isPlayingAudio = false
            return
        }

        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()

            let duration: Double = 1.8
            let frameCount = AVAudioFrameCount(sampleRate * duration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount

            let channels = buffer.floatChannelData
            guard let leftChannel = channels?[0], let rightChannel = channels?[1] else { return }

            let angularFreq = 2.0 * Double.pi * frequency / sampleRate

            for i in 0..<Int(frameCount) {
                let sample = Float(sin(angularFreq * Double(i)))
                let envelope: Float
                let attackFrames = Int(sampleRate * 0.05)
                let releaseFrames = Int(sampleRate * 0.1)

                if i < attackFrames {
                    envelope = Float(i) / Float(attackFrames)
                } else if i > Int(frameCount) - releaseFrames {
                    envelope = Float(Int(frameCount) - i) / Float(releaseFrames)
                } else {
                    envelope = 1.0
                }

                let finalSample = sample * envelope * 0.4

                if channel == "Left" {
                    leftChannel[i] = finalSample
                    rightChannel[i] = 0.0
                } else if channel == "Right" {
                    leftChannel[i] = 0.0
                    rightChannel[i] = finalSample
                } else {
                    leftChannel[i] = finalSample
                    rightChannel[i] = finalSample
                }
            }

            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

            self.audioEngine = engine
            self.playerNode = player

            audioStopTimer?.invalidate()
            audioStopTimer = Timer.scheduledTimer(withTimeInterval: duration + 0.1, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stopAudioTest()
                }
            }

            ToastManager.shared.show("Testing \(channel) Speaker", icon: "speaker.wave.3.fill", tint: .blue)
        } catch {
            isPlayingAudio = false
            currentlyTestingSpeaker = nil
        }
    }

    func stopAudioTest() {
        audioStopTimer?.invalidate()
        audioStopTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
        isPlayingAudio = false
        currentlyTestingSpeaker = nil
    }

    // MARK: - 2. Real-Time Microphone Decibel Input & Loopback

    func startMicSampling() {
        stopMicSampling()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: micTempURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: 3.0)
            self.micRecorder = recorder
            self.isRecordingMic = true

            ToastManager.shared.show("Recording 3-sec sample...", icon: "mic.fill", tint: .orange)

            micLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let rec = self.micRecorder, rec.isRecording else { return }
                    rec.updateMeters()
                    let power = rec.averagePower(forChannel: 0)
                    let normalized = max(0.0, min(1.0, (power + 50.0) / 50.0))
                    self.micAudioLevel = normalized
                }
            }

            Timer.scheduledTimer(withTimeInterval: 3.1, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.finishMicRecording()
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

    // MARK: - 3. Professional Screen Diagnostics Suite

    @Published var isScreenTestActive: Bool = false
    @Published var selectedScreenCategory: ScreenTestCategory = .defectivePixels
    @Published var currentPatternIndex: Int = 0
    @Published var isHUDVisible: Bool = true
    @Published var motionSpeed: Double = 480.0

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
        case 56, 60:
            isDown = flags.contains(.shift)
        case 55, 54:
            isDown = flags.contains(.command)
        case 58, 61:
            isDown = flags.contains(.option)
        case 59, 62:
            isDown = flags.contains(.control)
        case 57:
            isDown = flags.contains(.capsLock)
        case 63:
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
