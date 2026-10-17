import SwiftUI

/// An sRGB color with components in 0...1, used for all sunrise math.
nonisolated struct LightColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static let black = LightColor(red: 0, green: 0, blue: 0)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Approximate blackbody color for a temperature in kelvin (Tanner Helland's fit), normalized so
    /// the brightest channel is 1.
    init(kelvin: Double) {
        let t = min(max(kelvin, 1000), 40000) / 100
        let r: Double = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let g: Double = t <= 66
            ? 99.4708025861 * log(t) - 161.1195681661
            : 288.1221695283 * pow(t - 60, -0.0755148492)
        let b: Double = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        let clamp = { (v: Double) in min(max(v, 0), 255) / 255 }
        self.init(red: clamp(r), green: clamp(g), blue: clamp(b))
    }

    func mixed(with other: LightColor, by amount: Double) -> LightColor {
        let t = min(max(amount, 0), 1)
        return LightColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    func scaled(by factor: Double) -> LightColor {
        LightColor(red: red * factor, green: green * factor, blue: blue * factor)
    }

    /// Relative luminance (Rec. 709 weights on linearized channels).
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// The same color pushed past SDR white by `stops` of exposure on displays with HDR headroom.
    func hdrColor(boostStops stops: Double) -> Color {
        guard stops > 0 else { return color }
        return color.exposureAdjust(stops)
    }
}
