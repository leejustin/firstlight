import SwiftUI

/// The bedside clock: thin numerals that wander a few points each minute so no pixel stays lit
/// in one place all night.
struct NightClockView: View {
    let date: Date
    var color: Color = Palette.nightRed
    var size: CGFloat = 84
    var caption: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
                Text(TimeText.clock(date))
                    .font(.clock(size))
                    .contentTransition(.numericText())
                if let period = TimeText.period(date) {
                    Text(period)
                        .font(.system(size: size * 0.22, weight: .light, design: .rounded))
                }
            }
            .foregroundStyle(color)
            if let caption {
                Text(caption)
                    .scaledFont(13, weight: .medium, design: .rounded)
                    .foregroundStyle(color.opacity(0.6))
            }
        }
        .offset(Self.drift(for: date))
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.5), value: Self.minuteIndex(date))
    }

    static func minuteIndex(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 60)
    }

    /// A stable offset within ±10 pt for each minute.
    static func drift(for date: Date, range: Double = 10) -> CGSize {
        var seed = UInt64(truncatingIfNeeded: minuteIndex(date)) &* 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed ^= seed >> 33
            seed = seed &* 0xFF51_AFD7_ED55_8CCD
            seed ^= seed >> 33
            return Double(seed % 10_000) / 10_000
        }
        return CGSize(width: (next() * 2 - 1) * range, height: (next() * 2 - 1) * range)
    }
}
