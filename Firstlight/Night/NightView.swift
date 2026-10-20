import FoldPosture
import SwiftUI

/// Full-screen night: wind-down, the dark clock, the sunrise, and the wake-up. On a half-folded
/// Duo the light and clock live on the top half (aimed at the pillow) and the controls on the
/// bottom half (flat on the nightstand, easy to reach); on a regular iPhone it's one surface.
struct NightView: View {
    let session: NightSession
    var onFinish: () -> Void

    @Environment(PowerMonitor.self) private var power
    @Environment(PostureMonitor.self) private var posture: PostureMonitor?
    @Environment(\.scenePhase) private var scenePhase
    @State private var controlsVisible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        FoldReader { layout in
            ZStack(alignment: .topLeading) {
                Color.black

                light
                    .frame(width: layout.upper.width, height: layout.upper.height)
                    .offset(x: layout.upper.minX, y: layout.upper.minY)

                upperContent(split: layout.isSplit)
                    .frame(width: layout.upper.width, height: layout.upper.height)
                    .offset(x: layout.upper.minX, y: layout.upper.minY)

                if layout.isSplit {
                    lowerContent(onDarkHalf: true)
                        .padding(24)
                        .frame(width: layout.lower.width, height: layout.lower.height)
                        .offset(x: layout.lower.minX, y: layout.lower.minY)
                } else {
                    lowerContent(onDarkHalf: false)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                        .frame(width: layout.upper.width, height: layout.upper.height, alignment: .bottom)
                }
            }
        }
        .immersive()
        .contentShape(Rectangle())
        .onTapGesture(perform: revealControls)
        .onAppear {
            // On a Duo the night is always the sideways laptop pose.
            if posture?.isFoldable == true { OrientationLock.landscape() }
            session.start()
        }
        .onDisappear {
            session.end()
            OrientationLock.release()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: session.didEnterBackground()
            case .active: session.willEnterForeground()
            default: break
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.phase == .ringing)
    }

    // MARK: Light

    @ViewBuilder
    private var light: some View {
        switch session.phase {
        case .windDown(let progress):
            WindDownLightView(progress: progress)
        case .night:
            Color.black
        case .sunrise, .ringing, .snoozed, .morning:
            SunriseLightView(frame: session.frame)
        }
    }

    private var isDaylight: Bool {
        switch session.phase {
        case .ringing, .snoozed, .morning: true
        case .sunrise(let progress): progress > 0.55
        case .windDown, .night: false
        }
    }

    /// Text tint that sits quietly on whatever light is showing.
    private var ink: Color {
        switch session.phase {
        case .night: Palette.nightRed
        case .windDown: Color(red: 0.55, green: 0.22, blue: 0.08)
        case .sunrise(let progress) where progress < 0.55:
            session.frame.color.mixed(with: .black, by: 0.55).color.opacity(0.9)
        default: Palette.daylightInk
        }
    }

    // MARK: Upper half: what you see from the pillow

    @ViewBuilder
    private func upperContent(split: Bool) -> some View {
        switch session.phase {
        case .windDown, .night:
            NightClockView(
                date: session.now,
                color: ink,
                size: split ? 72 : 84,
                caption: "Sunrise at \(session.sunriseStart.formatted(date: .omitted, time: .shortened))"
            )
        case .sunrise(let progress):
            NightClockView(date: session.now, color: ink.opacity(0.75 - progress * 0.3), size: split ? 64 : 76)
        case .ringing:
            greeting(title: session.kind == .test ? "Full daylight" : "Good morning",
                     detail: session.kind == .test ? "This is how bright it gets at wake time. Check that it reaches your pillow." : nil)
        case .snoozed(let until):
            greeting(title: "Snoozing",
                     detail: "Ringing again at \(until.formatted(date: .omitted, time: .shortened))")
        case .morning:
            greeting(title: "Good morning", detail: morningSummary)
        }
    }

    private func greeting(title: String, detail: String?) -> some View {
        VStack(spacing: 10) {
            NightClockView(date: session.now, color: Palette.daylightInk.opacity(0.85), size: 64)
            Text(title)
                .font(.display(34))
                .foregroundStyle(Palette.daylightInk)
            if let detail {
                Text(detail)
                    .scaledFont(15, weight: .regular, design: .rounded)
                    .foregroundStyle(Palette.daylightInk.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var morningSummary: String {
        guard let dismissed = session.dismissedAt else { return "" }
        let time = dismissed.formatted(date: .omitted, time: .shortened)
        switch session.snoozeCount {
        case 0: return "Up at \(time)."
        case 1: return "Up at \(time) after one snooze."
        default: return "Up at \(time) after \(session.snoozeCount) snoozes."
        }
    }

    // MARK: Lower half: controls

    @ViewBuilder
    private func lowerContent(onDarkHalf: Bool) -> some View {
        VStack(spacing: 14) {
            warnings(onDarkHalf: onDarkHalf)
            switch session.phase {
            case .ringing:
                if session.kind == .night {
                    secondaryButton("Snooze \(Int(session.snoozeLength / 60)) min", onDarkHalf: onDarkHalf, action: session.snooze)
                }
                primaryButton(session.kind == .test ? "Done" : "I'm up", onDarkHalf: onDarkHalf) {
                    if session.kind == .test { onFinish() } else { session.dismiss() }
                }
            case .snoozed:
                primaryButton("I'm up", onDarkHalf: onDarkHalf, action: session.dismiss)
            case .morning:
                primaryButton("Done", onDarkHalf: onDarkHalf, action: onFinish)
            case .windDown, .night, .sunrise:
                if controlsVisible || session.kind == .test {
                    nightControls
                        .transition(.opacity)
                } else if onDarkHalf {
                    // The bottom half faces the ceiling, not the pillow: a quiet status is fine here.
                    Text(nightSummary)
                        .scaledFont(13, weight: .medium, design: .rounded)
                        .foregroundStyle(Palette.nightRed.opacity(0.7))
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: 420)
        .animation(.easeInOut(duration: 0.4), value: controlsVisible)
        .animation(.easeInOut(duration: 0.6), value: session.phase)
    }

    /// On a folded Duo the controls sit on the dark bottom half, not on the light.
    @ViewBuilder
    private func primaryButton(_ title: String, onDarkHalf: Bool, action: @escaping () -> Void) -> some View {
        if onDarkHalf {
            Button(title, action: action).buttonStyle(.glow)
        } else {
            Button(title, action: action).buttonStyle(.daylight)
        }
    }

    @ViewBuilder
    private func secondaryButton(_ title: String, onDarkHalf: Bool, action: @escaping () -> Void) -> some View {
        if onDarkHalf {
            Button(action: action) {
                Text(title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassCapsule)
        } else {
            Button(title, action: action).buttonStyle(.daylightOutline)
        }
    }

    private var nightControls: some View {
        VStack(spacing: 12) {
            Text(nightSummary)
                .scaledFont(13, weight: .medium, design: .rounded)
                .foregroundStyle(ink.opacity(0.8))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                if case .windDown = session.phase {
                    Button("Skip wind-down", action: session.skipWindDown)
                        .buttonStyle(GlassCapsuleButtonStyle(tint: ink))
                }
                if session.kind == .test {
                    Button("Stop test", action: onFinish)
                        .buttonStyle(GlassCapsuleButtonStyle(tint: isDaylight ? Palette.daylightInk : Palette.ink))
                } else {
                    HoldToEndButton(tint: ink, action: onFinish)
                }
            }
        }
    }

    private var nightSummary: String {
        if session.kind == .test {
            return "Test sunrise. Watch the pillow, not the phone."
        }
        let start = session.sunriseStart.formatted(date: .omitted, time: .shortened)
        let wake = session.wake.formatted(date: .omitted, time: .shortened)
        return "Light at \(start), alarm at \(wake)"
    }

    @ViewBuilder
    private func warnings(onDarkHalf: Bool) -> some View {
        let messages = warningMessages
        if !messages.isEmpty {
            VStack(spacing: 4) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle")
                        .scaledFont(12, weight: .medium, design: .rounded)
                }
            }
            .foregroundStyle(isDaylight && !onDarkHalf ? Palette.daylightInk.opacity(0.7) : Palette.nightRed)
        }
    }

    private var warningMessages: [String] {
        var messages: [String] = []
        if session.kind == .night && power.isCharging == false { messages.append("Not charging") }
        if power.isLowPowerMode { messages.append("Low Power Mode may dim the light") }
        if session.isThrottled || power.isHot { messages.append("iOS is dimming the screen to cool down") }
        if session.kind == .night && power.outputVolume < 0.25 { messages.append("Volume is low. Turn it up for the alarm") }
        if session.kind == .night && power.isOnExternalAudio { messages.append("Sound is going to headphones or a speaker") }
        return messages
    }

    private func revealControls() {
        controlsVisible = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }
}

/// Ending the night by accident at 3 a.m. is worse than a slower button: hold for a second.
struct HoldToEndButton: View {
    var tint: Color
    var action: () -> Void

    @State private var progress: Double = 0
    @GestureState private var pressing = false

    var body: some View {
        Text("Hold to end night")
            .scaledFont(15, weight: .medium, design: .rounded)
            .foregroundStyle(tint)
            .padding(.horizontal, 20)
            .frame(minHeight: 46)
            .background {
                GeometryReader { geometry in
                    Capsule()
                        .fill(tint.opacity(0.18))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
            .onLongPressGesture(minimumDuration: 1.1) {
                action()
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: 1.1) : .easeOut(duration: 0.2)) {
                    progress = pressing ? 1 : 0
                }
            }
            .accessibilityLabel("End night")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

/// Dark, solid capsule that reads on top of bright light.
struct DaylightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(18, weight: .semibold, design: .rounded)
            .foregroundStyle(Color(red: 1, green: 0.96, blue: 0.9))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Palette.daylightInk.opacity(configuration.isPressed ? 0.75 : 0.9), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Secondary action on bright light: an ink outline instead of glass, which washes out on white.
struct DaylightOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(16, weight: .semibold, design: .rounded)
            .foregroundStyle(Palette.daylightInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.daylightInk.opacity(configuration.isPressed ? 0.12 : 0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.daylightInk.opacity(0.35), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DaylightOutlineButtonStyle {
    static var daylightOutline: DaylightOutlineButtonStyle { DaylightOutlineButtonStyle() }
}

extension ButtonStyle where Self == DaylightButtonStyle {
    static var daylight: DaylightButtonStyle { DaylightButtonStyle() }
}
