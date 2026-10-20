import AlarmKit
import SwiftUI
import WidgetKit

/// How the backup alarm looks on the Lock Screen and in the Dynamic Island, including the snooze
/// countdown. AlarmKit only offers snooze on an alarm when the app ships this widget.
struct BackupAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<BackupAlarmMetadata>.self) { context in
            LockScreenAlarmView(state: context.state)
                .padding(16)
                .activityBackgroundTint(WidgetPalette.night)
                .activitySystemActionForegroundColor(WidgetPalette.amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sun.horizon.fill")
                        .foregroundStyle(WidgetPalette.amber)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmTimeText(state: context.state)
                        .font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(AlarmTimeText.title(for: context.state))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(WidgetPalette.amber)
            } compactTrailing: {
                AlarmTimeText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(WidgetPalette.amber)
            }
        }
    }
}

private struct LockScreenAlarmView: View {
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.title)
                .foregroundStyle(WidgetPalette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(AlarmTimeText.title(for: state))
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)
                Text("Firstlight backup alarm")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.ink.opacity(0.6))
            }
            Spacer()
            AlarmTimeText(state: state)
                .font(.system(size: 32, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(WidgetPalette.ink)
        }
    }
}

/// The time on the alarm, or a live countdown while snoozed.
private struct AlarmTimeText: View {
    let state: AlarmPresentationState

    static func title(for state: AlarmPresentationState) -> String {
        switch state.mode {
        case .alert: "Wake up"
        case .countdown: "Snoozing"
        case .paused: "Paused"
        @unknown default: "Firstlight"
        }
    }

    var body: some View {
        switch state.mode {
        case .alert(let alert):
            Text(Self.clock(alert.time))
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
        case .paused(let paused):
            let remaining = paused.totalCountdownDuration - paused.previouslyElapsedDuration
            Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
        @unknown default:
            Text("")
        }
    }

    private static func clock(_ time: Alarm.Schedule.Relative.Time) -> String {
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
