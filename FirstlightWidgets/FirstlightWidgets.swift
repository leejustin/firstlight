import SwiftUI
import WidgetKit

@main
struct FirstlightWidgets: WidgetBundle {
    var body: some Widget {
        NextSunriseWidget()
        BackupAlarmLiveActivity()
    }
}

enum WidgetPalette {
    static let night = Color(red: 0.031, green: 0.027, blue: 0.051)
    static let ink = Color(red: 0.965, green: 0.933, blue: 0.902)
    static let amber = Color(red: 1.0, green: 0.698, blue: 0.361)
    static let ember = Color(red: 0.93, green: 0.29, blue: 0.07)
    static let crimson = Color(red: 0.43, green: 0.04, blue: 0.02)
}
