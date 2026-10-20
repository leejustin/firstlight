import Foundation

/// What the widgets show, written by the app to the shared app group whenever the alarm changes.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    var isArmed: Bool
    var nextWake: Date?
    var sunriseMinutes: Int

    static let appGroup = "group.app.dawnfold"
    private static let key = "widgetSnapshot"

    var sunriseStart: Date? {
        nextWake?.addingTimeInterval(-TimeInterval(sunriseMinutes * 60))
    }

    static func load() -> WidgetSnapshot? {
        guard
            let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
