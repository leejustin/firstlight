#if DEBUG
import Foundation

/// Debug builds can open straight to any screen, for screenshots and design review:
///
///   xcrun simctl launch <device> app.firstlight -screen sunrise:0.4 -simulateFold YES
///
/// Screens: onboarding, home, time, light, sound, windDown, settings, pro, bedtime, windDownNight,
/// night, sunrise:<0…1>, ringing, snoozed, morning, test.
enum DebugLaunch {
    static var screen: String? {
        UserDefaults.standard.string(forKey: "screen")
    }

    /// Screenshot mode: shows the alarm as on but never touches AlarmKit, so no permission prompt
    /// appears in the shot.
    static var isTakingScreenshots: Bool {
        UserDefaults.standard.bool(forKey: "screenshots")
    }

    static var simulatesFold: Bool {
        UserDefaults.standard.bool(forKey: "simulateFold")
    }

    static var homeSheet: HomeView.HomeSheet? {
        screen.flatMap(HomeView.HomeSheet.init(rawValue:))
    }

    /// In screenshot runs, sets the app clock to a moment that suits the screen: 9:41 PM at home
    /// (matching the status bar), the small hours at night, and just before 7:00 for the sunrise.
    static func setScreenshotClock(sunriseDuration: TimeInterval) {
        guard isTakingScreenshots, let screen else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func at(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: second, of: today) ?? .now
        }
        let parts = screen.split(separator: ":")
        let target: Date
        switch parts.first {
        case "night", "windDownNight": target = at(2, 14)
        case "sunrise":
            let progress = parts.count > 1 ? Double(parts[1]) ?? 0.5 : 0.5
            target = at(7, 0).addingTimeInterval(-(1 - progress) * sunriseDuration)
        case "ringing", "snoozed", "morning": target = at(7, 0, 20)
        default: target = at(21, 41)
        }
        AppClock.offset = target.timeIntervalSince(.now)
    }

    /// A session already partway through the night, for the night screens.
    @MainActor
    static func session(settings: AlarmSettings, isPro: Bool) -> NightSession? {
        guard let screen else { return nil }
        let parts = screen.split(separator: ":")
        let name = parts.first.map(String.init) ?? ""
        let now = AppClock.now
        let duration = settings.sunriseDuration
        // Screenshot runs wake at 7:00; otherwise a few hours from now.
        let nightWake = isTakingScreenshots
            ? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
            : now.addingTimeInterval(5 * 3600)

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
            return make(wake: nightWake)
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
