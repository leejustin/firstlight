import SwiftUI

/// Sunrise length as a strip of the sunrise itself: drag it longer and the colors stretch out.
struct SunriseLengthSlider: View {
    @Binding var minutes: Int
    var curve: SunriseCurve
    var range: ClosedRange<Int> = AlarmSettings.sunriseRange
    var step = 1

    private let height: CGFloat = 54
    private let thumb: CGFloat = 46

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let fraction = Double(minutes - range.lowerBound) / Double(range.upperBound - range.lowerBound)
                let fillWidth = thumb + 8 + (width - thumb - 8) * fraction

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))

                    Capsule()
                        .fill(LinearGradient(stops: gradientStops, startPoint: .leading, endPoint: .trailing))
                        .frame(width: fillWidth)
                        .overlay(alignment: .leading) {
                            Text("\(minutes) min")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink.opacity(0.9))
                                .padding(.leading, 18)
                                .opacity(fillWidth > 120 ? 1 : 0)
                        }
                        .shadow(color: curve.style.color(at: 0.5).color.opacity(0.35), radius: 18, x: 6)

                    Circle()
                        .fill(.white)
                        .overlay(Circle().fill(curve.style.color(at: 1).color).padding(3))
                        .frame(width: thumb, height: thumb)
                        .shadow(color: .white.opacity(0.5), radius: 12)
                        .offset(x: fillWidth - thumb - 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let usable = width - thumb - 8
                            let raw = (value.location.x - thumb / 2 - 4) / usable
                            let clamped = min(max(raw, 0), 1)
                            let span = Double(range.upperBound - range.lowerBound)
                            let snapped = Int((clamped * span / Double(step)).rounded()) * step + range.lowerBound
                            if snapped != minutes { minutes = snapped }
                        }
                )
            }
            .frame(height: height)

            // Labels sit under the thumb's center at each mark, so an uneven last step (40 → 45) lines up.
            GeometryReader { geometry in
                let usable = geometry.size.width - thumb - 8
                let span = Double(range.upperBound - range.lowerBound)
                ForEach(marks, id: \.self) { mark in
                    Text("\(mark)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(mark == minutes ? Palette.ink : Palette.inkTertiary)
                        .fixedSize()
                        .position(
                            x: thumb / 2 + 4 + usable * Double(mark - range.lowerBound) / span,
                            y: geometry.size.height / 2
                        )
                }
            }
            .frame(height: 14)
        }
        .sensoryFeedback(.selection, trigger: minutes)
        .accessibilityElement()
        .accessibilityLabel("Sunrise length")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(minutes + step, range.upperBound)
            case .decrement: minutes = max(minutes - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    /// The ends of the range plus every 10 minutes in between: 1, 10, 20, 30.
    private var marks: [Int] {
        let tens = stride(from: 10, to: range.upperBound, by: 10).filter { $0 > range.lowerBound }
        return [range.lowerBound] + tens + [range.upperBound]
    }

    /// The sunrise sampled left to right, brightened so the dark start still reads as color.
    private var gradientStops: [Gradient.Stop] {
        (0...14).map { i in
            let t = Double(i) / 14
            let frame = curve.frame(at: t)
            let visible = frame.color.scaled(by: 0.35 + 0.65 * sqrt(frame.screenBrightness))
            return .init(color: (i == 0 ? curve.style.color(at: 0).scaled(by: 0.35) : visible).color, location: t)
        }
    }
}
