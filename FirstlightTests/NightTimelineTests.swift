import Foundation
import Testing
@testable import Firstlight

struct NightTimelineTests {
    let wake = Date(timeIntervalSince1970: 1_800_000_000)

    func timeline(windDown: Bool = false) -> NightTimeline {
        NightTimeline(
            sunrise: SunriseWindow(wake: wake, duration: 1800),
            windDownEnd: windDown ? wake.addingTimeInterval(-8 * 3600) : nil,
            windDownLength: 600,
            soundFade: 300
        )
    }

    @Test func walksThroughTheNight() {
        let t = timeline(windDown: true)
        #expect(t.basePhase(at: wake.addingTimeInterval(-8 * 3600 - 300)) == .windDown(0.5))
        #expect(t.basePhase(at: wake.addingTimeInterval(-3 * 3600)) == .night)
        #expect(t.basePhase(at: wake.addingTimeInterval(-900)) == .sunrise(0.5))
        #expect(t.basePhase(at: wake) == .ringing)
    }

    @Test func natureSoundFadesInOverTheLastMinutes() {
        let t = timeline()
        #expect(t.natureLevel(at: wake.addingTimeInterval(-301)) == 0)
        #expect(t.natureLevel(at: wake.addingTimeInterval(-150)) == 0.25)
        #expect(t.natureLevel(at: wake) == 1)
    }

    @Test func flashlightFadesUpOverTheLastMinutes() {
        var t = timeline()
        t.torchLead = 300
        t.torchStrength = 0.8
        #expect(t.torchLevel(at: wake.addingTimeInterval(-301)) == 0)
        #expect(abs(t.torchLevel(at: wake.addingTimeInterval(-150)) - 0.4) < 1e-9)
        #expect(t.torchLevel(at: wake) == 0.8)
    }

    @Test func flashlightOffByDefault() {
        #expect(timeline().torchLevel(at: wake) == 0)
    }

    @Test func noFadeMeansSilence() {
        var t = timeline()
        t.soundFade = 0
        #expect(t.natureLevel(at: wake) == 0)
    }
}

@MainActor
struct NightSessionTests {
    let wake = Date(timeIntervalSince1970: 1_800_000_000)

    func session() -> NightSession {
        NightSession(
            kind: .night,
            timeline: NightTimeline(sunrise: SunriseWindow(wake: wake, duration: 1800), windDownEnd: nil, soundFade: 0),
            curve: SunriseCurve(style: .dawn),
            natureSound: .none,
            alarmVolume: 0.8,
            snoozeLength: 540,
            backup: nil,
            now: wake.addingTimeInterval(-3600)
        )
    }

    @Test func snoozeThenRingAgainThenDismiss() {
        let night = session()
        night.tick(at: wake.addingTimeInterval(5))
        #expect(night.phase == .ringing)

        night.snooze()
        #expect(night.phase == .snoozed(until: wake.addingTimeInterval(545)))
        #expect(night.frame.screenBrightness == 1)

        night.tick(at: wake.addingTimeInterval(546))
        #expect(night.phase == .ringing)

        night.dismiss()
        #expect(night.phase == .morning)
        #expect(night.snoozeCount == 1)
        night.end()
    }

    @Test func cannotSnoozeBeforeRinging() {
        let night = session()
        night.tick(at: wake.addingTimeInterval(-60))
        night.snooze()
        #expect(night.snoozeCount == 0)
        night.end()
    }
}

struct ActiveNightTests {
    @Test func staleNightsAreDropped() {
        let wake = Date(timeIntervalSince1970: 1_800_000_000)
        ActiveNight(wake: wake).save()
        #expect(ActiveNight.load(now: wake.addingTimeInterval(-3600)) == ActiveNight(wake: wake))
        #expect(ActiveNight.load(now: wake.addingTimeInterval(ActiveNight.staleAfter + 1)) == nil)
        #expect(ActiveNight.load(now: wake.addingTimeInterval(-3600)) == nil)
    }
}
