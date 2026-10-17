import Foundation

/// The fixed shape of one night, from bedtime to wake. Pure, so the phase logic is testable.
nonisolated struct NightTimeline: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// Warm glow fading to black. Progress 0...1.
        case windDown(Double)
        /// Black screen, dim clock.
        case night
        /// Progress 0...1 toward wake time.
        case sunrise(Double)
        case ringing
        case snoozed(until: Date)
        /// Dismissed; light stays on until the user leaves.
        case morning
    }

    var sunrise: SunriseWindow
    var windDownEnd: Date?
    var windDownLength: TimeInterval = 600
    /// Nature sound starts fading in this long before wake. Zero means no nature sound.
    var soundFade: TimeInterval
    /// Flashlight boost starts this long before wake. Zero means off.
    var torchLead: TimeInterval = 0
    /// Flashlight level at wake time, 0...1.
    var torchStrength: Double = 0

    var wake: Date { sunrise.wake }

    /// Phase ignoring user actions (snooze, dismiss), which the session layers on top.
    func basePhase(at date: Date) -> Phase {
        if date >= wake { return .ringing }
        if let progress = sunrise.progress(at: date) { return .sunrise(progress) }
        if let windDownEnd, date < windDownEnd, windDownLength > 0 {
            let start = windDownEnd.addingTimeInterval(-windDownLength)
            return .windDown(min(max(date.timeIntervalSince(start) / windDownLength, 0), 1))
        }
        return .night
    }

    /// Flashlight level before wake: off until the boost starts, then easing up to full strength.
    func torchLevel(at date: Date) -> Double {
        guard torchLead > 0, torchStrength > 0 else { return 0 }
        let start = wake.addingTimeInterval(-torchLead)
        guard date > start else { return 0 }
        let t = min(date.timeIntervalSince(start) / torchLead, 1)
        return torchStrength * t * t * (3 - 2 * t)
    }

    /// Nature sound level before wake: silent until the fade starts, then easing up to full.
    func natureLevel(at date: Date) -> Double {
        guard soundFade > 0 else { return 0 }
        let start = wake.addingTimeInterval(-soundFade)
        guard date > start else { return 0 }
        let t = min(date.timeIntervalSince(start) / soundFade, 1)
        return t * t
    }
}
