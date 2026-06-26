import AVFoundation
import AppKit

enum SoundEvent: String, CaseIterable {
    case clipCaptured      = "clipCaptured"
    case pasteFromPanel    = "pasteFromPanel"
    case clipPinned        = "clipPinned"
    case incognitoOn       = "incognitoOn"
    case incognitoOff      = "incognitoOff"
    case duplicateBlocked  = "duplicateBlocked"

    var displayName: String {
        switch self {
        case .clipCaptured:     return "Clip captured"
        case .pasteFromPanel:   return "Paste from panel"
        case .clipPinned:       return "Clip pinned"
        case .incognitoOn:      return "Incognito on"
        case .incognitoOff:     return "Incognito off"
        case .duplicateBlocked: return "Duplicate detected"
        }
    }

    var defaultOn: Bool {
        switch self {
        case .clipCaptured: return false   // opt-in per PRD
        default:            return true
        }
    }

    // Tone spec: (frequency Hz, duration s, volume 0-1, shape)
    fileprivate var toneSpec: ToneSpec {
        switch self {
        case .clipCaptured:
            return ToneSpec(freq: 880, duration: 0.05, volume: 0.12, shape: .tick)
        case .pasteFromPanel:
            return ToneSpec(freq: 110, duration: 0.18, volume: 0.55, shape: .thud)
        case .clipPinned:
            return ToneSpec(freq: 528, duration: 0.14, volume: 0.40, shape: .snap)
        case .incognitoOn:
            return ToneSpec(freq: 196, duration: 0.28, volume: 0.38, shape: .fade)
        case .incognitoOff:
            return ToneSpec(freq: 294, duration: 0.26, volume: 0.38, shape: .fade)
        case .duplicateBlocked:
            return ToneSpec(freq: 90,  duration: 0.12, volume: 0.35, shape: .thud)
        }
    }
}

class SoundManager {
    static let shared = SoundManager()

    private let engine      = AVAudioEngine()
    private let playerNode  = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var masterOn: Bool { UserDefaults.standard.bool(forKey: "clipr.sound.master") }
    private var masterVolume: Float {
        let v = UserDefaults.standard.float(forKey: "clipr.sound.volume")
        return v == 0 ? 0.7 : v   // default 70%
    }

    private init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!)
        try? engine.start()
        // Set master on by default on first launch
        if UserDefaults.standard.object(forKey: "clipr.sound.master") == nil {
            UserDefaults.standard.set(true, forKey: "clipr.sound.master")
        }
        if UserDefaults.standard.object(forKey: "clipr.sound.volume") == nil {
            UserDefaults.standard.set(Float(0.7), forKey: "clipr.sound.volume")
        }
        // Set per-event defaults on first launch
        for event in SoundEvent.allCases {
            let key = "clipr.sound.\(event.rawValue)"
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(event.defaultOn, forKey: key)
            }
        }
    }

    func play(_ event: SoundEvent) {
        guard masterOn else { return }
        guard UserDefaults.standard.bool(forKey: "clipr.sound.\(event.rawValue)") else { return }
        // Respect DND / Focus
        guard !isDoNotDisturbActive() else { return }

        let buffer = generateBuffer(spec: event.toneSpec)
        if playerNode.isPlaying { playerNode.stop() }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.volume = masterVolume
        playerNode.play()
    }

    // MARK: - Buffer generation

    private func generateBuffer(spec: ToneSpec) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(sampleRate * spec.duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer  = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let left  = buffer.floatChannelData![0]
        let right = buffer.floatChannelData![1]

        for i in 0..<Int(frameCount) {
            let t        = Double(i) / sampleRate
            let progress = Double(i) / Double(frameCount)
            let envelope = spec.shape.envelope(t: progress, duration: spec.duration)
            let sine     = Float(sin(2 * .pi * spec.freq * t))
            let sample   = sine * Float(envelope) * spec.volume
            left[i]  = sample
            right[i] = sample
        }
        return buffer
    }

    // MARK: - DND detection

    private func isDoNotDisturbActive() -> Bool {
        // Check Focus/DND via UserNotifications — conservative: if we can't tell, allow sounds
        false   // TODO: hook into CNFocusFilter when targeting macOS 12+
    }
}

// MARK: - Tone specification

fileprivate struct ToneSpec {
    let freq: Double
    let duration: Double
    let volume: Float
    let shape: EnvelopeShape
}

fileprivate enum EnvelopeShape {
    case tick   // instant attack, very fast decay
    case thud   // instant attack, medium exponential decay
    case snap   // fast attack, punchy mid decay
    case fade   // smooth attack and decay

    func envelope(t: Double, duration: Double) -> Double {
        switch self {
        case .tick:
            return t < 0.1 ? 1.0 : max(0, 1.0 - (t - 0.1) / 0.9)
        case .thud:
            return t < 0.05 ? t / 0.05 : exp(-6 * (t - 0.05))
        case .snap:
            return t < 0.08 ? t / 0.08 : exp(-4 * (t - 0.08))
        case .fade:
            let attack = min(t / 0.15, 1.0)
            let decay  = t > 0.5 ? max(0, 1.0 - (t - 0.5) / 0.5) : 1.0
            return attack * decay
        }
    }
}
