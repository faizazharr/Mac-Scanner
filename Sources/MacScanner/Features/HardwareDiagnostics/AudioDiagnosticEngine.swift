// MacScanner
// Copyright © 2026 Faiz Azhar Ristya Nugraha. All rights reserved.

import Foundation
import AVFoundation

/// High-performance audio tone synthesis engine for stereo channel diagnostics and frequency sweeps.
///
/// This engine generates pure sinusoidal audio waveforms dynamically in RAM and schedules PCM buffers
/// on an `AVAudioEngine` pipeline without relying on external audio assets or network requests.
@MainActor
final class AudioDiagnosticEngine: ObservableObject {

    /// Indicates whether a diagnostic audio sweep or test tone is currently active.
    @Published private(set) var isPlayingAudio: Bool = false

    /// Human-readable label of the speaker channel currently being tested (e.g., "Left", "Right", "Sweep").
    @Published private(set) var currentlyTestingSpeaker: String? = nil

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioStopTimer: Timer?

    // MARK: - Tone Generation

    /// Plays a pure sine wave tone on a designated stereo channel with an attack/release envelope.
    ///
    /// - Parameters:
    ///   - frequency: Acoustic tone frequency in Hertz (default 440.0 Hz).
    ///   - pan: Stereo pan position: `-1.0` (Full Left), `0.0` (Center), `1.0` (Full Right).
    ///   - duration: Tone duration in seconds.
    ///   - channelName: Speaker channel label for status toasts.
    func playTone(frequency: Double = 440.0, pan: Float = 0.0, duration: Double = 1.8, channelName: String) {
        stopAudio()

        isPlayingAudio = true
        currentlyTestingSpeaker = channelName

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            stopAudio()
            return
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.pan = pan

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            stopAudio()
            return
        }
        buffer.frameLength = frameCount

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

            ToastManager.shared.show("Testing \(channelName)", icon: "speaker.wave.3.fill", tint: .blue)
        } catch {
            stopAudio()
        }
    }

    /// Plays a logarithmic frequency sweep from 60 Hz to 8000 Hz across both stereo channels
    /// to detect chassis rattle, bass clipping, and harmonic distortion.
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
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            stopAudio()
            return
        }
        buffer.frameLength = frameCount

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

            ToastManager.shared.show("Playing Frequency Sweep (60Hz - 8kHz)", icon: "waveform.path.ecg", tint: .blue)
        } catch {
            stopAudio()
        }
    }

    /// Immediately tears down audio engines, invalidates timers, and releases hardware audio handles.
    func stopAudio() {
        audioStopTimer?.invalidate()
        audioStopTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
        isPlayingAudio = false
        currentlyTestingSpeaker = nil
    }

    deinit {
        audioStopTimer?.invalidate()
        playerNode?.stop()
        audioEngine?.stop()
    }
}
