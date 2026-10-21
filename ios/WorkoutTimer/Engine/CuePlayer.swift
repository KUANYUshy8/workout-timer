import AVFoundation

/// Plays the beeps and spoken cues. While a workout runs it keeps a silent loop going,
/// which (with the "audio" background mode) keeps the timer alive when the phone is locked
/// or another app is in front. It mixes with music instead of stopping it.
final class CuePlayer {
    enum Cue: Hashable { case prep, work, rest, reset, tick, finish }

    var onInterruption: (() -> Void)?

    private let engine = AVAudioEngine()
    private let tonePlayer = AVAudioPlayerNode()
    private let silencePlayer = AVAudioPlayerNode()
    private let synth = AVSpeechSynthesizer()
    private let format: AVAudioFormat
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var silence: AVAudioPCMBuffer?
    private var wantsRunning = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(tonePlayer)
        engine.attach(silencePlayer)
        engine.connect(tonePlayer, to: engine.mainMixerNode, format: format)
        engine.connect(silencePlayer, to: engine.mainMixerNode, format: format)

        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.restartIfNeeded()
        }
    }

    // MARK: Session

    func start() {
        wantsRunning = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        startEngine()
    }

    func stop() {
        wantsRunning = false
        synth.stopSpeaking(at: .immediate)
        tonePlayer.stop()
        silencePlayer.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() {
        if !engine.isRunning {
            engine.prepare()
            do { try engine.start() } catch { return }
        }
        if !silencePlayer.isPlaying {
            silencePlayer.scheduleBuffer(silenceBuffer(), at: nil, options: .loops, completionHandler: nil)
            silencePlayer.play()
        }
        if !tonePlayer.isPlaying { tonePlayer.play() }
    }

    private func restartIfNeeded() {
        guard wantsRunning else { return }
        tonePlayer.stop()
        silencePlayer.stop()
        startEngine()
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            if wantsRunning { onInterruption?() }
        } else if wantsRunning {
            try? AVAudioSession.sharedInstance().setActive(true)
            restartIfNeeded()
        }
    }

    // MARK: Cues

    func play(_ cue: Cue) {
        if !engine.isRunning { startEngine() }
        guard engine.isRunning else { return }
        tonePlayer.scheduleBuffer(buffer(for: cue), at: nil, options: .interrupts, completionHandler: nil)
        if !tonePlayer.isPlaying { tonePlayer.play() }
    }

    func speak(_ text: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW") ?? AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.05)
        utterance.volume = 1
        synth.speak(utterance)
    }

    func stopSpeaking() {
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: Tone synthesis

    private struct Tone {
        let freq: Double
        let dur: Double
        let vol: Float
        let delay: Double
    }

    private func tones(for cue: Cue) -> [Tone] {
        switch cue {
        case .prep:
            return [Tone(freq: 620, dur: 0.16, vol: 0.5, delay: 0)]
        case .work:
            return [Tone(freq: 880, dur: 0.10, vol: 0.5, delay: 0),
                    Tone(freq: 1320, dur: 0.26, vol: 0.55, delay: 0.12)]
        case .rest:
            return [Tone(freq: 523, dur: 0.40, vol: 0.5, delay: 0)]
        case .reset:
            return [Tone(freq: 659, dur: 0.16, vol: 0.5, delay: 0),
                    Tone(freq: 440, dur: 0.42, vol: 0.5, delay: 0.18)]
        case .tick:
            return [Tone(freq: 988, dur: 0.09, vol: 0.45, delay: 0)]
        case .finish:
            return [Tone(freq: 523, dur: 0.16, vol: 0.5, delay: 0),
                    Tone(freq: 659, dur: 0.16, vol: 0.5, delay: 0.14),
                    Tone(freq: 784, dur: 0.16, vol: 0.5, delay: 0.28),
                    Tone(freq: 1047, dur: 0.50, vol: 0.55, delay: 0.42)]
        }
    }

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer {
        if let cached = buffers[cue] { return cached }
        let list = tones(for: cue)
        let rate = format.sampleRate
        let length = (list.map { $0.delay + $0.dur }.max() ?? 0.1) + 0.05
        let frames = AVAudioFrameCount(length * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        let count = Int(frames)
        for i in 0..<count { data[i] = 0 }
        for tone in list {
            let start = Int(tone.delay * rate)
            let n = Int(tone.dur * rate)
            let attack = max(1, Int(0.012 * rate))
            for k in 0..<n {
                let idx = start + k
                if idx >= count { break }
                let t = Double(k) / rate
                let env: Float
                if k < attack {
                    env = Float(k) / Float(attack)
                } else {
                    env = Float(exp(-6.0 * Double(k - attack) / Double(max(1, n - attack))))
                }
                data[idx] += tone.vol * env * Float(sin(2 * Double.pi * tone.freq * t))
            }
        }
        buffers[cue] = buf
        return buf
    }

    private func silenceBuffer() -> AVAudioPCMBuffer {
        if let s = silence { return s }
        let frames = AVAudioFrameCount(format.sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) { data[i] = 0 }
        silence = buf
        return buf
    }
}
