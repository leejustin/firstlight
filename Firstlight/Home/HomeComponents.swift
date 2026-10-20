import SwiftUI

/// S M T W T F S, in the locale's week order.
struct WeekdayPicker: View {
    @Binding var schedule: WakeSchedule

    private let calendar = Calendar.current

    var body: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let names = calendar.weekdaySymbols
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { offset in
                let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
                let isOn = schedule.includes(weekday: weekday)
                Button {
                    schedule = schedule.toggling(weekday: weekday)
                } label: {
                    Text(symbols[weekday - 1])
                        .scaledFont(13, weight: isOn ? .bold : .medium, design: .rounded)
                        .foregroundStyle(isOn ? Palette.night : Palette.inkSecondary)
                        .frame(width: 36, height: 36)
                        .background {
                            if isOn {
                                Circle().fill(Palette.warmGradient)
                                    .shadow(color: Palette.ember.opacity(0.4), radius: 8)
                            } else {
                                Circle().strokeBorder(Palette.hairline, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.selection, trigger: schedule.repeatMask)
    }
}

/// A square glass tile: icon, label, value.
struct OptionTile: View {
    let symbol: String
    let title: String
    let value: String
    var accent: Color = Palette.amber
    var showsPro = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .scaledFont(18, weight: .regular, design: .default)
                        .foregroundStyle(accent)
                        .frame(height: 22)
                    Spacer(minLength: 0)
                    if showsPro { ProBadge() }
                }
                Spacer(minLength: 18)
                Text(title)
                    .scaledFont(13, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.inkTertiary)
                Text(value)
                    .scaledFont(15, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(14)
            .contentShape(.rect(cornerRadius: 24))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

/// "Alarm on" pill with a glowing indicator.
struct ArmToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOn ? Palette.amber : Palette.inkTertiary)
                    .frame(width: 8, height: 8)
                    .shadow(color: isOn ? Palette.amber : .clear, radius: 6)
                Text(isOn ? "Alarm on" : "Alarm off")
                    .scaledFont(14, weight: .semibold, design: .rounded)
                    .foregroundStyle(isOn ? Palette.ink : Palette.inkSecondary)
                    .contentTransition(.interpolate)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: isOn)
        .animation(.easeInOut(duration: 0.25), value: isOn)
        .accessibilityLabel("Alarm")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Wordmark: the horizon mark and a lowercase serif name.
struct Wordmark: View {
    var style: SunriseStyle = .dawn

    var body: some View {
        HStack(spacing: 8) {
            HorizonMark(style: style)
                .frame(width: 26, height: 26)
            Text("firstlight")
                .font(.display(22, weight: .regular))
                .italic()
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement()
        .accessibilityLabel("Firstlight")
    }
}

enum TimeText {
    static var uses12Hour: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false
    }

    /// "7:00" without the day period.
    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("a")
        return formatter
    }()

    /// "AM"/"PM", or nil in 24-hour locales.
    static func period(_ date: Date) -> String? {
        uses12Hour ? periodFormatter.string(from: date) : nil
    }

    static func short(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "7 hr 42 min"
    static func until(_ date: Date, from now: Date) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let rounded = (seconds / 60).rounded(.up) * 60
        return Duration.seconds(rounded).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
