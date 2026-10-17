import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

nonisolated struct BackupAlarmMetadata: AlarmMetadata {}

/// The safety net: a system alarm two minutes after each wake time, so the phone still rings if
/// Firstlight was closed overnight. When the in-app alarm is dismissed, that morning's backup is
/// cancelled.
@MainActor
@Observable
final class BackupAlarmService {
    static let delay: TimeInterval = 120
    /// How many upcoming mornings to cover, so a repeating alarm survives a few nights without the
    /// app being opened.
    static let horizon = 7

    private(set) var authorization: AlarmManager.AuthorizationState = .notDetermined
    private(set) var lastError: String?

    private var manager: AlarmManager { AlarmManager.shared }
    private let storeKey = "backupAlarms"

    init() {
        authorization = manager.authorizationState
    }

    var isAuthorized: Bool { authorization == .authorized }

    /// True until the user has answered the permission prompt once.
    var canAskForAuthorization: Bool { authorization == .notDetermined }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            authorization = try await AlarmManager.shared.requestAuthorization()
        } catch {
            authorization = manager.authorizationState
            lastError = error.localizedDescription
        }
        return isAuthorized
    }

    func refreshAuthorization() {
        authorization = manager.authorizationState
    }

    /// Wake time → backup alarm ID, persisted on this device only (alarms don't sync).
    private var scheduled: [TimeInterval: UUID] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: storeKey) as? [String: String] ?? [:]
            return raw.reduce(into: [:]) { result, pair in
                if let time = TimeInterval(pair.key), let id = UUID(uuidString: pair.value) {
                    result[time] = id
                }
            }
        }
        set {
            let raw = newValue.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value.uuidString }
            UserDefaults.standard.set(raw, forKey: storeKey)
        }
    }

    // Every change to the system alarms runs through one serial queue. Without it, two syncs that
    // overlap at an `await` each schedule a full set and one set is never tracked, so it rings later
    // at a stale time or after the alarm was turned off.
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored private var syncGeneration = 0

    @discardableResult
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        tail = task
        return task
    }

    /// Replaces all backups with one per wake time. Overlapping calls collapse into the latest.
    func sync(wakes: [Date]) async {
        syncGeneration += 1
        let generation = syncGeneration
        await enqueue { [weak self] in
            guard let self, generation == self.syncGeneration else { return }
            await self.performSync(wakes: wakes)
        }.value
    }

    private func performSync(wakes: [Date]) async {
        cancelAllScheduled()
        guard !wakes.isEmpty else { return }
        if authorization == .notDetermined {
            await requestAuthorization()
        }
        guard isAuthorized else { return }

        var next: [TimeInterval: UUID] = [:]
        for wake in wakes.prefix(Self.horizon) {
            let id = UUID()
            if await schedule(id: id, at: wake.addingTimeInterval(Self.delay)) {
                next[wake.timeIntervalSince1970] = id
            }
        }
        scheduled = next
    }

    /// Moves a morning's backup to two minutes after a new ring time (after a snooze).
    func reschedule(wake: Date, ringingAgainAt ringTime: Date) {
        enqueue { [weak self] in
            guard let self else { return }
            self.silence(wake: wake)
            guard self.isAuthorized else { return }
            let id = UUID()
            if await self.schedule(id: id, at: ringTime.addingTimeInterval(Self.delay)) {
                var current = self.scheduled
                current[wake.timeIntervalSince1970] = id
                self.scheduled = current
            }
        }
    }

    /// The user is up: cancel this morning's backup, and stop it if it's already ringing.
    /// Queued behind any snooze reschedule still in flight, so that one is cancelled too.
    func cancel(wake: Date) {
        enqueue { [weak self] in self?.silence(wake: wake) }
    }

    private func silence(wake: Date) {
        var current = scheduled
        if let id = current.removeValue(forKey: wake.timeIntervalSince1970) {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
        scheduled = current
    }

    /// Cancels every upcoming alarm this app owns, tracked or not, so nothing stale survives. An
    /// alarm that's ringing right now is left alone; opening the app mustn't silence it.
    private func cancelAllScheduled() {
        let live = (try? manager.alarms) ?? []
        for alarm in live where alarm.state != .alerting {
            try? manager.cancel(id: alarm.id)
        }
        let alerting = Set(live.filter { $0.state == .alerting }.map(\.id))
        scheduled = scheduled.filter { alerting.contains($0.value) }
    }

    private func schedule(id: UUID, at date: Date) async -> Bool {
        guard date > .now else { return false }
        let alert = AlarmPresentation.Alert(title: "Wake up")
        let attributes = AlarmAttributes<BackupAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Palette.ember
        )
        let configuration = AlarmManager.AlarmConfiguration<BackupAlarmMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            sound: .named("\(SoundEngine.alarmFileName).caf")
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
