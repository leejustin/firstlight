import Foundation

/// A wake time and the weekdays it repeats on.
nonisolated struct WakeSchedule: Equatable, Hashable, Sendable {
    var hour: Int
    var minute: Int
    /// Bit 0 is Sunday … bit 6 is Saturday, matching `Calendar` weekday numbers minus one.
    var repeatMask: Int

    var repeats: Bool { repeatMask & 0x7F != 0 }

    func includes(weekday: Int) -> Bool {
        repeatMask & (1 << (weekday - 1)) != 0
    }

    func toggling(weekday: Int) -> WakeSchedule {
        var copy = self
        copy.repeatMask ^= 1 << (weekday - 1)
        return copy
    }

    /// The next wake strictly after `date`.
    func nextWake(after date: Date, calendar: Calendar = .current) -> Date? {
        upcomingWakes(after: date, limit: 1, calendar: calendar).first
    }

    /// Wake times in order, up to `limit`, looking at most two weeks ahead.
    func upcomingWakes(after date: Date, limit: Int, calendar: Calendar = .current) -> [Date] {
        var results: [Date] = []
        let startOfDay = calendar.startOfDay(for: date)
        for dayOffset in 0..<15 where results.count < limit {
            guard
                let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                let wake = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                wake > date
            else { continue }
            if !repeats || includes(weekday: calendar.component(.weekday, from: wake)) {
                results.append(wake)
            }
            if !repeats && !results.isEmpty { break }
        }
        return results
    }

    /// "Weekdays", "Every day", "Mon, Wed, Fri" or "Once".
    func repeatSummary(calendar: Calendar = .current) -> String {
        switch repeatMask & 0x7F {
        case 0: return "Once"
        case 0x7F: return "Every day"
        case 0b0111110: return "Weekdays"
        case 0b1000001: return "Weekends"
        default:
            let symbols = calendar.shortWeekdaySymbols
            let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
            return ordered.filter { repeatMask & (1 << $0) != 0 }.map { symbols[$0] }.joined(separator: ", ")
        }
    }
}
