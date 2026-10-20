import Foundation

/// What a HomeKit lamp should show at one moment of a sunrise.
nonisolated struct LampState: Equatable, Sendable {
    var isOn: Bool
    /// 0...100, as HomeKit expects.
    var brightness: Int
    /// 0...360 and 0...100, for color lamps.
    var hue: Double
    var saturation: Double
    /// Color temperature for white-only lamps, in mireds (1,000,000 / kelvin).
    var mireds: Int
    /// Late in the sunrise, lamps that do both look better on their white channel.
    var prefersWhite: Bool

    static let off = LampState(isOn: false, brightness: 0, hue: 0, saturation: 0, mireds: 500, prefersWhite: false)
}

extension SunriseCurve {
    /// Lamps follow the screen: the same hue path, and brightness rising on the same curve.
    func lampState(at progress: Double) -> LampState {
        let t = min(max(progress, 0), 1)
        guard t > 0 else { return .off }

        let (hue, saturation) = style.color(at: t).hueSaturation
        // Warm white until halfway, then easing to the style's end temperature.
        let whiteT = min(max((t - 0.45) / 0.55, 0), 1)
        let eased = whiteT * whiteT * (3 - 2 * whiteT)
        let kelvin = 2000 + (style.endKelvin - 2000) * eased

        return LampState(
            isOn: true,
            brightness: max(1, Int((frame(at: t).screenBrightness * 100).rounded())),
            hue: hue,
            saturation: saturation,
            mireds: Int((1_000_000 / kelvin).rounded()),
            prefersWhite: t >= 0.62
        )
    }
}

extension LightColor {
    /// Hue in degrees and saturation in percent.
    nonisolated var hueSaturation: (hue: Double, saturation: Double) {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        guard maxC > 0, delta > 0 else { return (0, 0) }

        var hue: Double
        if maxC == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == green {
            hue = 60 * ((blue - red) / delta + 2)
        } else {
            hue = 60 * ((red - green) / delta + 4)
        }
        if hue < 0 { hue += 360 }
        return (hue, delta / maxC * 100)
    }
}
