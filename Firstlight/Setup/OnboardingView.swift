import FoldPosture
import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AppModel.self) private var model
    @State private var page = 0
    @State private var rise: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 4

    var body: some View {
        ZStack {
            SkyBackground(style: .dawn, dawn: 0.2 + Double(page) * 0.2)
                .animation(.easeInOut(duration: 1.2), value: page)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    placement.tag(1)
                    backup.tag(2)
                    tonight.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 18)

                Button(buttonTitle) {
                    advance()
                }
                .buttonStyle(.glow)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var buttonTitle: String {
        if page == pageCount - 1 { return "Start" }
        if page == 2 && model.backup.canAskForAuthorization { return "Allow alarms" }
        return "Continue"
    }

    private func advance() {
        if page == 2 && model.backup.canAskForAuthorization {
            Task {
                await model.backup.requestAuthorization()
                withAnimation { page += 1 }
            }
            return
        }
        if page < pageCount - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Palette.amber : Palette.inkTertiary)
                    .frame(width: index == page ? 22 : 6, height: 6)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityHidden(true)
    }

    // MARK: Pages

    private var welcome: some View {
        page(
            eyebrow: nil,
            title: "A sunrise alarm for your nightstand",
            body: "In the minutes before your alarm, the screen fades from deep red to bright white. The light starts waking you before any sound plays."
        ) {
            HorizonMark(style: .dawn, rise: rise)
                .frame(width: 220, height: 220)
                .onAppear {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 3.2)) { rise = 1 }
                }
        }
    }

    private var placement: some View {
        page(
            eyebrow: model.posture.isFoldable ? nil : "Made for iPhone Duo",
            title: model.posture.isFoldable ? "Set it up like a laptop" : "Stand it up facing you",
            body: model.posture.isFoldable
                ? "Turn it sideways and fold it halfway, like a little laptop on the nightstand. The top half faces your pillow from 40–60 cm away and lights up. Keep it plugged in."
                : "Dawnfold is built around the Duo's fold, but a stand does the same job. Put it 40–60 cm from your head with the screen toward the pillow, and keep it plugged in. Lying flat, it only lights the ceiling."
        ) {
            PlacementGuideView(foldable: model.posture.isFoldable)
                .frame(height: 220)
        }
    }

    private var backup: some View {
        page(
            eyebrow: nil,
            title: "There's a backup alarm",
            body: "If Dawnfold gets closed during the night, a normal alarm goes off two minutes after your wake time."
        ) {
            ZStack {
                Circle()
                    .fill(Palette.amber.opacity(0.12))
                    .frame(width: 170, height: 170)
                    .blur(radius: 20)
                Image(systemName: "alarm.waves.left.and.right")
                    .font(.system(size: 70, weight: .ultraLight))
                    .foregroundStyle(Palette.warmGradient)
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.5)))
            }
            .frame(height: 220)
        }
    }

    private var tonight: some View {
        page(
            eyebrow: nil,
            title: "Before you sleep",
            body: nil
        ) {
            VStack(alignment: .leading, spacing: 18) {
                tip("circle.lefthalf.filled", "Turn off Night Shift and True Tone", "They tint the light yellow and dim the white. Control Center › long-press brightness.")
                tip("moon.fill", "Turn on Sleep Focus", "Keeps notifications from lighting the screen at 3 a.m.")
                tip("bolt.fill", "Plug it in", "Full brightness for 30 minutes uses a lot of battery.")
            }
            .padding(.horizontal, 8)
        }
    }

    private func tip(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .scaledFont(18, design: .default)
                .foregroundStyle(Palette.amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .scaledFont(17, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .scaledFont(14, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    /// Stacked when the screen is tall; side by side when it's wide, as on a sideways Duo.
    private func page<Hero: View>(eyebrow: String?, title: String, body: String?, @ViewBuilder hero: () -> Hero) -> some View {
        let hero = hero()
        return GeometryReader { geometry in
            let isWide = geometry.size.width > geometry.size.height * 1.2
            let text = pageText(eyebrow: eyebrow, title: title, body: body, centered: !isWide)
            Group {
                if isWide {
                    HStack(spacing: 40) {
                        hero.frame(maxWidth: .infinity)
                        text.frame(maxWidth: 420, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 28) {
                        Spacer(minLength: 20)
                        hero
                        text
                        Spacer(minLength: 20)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 24)
    }

    private func pageText(eyebrow: String?, title: String, body: String?, centered: Bool) -> some View {
        let alignment: TextAlignment = centered ? .center : .leading
        return VStack(alignment: centered ? .center : .leading, spacing: 14) {
            if let eyebrow {
                Eyebrow(eyebrow, color: Palette.amber.opacity(0.85))
            }
            Text(title)
                .font(.display(34))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(alignment)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let body {
                Text(body)
                    .scaledFont(16, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(alignment)
                    .lineSpacing(3)
                    .padding(.horizontal, centered ? 12 : 0)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
