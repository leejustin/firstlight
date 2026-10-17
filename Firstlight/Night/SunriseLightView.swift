import SwiftUI

/// The light itself. Early on it's a glow rising from the bottom edge, like a sun under the
/// horizon; by about two-thirds through it floods the whole surface evenly, which is what puts the
/// most light on the pillow.
struct SunriseLightView: View {
    let frame: SunriseFrame

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let spread = frame.spread
            let base = frame.color.scaled(by: 0.4 + 0.6 * spread)
            let core = frame.color.mixed(with: LightColor(red: 1, green: 0.97, blue: 0.92), by: 0.12 * spread)
            ZStack {
                base.hdrColor(boostStops: frame.boostStops)

                RadialGradient(
                    stops: [
                        .init(color: core.hdrColor(boostStops: frame.boostStops), location: 0),
                        .init(color: frame.color.hdrColor(boostStops: frame.boostStops), location: 0.45),
                        .init(color: frame.color.hdrColor(boostStops: frame.boostStops).opacity(0), location: 1),
                    ],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: height * (0.7 + 1.6 * spread)
                )
            }
        }
        .allowedDynamicRange(.high)
        .animation(.linear(duration: 0.3), value: frame)
        .accessibilityHidden(true)
    }
}

/// Wind-down: a low amber glow that sinks away over ten minutes.
struct WindDownLightView: View {
    let progress: Double

    var body: some View {
        let ember = LightColor(kelvin: 1900).scaled(by: 0.55 * (1 - progress))
        RadialGradient(
            colors: [ember.color, ember.scaled(by: 0.35).color, .black],
            center: .bottom,
            startRadius: 0,
            endRadius: 700 * (1 - 0.5 * progress)
        )
        .animation(.linear(duration: 1), value: progress)
        .accessibilityHidden(true)
    }
}
