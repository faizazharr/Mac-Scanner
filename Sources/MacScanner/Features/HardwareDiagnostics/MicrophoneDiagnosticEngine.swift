// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AVFoundation

/// Real-time microphone input sampler and audio loopback diagnostic engine.
///
/// Samples acoustic input decibel levels for real-time VU meter visualizations,
/// records a temporary 3-second sample, and plays it back immediately to verify clarity.
@MainActor
final class MicrophoneDiagnosticEngine: ObservableObject {

    /// True if audio recording from the microphone is currently active.
    @Published private(set) var isRecordingMic: Bool = false

    /// Normalized input level between `0.0` (silence) and `1.0` (peak volume) for UI visual meters.
    @Published private(set) var micAudioLevel: Float = 0.0

    /// True if the 3-second recorded sample is currently playing back through the speakers.
    @Published private(set) var isPlayingLoopback: Bool = false

    private var micRecorder: AVAudioRecorder?
    private var loopbackPlayer: AVAudioPlayer?
    private var micLevelTimer: Timer?
    private let micTempURL = FileManager.default.temporaryDirectory.appendingPathComponent("macscanner_mic_test.m4a")

    // MARK: - Sampling & Recording

    /// Starts a 3-second audio recording session with real-time decibel metering.
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
            // Loopback player initialization failed
        }
    }

    /// Stops any active microphone recording or loopback playback immediately.
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

    deinit {
        micLevelTimer?.invalidate()
        micRecorder?.stop()
        loopbackPlayer?.stop()
    }
}
