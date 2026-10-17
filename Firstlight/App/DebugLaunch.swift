#if DEBUG
import Foundation

/// Debug builds can open straight to any screen, for screenshots and design review:
///
///   xcrun simctl launch <device> com.leejustin.firstlight -screen sunrise:0.4 -simulateFold YES
///
/// Screens: onboarding, home, time, light, sound, windDown, settings, pro, bedtime, windDownNight,
/// night, sunrise:<0…1>, ringing, snoozed, morning, test.
enum DebugLaunch {
    static var screen: String? {
        UserDefaults.standard.string(forKey: "screen")
    }

    static var simulatesFold: Bool {
        UserDefaults.standard.bool(forKey: "simulateFold")
    }

    static var homeSheet: HomeView.HomeSheet? {
        screen.flatMap(HomeView.HomeSheet.init(rawValue:))
    }

    /// A session already partway through the night, for the night screens.
    @MainActor
    static func session(settings: AlarmSettings, isPro: Bool) -> NightSession? {
        guard let screen else { return nil }
        let parts = screen.split(separator: ":")
        let name = parts.first.map(String.init) ?? ""
        let now = Date.now
        let duration = settings.sunriseDuration

        func make(wake: Date, windDown: Bool = false) -> NightSession {
            NightSession(
                kind: .night,
                timeline: NightTimeline(
                    sunrise: SunriseWindow(wake: wake, duration: duration),
                    windDownEnd: windDown ? now.addingTimeInterval(420) : nil,
                    windDownLength: 600,
                    soundFade: 0
                ),
                curve: settings.curve(isPro: isPro),
                natureSound: .none,
                alarmVolume: 0,
                snoozeLength: TimeInterval(settings.snoozeMinutes * 60),
                backup: nil,
                now: now
            )
        }

        switch name {
        case "windDownNight":
            return make(wake: now.addingTimeInterval(7 * 3600), windDown: true)
        case "night":
            return make(wake: now.addingTimeInterval(5 * 3600))
        case "sunrise":
            let progress = parts.count > 1 ? Double(parts[1]) ?? 0.5 : 0.5
            return make(wake: now.addingTimeInterval((1 - progress) * duration))
        case "ringing", "snoozed", "morning":
            let session = make(wake: now.addingTimeInterval(-1))
            session.tick(at: now)
            if name == "snoozed" { session.snooze() }
            if name == "morning" { session.dismiss() }
            return session
        case "test":
            return NightSession.test(settings: settings, isPro: isPro)
        default:
            return nil
        }
    }
}
#endif
