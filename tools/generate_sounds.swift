// Synthesizes Firstlight's bundled sounds so the repo carries no third-party audio.
//
//   swiftc -O tools/generate_sounds.swift -o /tmp/gensounds && /tmp/gensounds <out-dir>
//
// Writes birds/rain/chimes loops (seamless, 48 s) and the morning alarm (16 s) as 16-bit WAV.
// Convert with tools/make_sounds.sh, which also runs this.

import Foundation

let sampleRate = 44_100.0

// MARK: - Deterministic randomness

struct RNG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
    mutating func bipolar() -> Double { unit() * 2 - 1 }
}

// MARK: - Buffer helpers

func makeBuffer(seconds: Double) -> [Double] {
    [Double](repeating: 0, count: Int(seconds * sampleRate))
}

func add(_ source: [Double], into buffer: inout [Double], at start: Int, gain: Double = 1) {
    for i in 0..<source.count {
        let j = start + i
        if j >= 0 && j < buffer.count { buffer[j] += source[i] * gain }
    }
}

/// Folds the tail past `loopLength` back onto the start with a crossfade so the loop is seamless.
func makeLoop(_ buffer: [Double], loopLength: Int) -> [Double] {
    var out = Array(buffer[0..<loopLength])
    let tail = buffer.count - loopLength
    for i in 0..<tail {
        let fade = Double(i) / Double(tail)
        out[i] = out[i] * fade + buffer[loopLength + i] * (1 - fade)
    }
    return out
}

func onePoleLowpass(_ input: [Double], cutoff: Double) -> [Double] {
    let a = exp(-2 * Double.pi * cutoff / sampleRate)
    var y = 0.0
    return input.map { x in
        y = (1 - a) * x + a * y
        return y
    }
}

func normalize(_ buffer: [Double], peakDB: Double = -3) -> [Double] {
    let peak = buffer.map(abs).max() ?? 1
    guard peak > 0 else { return buffer }
    let target = pow(10, peakDB / 20)
    return buffer.map { $0 / peak * target }
}

/// Soft-knee saturation that lifts quiet decays without audible clipping, so the alarm carries.
func compress(_ buffer: [Double], drive: Double) -> [Double] {
    let peak = buffer.map(abs).max() ?? 1
    guard peak > 0 else { return buffer }
    return buffer.map { tanh(drive * $0 / peak) / tanh(drive) }
}

func writeWAV(_ samples: [Double], to url: URL) throws {
    var data = Data()
    func append<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }
    let byteCount = UInt32(samples.count * 2)
    data.append(contentsOf: "RIFF".utf8); append(UInt32(36) + byteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
    append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2); append(UInt16(2)); append(UInt16(16))
    data.append(contentsOf: "data".utf8); append(byteCount)
    for s in samples {
        append(Int16(max(-1, min(1, s)) * 32_767))
    }
    try data.write(to: url)
}

// MARK: - Rain

func rain(seconds: Double, seed: UInt64) -> [Double] {
    var rng = RNG(state: seed)
    var buffer = makeBuffer(seconds: seconds)

    // Pink-ish noise bed (Paul Kellet's economy filter) with a slow swell.
    var b0 = 0.0, b1 = 0.0, b2 = 0.0
    var bed = [Double](repeating: 0, count: buffer.count)
    for i in 0..<bed.count {
        let white = rng.bipolar()
        b0 = 0.99765 * b0 + white * 0.0990460
        b1 = 0.96300 * b1 + white * 0.2965164
        b2 = 0.57000 * b2 + white * 1.0526913
        let swell = 0.85 + 0.15 * sin(2 * .pi * Double(i) / sampleRate * 0.045)
        bed[i] = (b0 + b1 + b2 + white * 0.1848) * 0.11 * swell
    }
    bed = onePoleLowpass(onePoleLowpass(bed, cutoff: 3200), cutoff: 5200)
    add(bed, into: &buffer, at: 0)

    // Individual drops: tiny filtered noise ticks, plus the odd bright plink.
    let dropCount = Int(seconds * 34)
    for _ in 0..<dropCount {
        let start = Int(rng.range(0, seconds) * sampleRate)
        let length = Int(rng.range(0.004, 0.018) * sampleRate)
        var tick = [Double](repeating: 0, count: length)
        for i in 0..<length {
            let env = exp(-Double(i) / Double(length) * 5)
            tick[i] = rng.bipolar() * env
        }
        tick = onePoleLowpass(tick, cutoff: rng.range(1800, 6000))
        add(tick, into: &buffer, at: start, gain: rng.range(0.05, 0.28))
    }
    let plinkCount = Int(seconds * 2.2)
    for _ in 0..<plinkCount {
        let start = Int(rng.range(0, seconds) * sampleRate)
        let freq = rng.range(1400, 3600)
        let length = Int(0.05 * sampleRate)
        var plink = [Double](repeating: 0, count: length)
        for i in 0..<length {
            let t = Double(i) / sampleRate
            let glide = freq * (1 + 0.25 * exp(-t * 90))
            plink[i] = sin(2 * .pi * glide * t) * exp(-t * 70)
        }
        add(plink, into: &buffer, at: start, gain: rng.range(0.03, 0.09))
    }
    return buffer
}

// MARK: - Birds

func tone(frequency: (Double) -> Double, amplitude: (Double) -> Double, seconds: Double, harmonic: Double = 0.08) -> [Double] {
    let count = Int(seconds * sampleRate)
    var out = [Double](repeating: 0, count: count)
    var phase = 0.0
    for i in 0..<count {
        let t = Double(i) / Double(count)
        let f = frequency(t)
        phase += 2 * .pi * f / sampleRate
        out[i] = (sin(phase) + harmonic * sin(2 * phase)) * amplitude(t)
    }
    return out
}

func bell(_ t: Double) -> Double { pow(sin(.pi * t), 2) }

func warbler(_ rng: inout RNG) -> [Double] {
    var call = [Double]()
    let notes = Int(rng.range(4, 9))
    var base = rng.range(2400, 3400)
    for _ in 0..<notes {
        let length = rng.range(0.06, 0.13)
        let bend = rng.range(-0.18, 0.22)
        let wobble = rng.range(18, 34)
        let f0 = base
        call += tone(
            frequency: { t in f0 * (1 + bend * t) * (1 + 0.025 * sin(2 * .pi * wobble * t * length)) },
            amplitude: bell,
            seconds: length
        )
        call += [Double](repeating: 0, count: Int(rng.range(0.02, 0.06) * sampleRate))
        base = min(max(base * rng.range(0.88, 1.14), 2100), 4200)
    }
    return call
}

func feeBee(_ rng: inout RNG) -> [Double] {
    let high = rng.range(3800, 4200)
    let low = high * rng.range(0.8, 0.86)
    var call = tone(frequency: { _ in high }, amplitude: { t in bell(t) * (0.8 + 0.2 * t) }, seconds: 0.32, harmonic: 0.02)
    call += [Double](repeating: 0, count: Int(0.05 * sampleRate))
    call += tone(frequency: { t in low * (1 - 0.02 * t) }, amplitude: bell, seconds: 0.36, harmonic: 0.02)
    return call
}

func trill(_ rng: inout RNG) -> [Double] {
    var call = [Double]()
    let chirps = Int(rng.range(10, 18))
    let top = rng.range(4800, 5600)
    for k in 0..<chirps {
        let fall = 1 - Double(k) / Double(chirps) * 0.15
        call += tone(frequency: { t in top * fall * (1 - 0.3 * t) }, amplitude: bell, seconds: 0.028)
        call += [Double](repeating: 0, count: Int(0.018 * sampleRate))
    }
    return call
}

func birds(seconds: Double, seed: UInt64) -> [Double] {
    var rng = RNG(state: seed)
    var buffer = makeBuffer(seconds: seconds)

    // Soft morning air underneath.
    var air = (0..<buffer.count).map { _ in rng.bipolar() * 0.02 }
    air = onePoleLowpass(onePoleLowpass(air, cutoff: 500), cutoff: 700)
    add(air, into: &buffer, at: 0)

    var time = 0.4
    while time < seconds - 1.5 {
        let pick = rng.unit()
        var call: [Double]
        if pick < 0.5 { call = warbler(&rng) } else if pick < 0.78 { call = feeBee(&rng) } else { call = trill(&rng) }
        let distance = rng.unit()
        if distance > 0.55 { call = onePoleLowpass(call, cutoff: 3500) }
        add(call, into: &buffer, at: Int(time * sampleRate), gain: 0.55 - distance * 0.4)
        time += rng.range(1.1, 3.4)
    }
    return buffer
}

// MARK: - Chimes

/// A tubular chime strike: inharmonic partials, each decaying at its own rate.
func chime(frequency: Double, seconds: Double = 5) -> [Double] {
    let partials: [(ratio: Double, gain: Double, decay: Double)] = [
        (1.0, 1.0, 0.9), (2.76, 0.42, 1.8), (5.40, 0.2, 3.4), (8.93, 0.09, 6.0),
    ]
    let count = Int(seconds * sampleRate)
    var out = [Double](repeating: 0, count: count)
    for i in 0..<count {
        let t = Double(i) / sampleRate
        let attack = min(1, t / 0.002)
        var s = 0.0
        for p in partials {
            s += sin(2 * .pi * frequency * p.ratio * t) * p.gain * exp(-t * p.decay)
        }
        out[i] = s * attack
    }
    return out
}

func chimes(seconds: Double, seed: UInt64) -> [Double] {
    var rng = RNG(state: seed)
    var buffer = makeBuffer(seconds: seconds)
    // C major pentatonic, two octaves up from C5.
    let scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.5]

    var time = 0.3
    while time < seconds - 2 {
        let strikes = Int(rng.range(2, 6))
        var t = time
        for _ in 0..<strikes {
            let note = scale[Int(rng.unit() * Double(scale.count)) % scale.count]
            add(chime(frequency: note), into: &buffer, at: Int(t * sampleRate), gain: rng.range(0.12, 0.3))
            t += rng.range(0.09, 0.32)
        }
        time += rng.range(2.6, 5.8)
    }
    return buffer
}

// MARK: - Morning alarm

/// A soft marimba-like note: strong fundamental, a 4x partial that dies fast, a hint of 10x.
func marimba(frequency: Double, seconds: Double = 1.6) -> [Double] {
    let count = Int(seconds * sampleRate)
    var out = [Double](repeating: 0, count: count)
    for i in 0..<count {
        let t = Double(i) / sampleRate
        let attack = min(1, t / 0.004)
        let s = sin(2 * .pi * frequency * t) * exp(-t * 3.2)
            + 0.35 * sin(2 * .pi * frequency * 4 * t) * exp(-t * 14)
            + 0.08 * sin(2 * .pi * frequency * 10 * t) * exp(-t * 40)
        out[i] = s * attack
    }
    return out
}

func morning(seconds: Double) -> [Double] {
    var buffer = makeBuffer(seconds: seconds)
    // Two phrases rising through C major, then a resolving answer; repeated twice, louder the second time.
    let phraseA: [(Double, Double)] = [(523.25, 0), (659.25, 0.22), (783.99, 0.44), (1046.5, 0.66), (987.77, 1.1), (783.99, 1.32)]
    let phraseB: [(Double, Double)] = [(587.33, 0), (698.46, 0.22), (880.0, 0.44), (1174.66, 0.66), (1046.5, 1.2)]
    for (round, gain) in [(0, 0.8), (1, 1.0)] {
        let offset = Double(round) * 8
        for (f, t) in phraseA { add(marimba(frequency: f), into: &buffer, at: Int((offset + 0.1 + t) * sampleRate), gain: gain) }
        for (f, t) in phraseB { add(marimba(frequency: f), into: &buffer, at: Int((offset + 3.4 + t) * sampleRate), gain: gain) }
    }
    return buffer
}

// MARK: - Main

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let loopSeconds = 48.0
let tailSeconds = 4.0
let loopLength = Int(loopSeconds * sampleRate)

let outputs: [(String, [Double])] = [
    ("rain", makeLoop(rain(seconds: loopSeconds + tailSeconds, seed: 11), loopLength: loopLength)),
    ("birds", makeLoop(birds(seconds: loopSeconds + tailSeconds, seed: 23), loopLength: loopLength)),
    ("chimes", makeLoop(chimes(seconds: loopSeconds + tailSeconds, seed: 37), loopLength: loopLength)),
    // The alarm doubles as the AlarmKit backup sound, so it's compressed to read as loud.
    ("morning", compress(morning(seconds: 16), drive: 3.2)),
]

for (name, samples) in outputs {
    let url = outDir.appendingPathComponent("\(name).wav")
    try writeWAV(normalize(samples, peakDB: name == "morning" ? -1 : -3), to: url)
    print("wrote \(url.path)")
}
