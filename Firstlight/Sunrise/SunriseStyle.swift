import Foundation

/// A color path from first glow to full daylight. Stops are hues at full intensity; the curve
/// decides how bright they get.
nonisolated struct SunriseStyle: Identifiable, Hashable, Sendable {
    struct Stop: Hashable, Sendable {
        var position: Double
        var color: LightColor
    }

    let id: String
    let name: String
    let tagline: String
    let stops: [Stop]
    let isPro: Bool

    /// Hue at a point in the sunrise, 0...1.
    func color(at progress: Double) -> LightColor {
        let t = min(max(progress, 0), 1)
        guard let first = stops.first, let last = stops.last else { return .black }
        if t <= first.position { return first.color }
        if t >= last.position { return last.color }
        for (lower, upper) in zip(stops, stops.dropFirst()) where t <= upper.position {
            let span = upper.position - lower.position
            let local = span > 0 ? (t - lower.position) / span : 1
            // Smoothstep between stops so the hue never visibly "turns a corner".
            let eased = local * local * (3 - 2 * local)
            return lower.color.mixed(with: upper.color, by: eased)
        }
        return last.color
    }
}

nonisolated extension SunriseStyle {
    static let dawn = SunriseStyle(
        id: "dawn",
        name: "Dawn",
        tagline: "Red, then amber, then white",
        stops: [
            Stop(position: 0.00, color: LightColor(hex: 0x6E0A06)),
            Stop(position: 0.18, color: LightColor(hex: 0xA3160A)),
            Stop(position: 0.36, color: LightColor(hex: 0xEE4A12)),
            Stop(position: 0.52, color: LightColor(hex: 0xFF8C2E)),
            Stop(position: 0.68, color: LightColor(kelvin: 2300)),
            Stop(position: 0.84, color: LightColor(kelvin: 3600)),
            Stop(position: 1.00, color: LightColor(kelvin: 6500)),
        ],
        isPro: false
    )

    static let ember = SunriseStyle(
        id: "ember",
        name: "Ember",
        tagline: "Stays orange, ends at 3800 K",
        stops: [
            Stop(position: 0.00, color: LightColor(hex: 0x5C0804)),
            Stop(position: 0.25, color: LightColor(hex: 0xB0200A)),
            Stop(position: 0.48, color: LightColor(hex: 0xF7631A)),
            Stop(position: 0.70, color: LightColor(hex: 0xFFA347)),
            Stop(position: 1.00, color: LightColor(kelvin: 3800)),
        ],
        isPro: true
    )

    static let coastal = SunriseStyle(
        id: "coastal",
        name: "Coastal",
        tagline: "Pinker, ends at 6000 K",
        stops: [
            Stop(position: 0.00, color: LightColor(hex: 0x4A0820)),
            Stop(position: 0.22, color: LightColor(hex: 0x8E1A40)),
            Stop(position: 0.42, color: LightColor(hex: 0xE5545A)),
            Stop(position: 0.62, color: LightColor(hex: 0xFF9A7A)),
            Stop(position: 0.82, color: LightColor(hex: 0xFFD3B5)),
            Stop(position: 1.00, color: LightColor(kelvin: 6000)),
        ],
        isPro: true
    )

    static let nordic = SunriseStyle(
        id: "nordic",
        name: "Nordic",
        tagline: "Ends in cool 7500 K white",
        stops: [
            Stop(position: 0.00, color: LightColor(hex: 0x5A0A10)),
            Stop(position: 0.28, color: LightColor(hex: 0xC2321C)),
            Stop(position: 0.50, color: LightColor(hex: 0xFF9E6A)),
            Stop(position: 0.72, color: LightColor(hex: 0xFFE2B0)),
            Stop(position: 1.00, color: LightColor(kelvin: 7500)),
        ],
        isPro: true
    )

    static let customID = "custom"

    /// Pro: Dawn's warm start, finishing at a temperature the user picks.
    static func custom(endKelvin: Double) -> SunriseStyle {
        let end = min(max(endKelvin, 2700), 7500)
        return SunriseStyle(
            id: customID,
            name: "Custom",
            tagline: "Ends at \(Int(end.rounded())) K",
            stops: [
                Stop(position: 0.00, color: LightColor(hex: 0x6E0A06)),
                Stop(position: 0.20, color: LightColor(hex: 0xA3160A)),
                Stop(position: 0.40, color: LightColor(hex: 0xEE4A12)),
                Stop(position: 0.58, color: LightColor(hex: 0xFF8C2E)),
                Stop(position: 0.76, color: LightColor(kelvin: min(2300, end))),
                Stop(position: 1.00, color: LightColor(kelvin: end)),
            ],
            isPro: true
        )
    }

    static let presets: [SunriseStyle] = [.dawn, .ember, .coastal, .nordic]

    static func resolve(id: String, customKelvin: Double) -> SunriseStyle {
        if id == customID { return .custom(endKelvin: customKelvin) }
        return presets.first { $0.id == id } ?? .dawn
    }
}

/// How quickly brightness builds. Every shape starts slow and speeds up near the end.
nonisolated enum CurveShape: String, CaseIterable, Identifiable, Sendable {
    case gentle
    case steady
    case late

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .late: "Late"
        }
    }

    var detail: String {
        switch self {
        case .gentle: "Dim for a long time, bright at the end"
        case .steady: "An even climb the whole way"
        case .late: "Stays dim longer, then gets bright fast"
        }
    }

    var exponent: Double {
        switch self {
        case .gentle: 1.9
        case .steady: 1.3
        case .late: 2.8
        }
    }

    /// Pro unlocks every shape except the default.
    var isPro: Bool { self != .gentle }
}
