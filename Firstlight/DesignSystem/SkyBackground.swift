import SwiftUI

/// The app's backdrop: a deep night sky with faint stars and a glow on the horizon tinted by the
/// chosen sunrise style. `dawn` (0...1) lifts the glow, for screens that preview the light.
struct SkyBackground: View {
    var style: SunriseStyle = .dawn
    var dawn: Double = 0.35
    var showsStars = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.020, green: 0.018, blue: 0.040), location: 0),
                        .init(color: Palette.night, location: 0.45),
                        .init(color: style.color(at: 0.08).scaled(by: 0.22 + 0.2 * dawn).color, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if showsStars {
                    StarField()
                        .mask(LinearGradient(colors: [.white, .white.opacity(0.6), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.7)))
                        .opacity(1 - dawn * 0.6)
                }

                TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let breathe = reduceMotion ? 1 : 1 + 0.035 * sin(t * 2 * .pi / 9)
                    HorizonGlow(style: style, intensity: dawn)
                        .frame(width: size.width * 1.9, height: size.width * 1.25)
                        .scaleEffect(breathe, anchor: .bottom)
                        .position(x: size.width / 2, y: size.height + size.width * 0.18)
                }

                GrainOverlay()
            }
        }
        .ignoresSafeArea()
    }
}

/// An elliptical bloom of sunrise colors, brightest at its bottom center.
struct HorizonGlow: View {
    var style: SunriseStyle
    var intensity: Double

    var body: some View {
        let core = style.color(at: 0.55 + intensity * 0.2)
        let mid = style.color(at: 0.32)
        let rim = style.color(at: 0.12)
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: core.color.opacity(0.55 + 0.35 * intensity), location: 0),
                        .init(color: mid.color.opacity(0.35 + 0.2 * intensity), location: 0.28),
                        .init(color: rim.color.opacity(0.16), location: 0.6),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 600
                )
            )
            .blur(radius: 30)
            .blendMode(.screen)
    }
}

/// Seeded, gently twinkling stars.
struct StarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        var x: Double
        var y: Double
        var radius: Double
        var phase: Double
        var speed: Double
        var brightness: Double
    }

    private let stars: [Star] = {
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<90).map { _ in
            Star(
                x: next(), y: pow(next(), 1.4),
                radius: 0.35 + pow(next(), 3) * 1.25,
                phase: next() * .pi * 2, speed: 0.4 + next() * 1.2,
                brightness: 0.25 + next() * 0.75
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for star in stars {
                    let twinkle = reduceMotion ? 1 : 0.65 + 0.35 * sin(t * star.speed + star.phase)
                    let rect = CGRect(
                        x: star.x * size.width - star.radius,
                        y: star.y * size.height - star.radius,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )
                    canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.brightness * twinkle * 0.8)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fine film grain that keeps big gradients from banding and gives surfaces some tooth.
struct GrainOverlay: View {
    var opacity: Double = 0.05

    var body: some View {
        Canvas { canvas, size in
            var seed: UInt64 = 0xC0FFEE
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 11) / Double(1 << 53)
            }
            let count = Int(size.width * size.height / 70)
            for _ in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1, height: 1)
                canvas.fill(Path(rect), with: .color(.white.opacity(next() * opacity)))
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

/// The brand mark: a sun cresting a horizon. The horizon is also the hinge.
struct HorizonMark: View {
    var style: SunriseStyle = .dawn
    var rise: Double = 1

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let horizon = h * 0.62
            let radius = w * 0.24
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [style.color(at: 0.6).color.opacity(0.7), style.color(at: 0.3).color.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: radius * 2.6
                    ))
                    .frame(width: radius * 5.2, height: radius * 5.2)
                    .position(x: w / 2, y: horizon)
                    .blendMode(.screen)

                Circle()
                    .fill(LinearGradient(
                        colors: [style.color(at: 0.95).color, style.color(at: 0.62).color, style.color(at: 0.4).color],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: w / 2, y: horizon + radius * (1.15 - rise * 1.0))
                    .mask(Rectangle().frame(height: horizon).frame(maxHeight: .infinity, alignment: .top))

                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, Palette.ink.opacity(0.75), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w * 0.9, height: 1)
                    .position(x: w / 2, y: horizon)
            }
        }
    }
}
