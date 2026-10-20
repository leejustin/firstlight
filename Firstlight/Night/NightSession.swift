import Foundation
import Observation

/// The night in progress, saved so a relaunch at 3 a.m. picks it back up.
nonisolated struct ActiveNight: Codable, Equatable, Sendable {
    var wake: Date
    var snoozeUntil: Date?

    private static let key = "activeNight"
    /// After this long past wake time, a saved night is stale.
    static let staleAfter: TimeInterval = 30 * 60

    static func load(now: Date = .now) -> ActiveNight? {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let night = try? JSONDecoder().decode(ActiveNight.self, from: data)
        else { return nil }
        guard now < night.wake.addingTimeInterval(staleAfter) else {
            clear()
            return nil
        }
        return night
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// One night (or a 60-second test) from bedtime to "good morning". Owns the screen and sound for
/// its lifetime; the views only read state and forward taps.
@MainActor
@Observable
final class NightSession: Identifiable {
    enum Kind: Equatable {
        case night
        case test
    }

    typealias Phase = NightTimeline.Phase

    let id = UUID()
    let kind: Kind
    let curve: SunriseCurve
    let natureSound: NatureSound
    let alarmVolume: Double
    let snoozeLength: TimeInterval
    let startedAt: Date

    private(set) var timeline: NightTimeline
    private(set) var now: Date
    private(set) var phase: Phase = .night
    private(set) var snoozeUntil: Date?
    private(set) var snoozeCount = 0
    private(set) var ringStartedAt: Date?
    private(set) var dismissedAt: Date?
    /// iOS reported noticeably less brightness than requested (heat or power throttling).
    private(set) var isThrottled = false

    @ObservationIgnored private let screen = ScreenController()
    @ObservationIgnored private let sound = SoundEngine()
    @ObservationIgnored private let torch = TorchController()
    @ObservationIgnored private weak var backup: BackupAlarmService?
    @ObservationIgnored private weak var lamps: HomeLights?
    @ObservationIgnored private var lampIDs: Set<String> = []
    @ObservationIgnored private var loop: Task<Void, Never>?

    /// Nature sound sits under the alarm; this is its ceiling.
    static let natureCeiling = 0.7

    init(
        kind: Kind,
        timeline: NightTimeline,
        curve: SunriseCurve,
        natureSound: NatureSound,
        alarmVolume: Double,
        snoozeLength: TimeInterval,
        backup: BackupAlarmService?,
        now: Date = .now
    ) {
        self.kind = kind
        self.timeline = timeline
        self.curve = curve
        self.natureSound = natureSound
        self.alarmVolume = alarmVolume
        self.snoozeLength = snoozeLength
        self.backup = backup
        self.startedAt = now
        self.now = now
        self.phase = timeline.basePhase(at: now)
    }

    /// A real night ending at the next wake time.
    /// `resumingWake` picks a night back up after the app was closed or relaunched mid-night.
    static func night(
        settings: AlarmSettings,
        isPro: Bool,
        backup: BackupAlarmService,
        resumingWake: Date? = nil,
        now: Date = .now
    ) -> NightSession? {
        guard let wake = resumingWake ?? settings.schedule.nextWake(after: now) else { return nil }
        let isResuming = resumingWake != nil
        let sound = settings.effectiveSound(isPro: isPro)
        let windDown = settings.windDownEnabled && isPro && !isResuming
        let windDownLength = TimeInterval(settings.windDownMinutes * 60)
        let sunrise = SunriseWindow(wake: wake, duration: settings.sunriseDuration)
        let timeline = NightTimeline(
            sunrise: sunrise,
            windDownEnd: windDown ? min(now.addingTimeInterval(windDownLength), sunrise.start) : nil,
            windDownLength: windDownLength,
            // Neither sound nor flashlight starts before the light does.
            soundFade: sound == .none ? 0 : min(TimeInterval(settings.soundFadeMinutes * 60), sunrise.duration),
            torchLead: settings.torchEnabled ? min(TimeInterval(settings.torchMinutes * 60), sunrise.duration) : 0,
            torchStrength: settings.torchEnabled ? settings.torchStrength : 0
        )
        return NightSession(
            kind: .night,
            timeline: timeline,
            curve: settings.curve(isPro: isPro),
            natureSound: sound,
            alarmVolume: settings.alarmVolume,
            snoozeLength: TimeInterval(settings.snoozeMinutes * 60),
            backup: backup,
            now: now
        )
    }

    /// The whole sunrise in a minute, to check placement. No backup alarm, no wind-down.
    static func test(settings: AlarmSettings, isPro: Bool, now: Date = .now) -> NightSession {
        let duration: TimeInterval = 60
        let sound = settings.effectiveSound(isPro: isPro)
        // Keep the real ratio of sound fade to sunrise length.
        let fadeShare = Double(settings.soundFadeMinutes) / Double(settings.sunriseLength)
        let torchShare = Double(settings.torchMinutes) / Double(settings.sunriseLength)
        let timeline = NightTimeline(
            sunrise: SunriseWindow(wake: now.addingTimeInterval(duration), duration: duration),
            windDownEnd: nil,
            soundFade: sound == .none ? 0 : duration * min(fadeShare, 1),
            torchLead: settings.torchEnabled ? duration * min(torchShare, 1) : 0,
            torchStrength: settings.torchEnabled ? settings.torchStrength : 0
        )
        return NightSession(
            kind: .test,
            timeline: timeline,
            curve: settings.curve(isPro: isPro),
            natureSound: sound,
            alarmVolume: settings.alarmVolume,
            snoozeLength: 0,
            backup: nil,
            now: now
        )
    }

    var wake: Date { timeline.wake }
    var sunriseStart: Date { timeline.sunrise.start }

    /// Current sunrise frame; full daylight once ringing.
    var frame: SunriseFrame {
        switch phase {
        case .sunrise(let progress): curve.frame(at: progress)
        case .ringing, .snoozed, .morning: curve.frame(at: 1)
        case .windDown, .night: curve.frame(at: 0)
        }
    }

    // MARK: Lifecycle

    func start() {
        guard loop == nil else { return }
        screen.begin()
        tick()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.tickInterval ?? .seconds(1)
                try? await Task.sleep(for: interval)
                self?.tick()
            }
        }
    }

    /// HomeKit lamps to brighten along with the screen.
    func attach(lamps: HomeLights, ids: Set<String>) {
        guard !ids.isEmpty else { return }
        self.lamps = lamps
        lampIDs = ids
        lamps.connect()
    }

    func end() {
        // A test shouldn't leave the bedroom lights on; a real morning should.
        if kind == .test { lamps?.turnOff(lampIDs) }
        loop?.cancel()
        loop = nil
        sound.stopAll(fade: 0.8)
        torch.off()
        screen.end()
    }

    /// The app left the screen (locked, switched away). Hand brightness back to the system so the
    /// phone isn't stuck at night brightness; the sunrise resumes from the clock when we return.
    func didEnterBackground() {
        torch.off()
        screen.end()
    }

    func willEnterForeground() {
        screen.begin()
        tick()
    }

    private var tickInterval: Duration {
        switch phase {
        case .sunrise, .windDown: kind == .test ? .milliseconds(100) : .milliseconds(250)
        case .ringing: .milliseconds(250)
        case .night, .snoozed, .morning: .seconds(1)
        }
    }

    func tick(at date: Date = .now) {
        now = date
        if let snoozeUntil, date >= snoozeUntil {
            self.snoozeUntil = nil
            ringStartedAt = date
        }
        let next = resolvedPhase(at: date)
        if next == .ringing, ringStartedAt == nil {
            ringStartedAt = date
        }
        if next != phase { phase = next }
        apply()
    }

    private func resolvedPhase(at date: Date) -> Phase {
        if dismissedAt != nil { return .morning }
        if let snoozeUntil { return .snoozed(until: snoozeUntil) }
        return timeline.basePhase(at: date)
    }

    private func apply() {
        switch phase {
        case .windDown(let progress):
            screen.setBrightness(0.22 * (1 - progress))
            torch.off()
        case .night:
            screen.setBrightness(0)
            torch.off()
        case .sunrise(let progress):
            let target = curve.frame(at: progress).screenBrightness
            screen.setBrightness(target)
            checkThrottle(requested: target)
            sound.setNature(natureSound, volume: timeline.natureLevel(at: now) * Self.natureCeiling)
            torch.set(level: timeline.torchLevel(at: now))
            lamps?.apply(curve.lampState(at: progress), to: lampIDs)
        case .ringing:
            screen.setBrightness(1)
            torch.set(level: timeline.torchStrength)
            lamps?.apply(curve.lampState(at: 1), to: lampIDs)
            checkThrottle(requested: 1)
            sound.setNature(natureSound, volume: Self.natureCeiling)
            let ringing = now.timeIntervalSince(ringStartedAt ?? now)
            // Start quiet and build over 40 seconds.
            sound.setAlarm(volume: alarmVolume * min(1, 0.2 + ringing / 40))
        case .snoozed:
            screen.setBrightness(1)
            torch.set(level: timeline.torchStrength)
            sound.setNature(natureSound, volume: Self.natureCeiling * 0.5)
        case .morning:
            screen.setBrightness(1)
            // You're up; the screen is plenty, and the flashlight runs warm.
            torch.off()
        }
    }

    private func checkThrottle(requested: Double) {
        #if !targetEnvironment(simulator)
        if requested > 0.5 && screen.reportedBrightness < requested - 0.15 {
            isThrottled = true
        }
        #endif
    }

    // MARK: Actions

    func snooze() {
        guard phase == .ringing, kind == .night else { return }
        let until = now.addingTimeInterval(snoozeLength)
        snoozeUntil = until
        snoozeCount += 1
        ringStartedAt = nil
        sound.stopAlarm()
        backup?.reschedule(wake: timeline.wake, ringingAgainAt: until)
        ActiveNight(wake: timeline.wake, snoozeUntil: until).save()
        tick(at: now)
    }

    func dismiss() {
        guard dismissedAt == nil else { return }
        dismissedAt = now
        snoozeUntil = nil
        sound.stopAll(fade: 3)
        backup?.cancel(wake: timeline.wake)
        // A relaunch after this point must not bring the alarm back.
        if kind == .night { ActiveNight.clear() }
        tick(at: now)
    }

    /// Puts back a snooze that was running when the app was closed.
    func restoreSnooze(until: Date) {
        guard until > now, dismissedAt == nil else { return }
        snoozeUntil = until
        snoozeCount = max(snoozeCount, 1)
        ringStartedAt = nil
        tick(at: now)
    }

    func skipWindDown() {
        guard case .windDown = phase else { return }
        timeline.windDownEnd = now
        tick(at: now)
    }
}
