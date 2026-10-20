import Foundation

/// The app's "now". Always the real time, except in debug screenshot runs, which shift it so the
/// clocks in a screenshot read like a real night.
enum AppClock {
    static var offset: TimeInterval = 0

    static var now: Date {
        Date.now.addingTimeInterval(offset)
    }
}
