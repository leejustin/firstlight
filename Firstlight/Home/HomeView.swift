import SwiftUI

struct HomeView: View {
    @Bindable var settings: AlarmSettings
    var onBeginNight: () -> Void
    var onTest: () -> Void

    @Environment(AppModel.self) private var model
    @State private var sheet: HomeSheet?
    @Environment(\.dynamicTypeSize) private var typeSize

    enum HomeSheet: String, Identifiable {
        case time, light, sound, windDown, settings, pro
        var id: String { rawValue }
    }

    private var curve: SunriseCurve { settings.curve(isPro: model.isPro) }

    var body: some View {
        ZStack {
            SkyBackground(style: curve.style, dawn: settings.isArmed ? 0.45 : 0.2)
                .animation(.easeInOut(duration: 1.2), value: settings.isArmed)

            ScrollView {
                VStack(spacing: 30) {
                    header
                    wakeBlock
                    sunriseBlock
                    tiles
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
        }
        #if DEBUG
        .task {
            if let debugSheet = DebugLaunch.homeSheet { sheet = debugSheet }
        }
        #endif
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Wordmark(style: curve.style)
            Spacer()
            Button {
                sheet = .settings
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .scaledFont(16, weight: .medium, design: .default)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var wakeBlock: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let wake = settings.schedule.nextWake(after: now) ?? now
            let lightStarts = wake.addingTimeInterval(-settings.sunriseDuration)
            VStack(spacing: 14) {
                Eyebrow(wakeEyebrow(for: wake, now: now))

                Button {
                    sheet = .time
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(TimeText.clock(wake))
                            .font(.clock(104, weight: .ultraLight))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        if let period = TimeText.period(wake) {
                            Text(period)
                                .scaledFont(20, weight: .light, design: .rounded)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .shadow(color: curve.style.color(at: 0.6).color.opacity(settings.isArmed ? 0.35 : 0), radius: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wake time \(TimeText.short(wake)). Double-tap to change.")

                Text(settings.isArmed
                    ? "Light starts at \(TimeText.short(lightStarts)), in \(TimeText.until(lightStarts, from: now))"
                    : "Light starts at \(TimeText.short(lightStarts))")
                    .scaledFont(15, weight: .regular, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
                    .contentTransition(.numericText())

                ArmToggle(isOn: $settings.isArmed)
                    .padding(.top, 4)
            }
            .animation(.snappy, value: settings.wakeHour * 60 + settings.wakeMinute)
        }
        .padding(.top, 12)
    }

    private var sunriseBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Sunrise")
                Spacer()
                Text(curve.style.tagline)
                    .scaledFont(13, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
            }
            SunriseLengthSlider(minutes: $settings.sunriseLength, curve: curve)
        }
    }

    private var tiles: some View {
        let sound = settings.effectiveSound(isPro: model.isPro)
        // Three across stops fitting at the largest text sizes, so they stack instead.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            OptionTile(symbol: "sun.horizon", title: "Light", value: "\(curve.style.name), \(curve.shape.name.lowercased())") {
                sheet = .light
            }
            OptionTile(
                symbol: sound.symbol,
                title: "Sound",
                value: sound == .none ? sound.name : "\(sound.name), \(settings.soundFadeMinutes) min",
                accent: Palette.blush
            ) {
                sheet = .sound
            }
            OptionTile(
                symbol: "moon.haze",
                title: "Wind-down",
                value: settings.windDownEnabled && model.isPro ? "\(settings.windDownMinutes) min" : "Off",
                accent: Color(red: 0.75, green: 0.6, blue: 1),
                showsPro: !model.isPro
            ) {
                sheet = model.isPro ? .windDown : .pro
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            Button(action: onBeginNight) {
                Label("Begin night", systemImage: "moon.stars.fill")
            }
            .buttonStyle(.glow)

            Button(action: onTest) {
                Label("Try a 60-second sunrise", systemImage: "play.circle")
                    .scaledFont(15, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func wakeEyebrow(for wake: Date, now: Date) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(wake) {
            day = "Today"
        } else if calendar.isDateInTomorrow(wake) {
            day = "Tomorrow"
        } else {
            day = wake.formatted(.dateTime.weekday(.wide))
        }
        guard settings.schedule.repeats else { return day }
        let summary = settings.schedule.repeatSummary()
        // "Weekdays" reads as a phrase and goes lowercase; a day list like "Mon, Wed" keeps its capitals.
        let phrase = ["Weekdays", "Weekends", "Every day"].contains(summary) ? summary.lowercased() : summary
        return "\(day), \(phrase)"
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .time:
            WakeTimeSheet(settings: settings)
        case .light:
            LightSheet(settings: settings, showPro: { self.sheet = .pro })
        case .sound:
            SoundSheet(settings: settings, showPro: { self.sheet = .pro })
        case .windDown:
            WindDownSheet(settings: settings)
        case .settings:
            SettingsView(settings: settings, showPro: { self.sheet = .pro })
        case .pro:
            ProView()
        }
    }
}
