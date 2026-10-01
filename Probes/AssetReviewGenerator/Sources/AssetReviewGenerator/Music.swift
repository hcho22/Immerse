import AVFoundation
import Foundation

enum ReviewMusic {
    /// Original draft score and additive synthesis. No recording, sample library,
    /// artist imitation or third-party melody is an input. Production review is pending.
    static func write(to url: URL) throws {
        let rate = 48_000.0, beat = 60.0 / 96.0, duration = 32.0 * 60.0 / 96.0 + 2.0
        let frames = Int(duration * rate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let samples = buffer.floatChannelData?[0] else { throw ReviewError.audioFailed }
        buffer.frameLength = AVAudioFrameCount(frames)
        for index in 0..<frames { samples[index] = 0 }
        let chords = [[48, 55, 60, 64], [43, 55, 59, 62], [45, 57, 60, 64], [41, 53, 57, 60],
                      [48, 55, 60, 64], [50, 57, 62, 65], [43, 55, 59, 62], [48, 55, 60, 64]]
        let melody = [[72, 76, 79, 76], [74, 71, 67, 71], [72, 76, 81, 79], [77, 76, 72, 69],
                      [76, 79, 84, 81], [77, 74, 69, 74], [79, 77, 74, 71], [72, 76, 72, -1]]
        func note(_ midi: Int, start: Double, length: Double, amplitude: Double, soft: Bool) {
            guard midi >= 0 else { return }
            let frequency = 440 * pow(2, Double(midi - 69) / 12)
            let first = Int(start * rate), count = min(Int(length * rate), frames - first)
            guard count > 0 else { return }
            for index in 0..<count {
                let t = Double(index) / rate
                let attack = min(1, t / 0.012)
                let release = min(1, max(0, (length - t) / 0.15))
                let envelope = attack * release * exp(-t * (soft ? 1.2 : 2.8))
                let phase = 2 * Double.pi * frequency * t
                let tone = sin(phase) + (soft ? 0.12 : 0.3) * sin(phase * 2) * exp(-t * 3)
                    + (soft ? 0.04 : 0.13) * sin(phase * 3) * exp(-t * 5)
                samples[first + index] += Float(amplitude * envelope * tone)
            }
        }
        for bar in 0..<8 {
            let start = Double(bar * 4) * beat
            note(chords[bar][0], start: start, length: beat * 3.8, amplitude: 0.12, soft: true)
            for pulse in 0..<8 {
                note(chords[bar][1 + pulse % 3], start: start + Double(pulse) * beat / 2,
                    length: beat * 1.3, amplitude: pulse % 2 == 0 ? 0.07 : 0.05, soft: false)
            }
            for pulse in 0..<4 {
                note(melody[bar][pulse], start: start + Double(pulse) * beat + 0.025,
                    length: beat * 1.6, amplitude: 0.14, soft: false)
            }
        }
        for index in 0..<frames {
            let seconds = Double(index) / rate
            samples[index] *= Float(min(1, seconds / 0.05) * min(1, max(0, (duration - seconds) / 1.5)))
            guard samples[index].isFinite, abs(samples[index]) < 0.95 else { throw ReviewError.audioFailed }
        }
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
        try file.write(from: buffer)
    }
}
