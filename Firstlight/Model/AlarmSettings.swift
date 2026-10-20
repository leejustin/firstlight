import Foundation
import SwiftData

/// The user's one sunrise alarm. Synced through iCloud, so every property has a default and
/// nothing is unique-constrained.
@Model
final class AlarmSettings {
    var wakeHour: Int = 7
    var wakeMinute: Int = 0
    /// Bit 0 is Sunday … bit 6 is Saturday. Zero means "once".
    var repeatMask: Int = 0b0111110
    var isArmed: Bool = false
    /// For a one-off alarm, the morning it was armed for; once that passes the alarm disarms.
    var oneOffWake: Date?

    var sunriseMinutes: Int = 30
    var styleID: String = "dawn"
    var curveShapeRaw: String = "gentle"
    var customKelvin: Double = 5600
    var hdrBoost: Bool = true

    var natureSoundRaw: String = "birds"
    var soundFadeMinutes: Int = 5
    var alarmVolume: Double = 0.8
    var snoozeMinutes: Int = 9

    /// Rear flashlight fades in over the last `torchMinutes`, bounced off the wall behind the phone.
    var torchEnabled: Bool = false
    var torchMinutes: Int = 5
    var torchStrength: Double = 1.0

    /// Pro: HomeKit lamps that follow the sunrise. IDs are HomeKit service identifiers.
    var homeLampsEnabled: Bool = false
    var homeLampIDs: [String] = []

    var windDownEnabled: Bool = false
    var windDownMinutes: Int = 10

    init() {}

    /// A phone can't match a lamp's brightness, so a long sunrise mostly means more time near full
    /// brightness, where iOS may throttle for heat.
    static let sunriseRange = 1...30
    static let soundFadeRange = 1...15
    static let snoozeRange = 5...15
    static let torchMinutesRange = 1...10

    var schedule: WakeSchedule {
        get { WakeSchedule(hour: wakeHour, minute: wakeMinute, repeatMask: repeatMask) }
        set {
            wakeHour = newValue.hour
            wakeMinute = newValue.minute
            repeatMask = newValue.repeatMask
        }
    }

    var curveShape: CurveShape {
        get { CurveShape(rawValue: curveShapeRaw) ?? .gentle }
        set { curveShapeRaw = newValue.rawValue }
    }

    var natureSound: NatureSound {
        get { NatureSound(rawValue: natureSoundRaw) ?? .birds }
        set { natureSoundRaw = newValue.rawValue }
    }

    var style: SunriseStyle {
        SunriseStyle.resolve(id: styleID, customKelvin: customKelvin)
    }

    /// Sunrise length in minutes, always within `sunriseRange`. Read this rather than
    /// `sunriseMinutes`: a value saved by an older build (or another device) may be outside it.
    var sunriseLength: Int {
        get { min(max(sunriseMinutes, Self.sunriseRange.lowerBound), Self.sunriseRange.upperBound) }
        set { sunriseMinutes = min(max(newValue, Self.sunriseRange.lowerBound), Self.sunriseRange.upperBound) }
    }

    var sunriseDuration: TimeInterval {
        TimeInterval(sunriseLength * 60)
    }

    /// The curve as configured, with Pro-only choices falling back to the free defaults.
    func curve(isPro: Bool) -> SunriseCurve {
        let resolvedStyle = (style.isPro && !isPro) ? .dawn : style
        let resolvedShape = (curveShape.isPro && !isPro) ? .gentle : curveShape
        return SunriseCurve(style: resolvedStyle, shape: resolvedShape, hdrBoost: hdrBoost)
    }

    func effectiveSound(isPro: Bool) -> NatureSound {
        (natureSound.isPro && !isPro) ? .birds : natureSound
    }

    /// Fetches the single settings row, creating it on first launch.
    @MainActor
    static func current(in context: ModelContext) -> AlarmSettings {
        var descriptor = FetchDescriptor<AlarmSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AlarmSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}

/// Wake-up sounds that fade in before the alarm.
nonisolated enum NatureSound: String, CaseIterable, Identifiable, Sendable {
    case birds
    case rain
    case chimes
    case none

    var id: String { rawValue }

    var name: String {
        switch self {
        case .birds: "Birdsong"
        case .rain: "Soft rain"
        case .chimes: "Wind chimes"
        case .none: "Light only"
        }
    }

    var symbol: String {
        switch self {
        case .birds: "bird"
        case .rain: "cloud.drizzle"
        case .chimes: "wind"
        case .none: "sun.horizon"
        }
    }

    var fileName: String? {
        self == .none ? nil : rawValue
    }

    var isPro: Bool {
        self == .rain || self == .chimes
    }
}
