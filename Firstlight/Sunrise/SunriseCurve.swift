import Foundation

/// What the light should look like at one moment of a sunrise.
nonisolated struct SunriseFrame: Equatable, Sendable {
    /// The color to paint, already dimmed for the earliest minutes.
    var color: LightColor
    /// System screen brightness, 0...1.
    var screenBrightness: Double
    /// Extra exposure past SDR white for the final stretch, in stops. Zero when HDR boost is off.
    var boostStops: Double
    /// How far the "sun" has spread: 0 is a glow at the bottom edge, 1 fills the screen.
    var spread: Double
}

/// Maps sunrise progress (0 at first light, 1 at wake time) to a frame.
nonisolated struct SunriseCurve: Equatable, Sendable {
    var style: SunriseStyle
    var shape: CurveShape = .gentle
    /// Push the final white into HDR headroom on displays that have it.
    var hdrBoost: Bool = true

    /// Pixels fade up from black over this first share of the sunrise; after that only
    /// screen brightness and hue change.
    static let fadeInShare = 0.22
    /// Boost starts here and reaches `maxBoostStops` at wake time.
    static let boostStart = 0.9
    static let maxBoostStops = 1.0
    /// Below this the panel is effectively off; start just above it so the first glow shows.
    static let minimumBrightness = 0.01

    func frame(at progress: Double) -> SunriseFrame {
        let t = min(max(progress, 0), 1)

        let fade = min(t / Self.fadeInShare, 1)
        let pixelGain = fade * fade * (3 - 2 * fade)
        let color = style.color(at: t).scaled(by: pixelGain)

        let ramp = pow(t, shape.exponent)
        let brightness = Self.minimumBrightness + (1 - Self.minimumBrightness) * ramp

        let boostT = max(0, (t - Self.boostStart) / (1 - Self.boostStart))
        let boost = hdrBoost ? Self.maxBoostStops * boostT * boostT : 0

        let spread = min(1, pow(t / 0.65, 0.8))

        return SunriseFrame(color: color, screenBrightness: brightness, boostStops: boost, spread: spread)
    }

    /// Light leaving the screen relative to full white at full brightness (pixel luminance × backlight).
    func relativeOutput(at progress: Double) -> Double {
        let f = frame(at: progress)
        return f.color.luminance * f.screenBrightness
    }
}

/// Where a moment falls in the wake-up, given the wake time and sunrise length.
nonisolated struct SunriseWindow: Equatable, Sendable {
    var wake: Date
    var duration: TimeInterval

    var start: Date { wake.addingTimeInterval(-duration) }

    /// Progress 0...1 during the sunrise, nil before it, 1 after wake.
    func progress(at date: Date) -> Double? {
        if date < start { return nil }
        guard duration > 0 else { return 1 }
        return min(date.timeIntervalSince(start) / duration, 1)
    }
}
