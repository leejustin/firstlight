import SwiftUI

struct WakeTimeSheet: View {
    @Bindable var settings: AlarmSettings
    @Environment(\.dismiss) private var dismiss

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: settings.wakeHour, minute: settings.wakeMinute, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            settings.wakeHour = parts.hour ?? 7
            settings.wakeMinute = parts.minute ?? 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SheetHeader(title: "Wake time")

            DatePicker("Wake time", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("Repeat")
                    Spacer()
                    Text(settings.schedule.repeatSummary())
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                }
                WeekdayPicker(schedule: $settings.schedule)
            }

            Text("The light starts \(settings.sunriseLength) minutes earlier, at \(TimeText.short(time.wrappedValue.addingTimeInterval(-settings.sunriseDuration))).")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Palette.inkSecondary)

            Button("Done") { dismiss() }
                .buttonStyle(.glow)
        }
        .padding(24)
        .presentationDetents([.large])
        .nightSheetStyle()
    }
}
