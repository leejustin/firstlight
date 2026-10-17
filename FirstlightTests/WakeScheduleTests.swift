import Foundation
import Testing
@testable import Firstlight

struct WakeScheduleTests {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    /// Friday 16 October 2026, 22:30 in Los Angeles.
    var fridayNight: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 22, minute: 30))!
    }

    func components(_ date: Date) -> DateComponents {
        calendar.dateComponents([.weekday, .day, .hour, .minute], from: date)
    }

    @Test func onceMeansTomorrowMorning() throws {
        let schedule = WakeSchedule(hour: 7, minute: 0, repeatMask: 0)
        let wake = try #require(schedule.nextWake(after: fridayNight, calendar: calendar))
        #expect(components(wake).day == 17)
        #expect(components(wake).hour == 7)
        #expect(schedule.upcomingWakes(after: fridayNight, limit: 7, calendar: calendar).count == 1)
    }

    @Test func weekdaysSkipTheWeekend() throws {
        let schedule = WakeSchedule(hour: 6, minute: 45, repeatMask: 0b0111110)
        let wake = try #require(schedule.nextWake(after: fridayNight, calendar: calendar))
        #expect(components(wake).weekday == 2) // Monday
        #expect(components(wake).day == 19)
    }

    @Test func laterTodayStillCounts() throws {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 5, minute: 0))!
        let schedule = WakeSchedule(hour: 7, minute: 0, repeatMask: 0x7F)
        let wake = try #require(schedule.nextWake(after: morning, calendar: calendar))
        #expect(components(wake).day == 16)
    }

    @Test func upcomingCoversAWeek() {
        let schedule = WakeSchedule(hour: 7, minute: 0, repeatMask: 0x7F)
        let wakes = schedule.upcomingWakes(after: fridayNight, limit: 7, calendar: calendar)
        #expect(wakes.count == 7)
        #expect(wakes == wakes.sorted())
    }

    @Test func togglingFlipsOneDay() {
        let schedule = WakeSchedule(hour: 7, minute: 0, repeatMask: 0)
        let monday = schedule.toggling(weekday: 2)
        #expect(monday.includes(weekday: 2))
        #expect(!monday.includes(weekday: 3))
        #expect(monday.toggling(weekday: 2).repeatMask == 0)
    }

    @Test func summaries() {
        #expect(WakeSchedule(hour: 7, minute: 0, repeatMask: 0).repeatSummary(calendar: calendar) == "Once")
        #expect(WakeSchedule(hour: 7, minute: 0, repeatMask: 0x7F).repeatSummary(calendar: calendar) == "Every day")
        #expect(WakeSchedule(hour: 7, minute: 0, repeatMask: 0b0111110).repeatSummary(calendar: calendar) == "Weekdays")
    }
}

struct AlarmSettingsTests {
    @Test func sunriseLengthStaysInRange() {
        let settings = AlarmSettings()
        settings.sunriseMinutes = 60
        #expect(settings.sunriseLength == 30)
        #expect(settings.sunriseDuration == 30 * 60)
        settings.sunriseMinutes = 0
        #expect(settings.sunriseLength == 1)
        settings.sunriseLength = 99
        #expect(settings.sunriseMinutes == 30)
    }
}
