import AlarmKit

/// The backup alarm's Live Activity type. Compiled into both the app and the widget extension,
/// which is how the system matches the alarm to the widget that draws it.
nonisolated struct BackupAlarmMetadata: AlarmMetadata {}
