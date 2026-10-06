import AVFoundation
import AppKit

/// 100% offline happy sounds — synthesised in code, no audio files needed.
/// Safe for App Store sale, works with sandbox, respects Sound on/off.
final class SoundManager {
    static let shared = SoundManager()
    var enabled = true

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?

    private init() {}

    private func tone(freq: Float, duration: Float = 0.18, type: ToneType = .sine, volume: Float = 0.35) {
        guard enabled else { return }
        do {
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)
            let sampleRate: Float = 44_100
            let frames = AVAudioFrameCount(sampleRate * duration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0), frameCapacity: frames) else { return }
            buffer.frameLength = frames
            let channels = buffer.floatChannelData!
            for f in 0..<Int(frames) {
                let t = Float(f) / sampleRate
                let env = 1.0 - Float(f) / Float(frames)  // decay
                let v: Float
                switch type {
                case .sine: v = sin(2 * Float.pi * freq * t)
                case .square: v = sin(2 * Float.pi * freq * t) > 0 ? 0.6 : -0.6
                case .sparkle: v = sin(2 * Float.pi * freq * t) * 0.6 + sin(2 * Float.pi * freq * 2 * t) * 0.3
                }
                channels[0][f] = v * volume * env
            }
            try engine.start()
            player.scheduleBuffer(buffer) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { engine.stop() }
            }
            player.play()
            // retain briefly
            self.engine = engine
            self.player = player
        } catch { /* silent for kids */ }
    }

    enum ToneType { case sine, square, sparkle }

    func pickup() { tone(freq: 880, type: .sparkle); DispatchQueue.main.asyncAfter(deadline: .now()+0.09) { self.tone(freq: 1320, type: .sparkle) } }
    func ring() { tone(freq: 660, duration: 0.22, type: .sine); DispatchQueue.main.asyncAfter(deadline: .now()+0.12) { self.tone(freq: 990, duration: 0.25, type: .sine) } }
    func fanfare() { for (i, f) in [523, 659, 784, 1046].enumerated() { DispatchQueue.main.asyncAfter(deadline: .now()+Double(i)*0.12) { self.tone(freq: Float(f), duration: 0.25, type: .square, volume: 0.25) } } }
    func boing() { tone(freq: 220, duration: 0.3, type: .sine, volume: 0.4) }
    func click() { tone(freq: 700, duration: 0.07, volume: 0.25) }

    func speak(_ text: String) {
        guard enabled else { return }
        let synth = AVSpeechSynthesizer()
        let u = AVSpeechUtterance(string: text)
        u.rate = 0.45; u.pitchMultiplier = 1.3
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }
}
