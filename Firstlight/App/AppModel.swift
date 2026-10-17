import FoldPosture
import Observation
import SwiftUI

/// App-wide services and the one night that may be running.
@MainActor
@Observable
final class AppModel {
    let store = ProStore()
    let backup = BackupAlarmService()
    let power = PowerMonitor()
    let posture = PostureMonitor()

    var session: NightSession?

    var isPro: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "pro") { return true }
        #endif
        return store.isPro
    }

    func start() async {
        power.start()
        backup.refreshAuthorization()
        await store.start()
    }

    /// Makes the system backup alarms match the settings. Skipped mid-night so a snooze's moved
    /// backup isn't overwritten.
    func syncBackups(for settings: AlarmSettings) async {
        if let session, session.kind == .night { return }
        retireSpentOneOff(settings)
        let wakes = settings.isArmed
            ? settings.schedule.upcomingWakes(after: .now, limit: BackupAlarmService.horizon)
            : []
        await backup.sync(wakes: wakes)
    }

    /// A one-off alarm is spent once its morning passes, however the user woke (in the app or
    /// from the backup). Without this it would quietly re-arm for the same time tomorrow.
    private func retireSpentOneOff(_ settings: AlarmSettings, now: Date = .now) {
        guard settings.isArmed, !settings.schedule.repeats else {
            settings.oneOffWake = nil
            return
        }
        if let target = settings.oneOffWake, target <= now {
            settings.isArmed = false
            settings.oneOffWake = nil
        } else {
            settings.oneOffWake = settings.schedule.nextWake(after: now)
        }
    }

    func beginNight(with settings: AlarmSettings) async {
        if !settings.isArmed {
            settings.oneOffWake = nil
            settings.isArmed = true
        }
        await syncBackups(for: settings)
        session = NightSession.night(settings: settings, isPro: isPro, backup: backup)
        if let session { ActiveNight(wake: session.wake).save() }
    }

    /// Reopens a night that was running when the app was closed or killed.
    func resumeNightIfNeeded(with settings: AlarmSettings) {
        guard session == nil, let active = ActiveNight.load() else { return }
        session = NightSession.night(settings: settings, isPro: isPro, backup: backup, resumingWake: active.wake)
        if let snoozeUntil = active.snoozeUntil { session?.restoreSnooze(until: snoozeUntil) }
    }

    func beginTest(with settings: AlarmSettings) {
        session = NightSession.test(settings: settings, isPro: isPro)
    }

    func finishSession(settings: AlarmSettings) {
        let finished = session
        session = nil
        if finished?.kind == .night { ActiveNight.clear() }
        finished?.end()
        // A one-off alarm that rang is spent; repeating ones roll forward.
        if finished?.kind == .night, finished?.dismissedAt != nil, !settings.schedule.repeats {
            settings.isArmed = false
        }
        Task { await syncBackups(for: settings) }
    }
}
