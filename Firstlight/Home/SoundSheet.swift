import SwiftUI

struct SoundSheet: View {
    @Bindable var settings: AlarmSettings
    var showPro: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var engine = SoundEngine()
    @State private var previewing: NatureSound?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SheetHeader(title: "Sound")

                VStack(spacing: 10) {
                    ForEach(NatureSound.allCases) { sound in
                        soundRow(sound)
                    }
                }

                if settings.natureSound != .none {
                    stepperRow(
                        title: "Fades in over",
                        value: "\(settings.soundFadeMinutes) min before wake",
                        binding: $settings.soundFadeMinutes,
                        range: AlarmSettings.soundFadeRange
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Alarm volume")
                    HStack(spacing: 14) {
                        Image(systemName: "speaker.fill").foregroundStyle(Palette.inkTertiary)
                        Slider(value: $settings.alarmVolume, in: 0.2...1)
                            .tint(Palette.amber)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(Palette.inkTertiary)
                    }
                    Text("A soft marimba rings at wake time and builds over 40 seconds. It plays even with the ringer off.")
                        .scaledFont(13, design: .rounded)
                        .foregroundStyle(Palette.inkSecondary)
                }

                stepperRow(
                    title: "Snooze",
                    value: "\(settings.snoozeMinutes) min. The light stays on.",
                    binding: $settings.snoozeMinutes,
                    range: AlarmSettings.snoozeRange
                )

                Button("Done") { dismiss() }
                    .buttonStyle(.glow)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .nightSheetStyle()
        .onDisappear { engine.stopPreview() }
    }

    private func soundRow(_ sound: NatureSound) -> some View {
        let locked = sound.isPro && !model.isPro
        let selected = settings.natureSound == sound
        return HStack(spacing: 14) {
            Button {
                if locked { showPro() } else { settings.natureSound = sound }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: sound.symbol)
                        .scaledFont(18, design: .default)
                        .foregroundStyle(selected ? Palette.amber : Palette.inkSecondary)
                        .frame(width: 28)
                    Text(sound.name)
                        .scaledFont(17, weight: .medium, design: .rounded)
                        .foregroundStyle(Palette.ink)
                    if locked { ProBadge() }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .scaledFont(14, weight: .bold, design: .default)
                            .foregroundStyle(Palette.amber)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if sound != .none {
                Button {
                    if previewing == sound {
                        engine.stopPreview()
                        previewing = nil
                    } else {
                        engine.playPreview(sound)
                        previewing = sound
                    }
                } label: {
                    Image(systemName: previewing == sound ? "stop.fill" : "play.fill")
                        .scaledFont(12, design: .default)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(previewing == sound ? "Stop preview" : "Preview \(sound.name)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(selected ? 0.08 : 0.03))
                .strokeBorder(selected ? Palette.amber.opacity(0.5) : Palette.hairline, lineWidth: 1)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func stepperRow(title: String, value: String, binding: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: binding, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(title)
                Text(value)
                    .scaledFont(16, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct WindDownSheet: View {
    @Bindable var settings: AlarmSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            SheetHeader(title: "Wind-down")

            WindDownLightView(progress: 0.15)
                .frame(height: 140)
                .clipShape(.rect(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.hairline))

            Text("When you start the night, the screen shows a dim orange glow that fades to black over the time you pick.")
                .scaledFont(15, design: .rounded)
                .foregroundStyle(Palette.inkSecondary)

            Toggle("Wind-down sunset", isOn: $settings.windDownEnabled)
                .scaledFont(17, weight: .medium, design: .rounded)
                .tint(Palette.ember)

            if settings.windDownEnabled {
                Picker("Length", selection: $settings.windDownMinutes) {
                    ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Spacer(minLength: 0)
            Button("Done") { dismiss() }
                .buttonStyle(.glow)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .nightSheetStyle()
        .animation(.smooth, value: settings.windDownEnabled)
    }
}
