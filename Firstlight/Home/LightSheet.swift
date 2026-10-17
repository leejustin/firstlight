import Charts
import FoldPosture
import SwiftUI

struct LightSheet: View {
    @Bindable var settings: AlarmSettings
    var showPro: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var styles: [SunriseStyle] {
        SunriseStyle.presets + [.custom(endKelvin: settings.customKelvin)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SheetHeader(title: "Sunrise style")

                VStack(spacing: 12) {
                    ForEach(styles) { style in
                        StyleRow(
                            style: style,
                            isSelected: settings.styleID == style.id,
                            isLocked: style.isPro && !model.isPro
                        ) {
                            if style.isPro && !model.isPro { showPro() } else { settings.styleID = style.id }
                        }
                    }
                }

                if settings.styleID == SunriseStyle.customID && model.isPro {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Eyebrow("Final color")
                            Spacer()
                            Text("\(Int(settings.customKelvin)) K")
                                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        Slider(value: $settings.customKelvin, in: 2700...7500, step: 100)
                            .tint(LightColor(kelvin: settings.customKelvin).color)
                        HStack {
                            Text("Candle warm")
                            Spacer()
                            Text("Crisp daylight")
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.inkTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow("Brightness curve")
                    CurveChart(curve: settings.curve(isPro: model.isPro))
                        .frame(height: 120)
                    ForEach(CurveShape.allCases) { shape in
                        let locked = shape.isPro && !model.isPro
                        Button {
                            if locked { showPro() } else { settings.curveShape = shape }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: settings.curveShape == shape ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(settings.curveShape == shape ? Palette.amber : Palette.inkTertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shape.name)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(Palette.ink)
                                    Text(shape.detail)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                                Spacer()
                                if locked { ProBadge() }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                TorchBoostSection(settings: settings)

                Toggle(isOn: $settings.hdrBoost) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Extra-bright finish")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Text("Uses HDR headroom for the last few minutes on displays that have it.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .tint(Palette.ember)

                Button("Done") { dismiss() }
                    .buttonStyle(.glow)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .nightSheetStyle()
    }
}

private struct StyleRow: View {
    let style: SunriseStyle
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Capsule()
                    .fill(LinearGradient(
                        stops: (0...8).map { i in
                            let t = Double(i) / 8
                            return .init(color: style.color(at: t).scaled(by: 0.45 + 0.55 * t).color, location: t)
                        },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 92, height: 40)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(style.name)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        if isLocked { ProBadge() }
                    }
                    Text(style.tagline)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.amber)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.white.opacity(isSelected ? 0.08 : 0.03))
                    .strokeBorder(isSelected ? Palette.amber.opacity(0.5) : Palette.hairline, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Light output across the sunrise, filled with the sunrise's own colors.
struct CurveChart: View {
    let curve: SunriseCurve

    private struct Point: Identifiable {
        let t: Double
        let output: Double
        var id: Double { t }
    }

    var body: some View {
        let points = (0...40).map { i in
            let t = Double(i) / 40
            return Point(t: t, output: curve.frame(at: t).screenBrightness)
        }
        Chart(points) { point in
            AreaMark(x: .value("Time", point.t), y: .value("Brightness", point.output))
                .foregroundStyle(LinearGradient(
                    stops: (0...8).map { i in
                        let t = Double(i) / 8
                        return .init(color: curve.style.color(at: t).scaled(by: 0.4 + 0.6 * t).color.opacity(0.85), location: t)
                    },
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.t), y: .value("Brightness", point.output))
                .foregroundStyle(Palette.ink.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: [0, 1]) { value in
                AxisValueLabel {
                    Text(value.as(Double.self) == 0 ? "First light" : "Wake")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .animation(.smooth, value: curve.shape)
        .accessibilityLabel("Brightness rises slowly at first and faster near wake time.")
    }
}

/// The optional flashlight finish: on/off, when it starts, how strong, and a way to try it now.
struct TorchBoostSection: View {
    @Bindable var settings: AlarmSettings

    @Environment(PostureMonitor.self) private var posture: PostureMonitor?
    @State private var torch = TorchController()
    @State private var isPreviewing = false

    private let isSupported = TorchController.isSupported

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Flashlight boost")

            Toggle(isOn: $settings.torchEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add the flashlight at the end")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(placementHint)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Palette.ember)
            .disabled(!isSupported)

            if settings.torchEnabled && isSupported {
                Stepper(value: $settings.torchMinutes, in: AlarmSettings.torchMinutesRange) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starts \(settings.torchMinutes) min before wake")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText())
                        Text("Fades up to full by wake time, and stays on through snooze.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                HStack(spacing: 14) {
                    Image(systemName: "flashlight.off.fill").foregroundStyle(Palette.inkTertiary)
                    Slider(value: $settings.torchStrength, in: 0.2...1)
                        .tint(Palette.amber)
                        .accessibilityLabel("Flashlight strength")
                    Image(systemName: "flashlight.on.fill").foregroundStyle(Palette.inkTertiary)
                }
            }

            if isSupported {
                Button {
                    guard !isPreviewing else { return }
                    isPreviewing = true
                    Task {
                        await torch.preview(level: settings.torchStrength)
                        isPreviewing = false
                    }
                } label: {
                    Label(isPreviewing ? "Shining…" : "Try it for 5 seconds", systemImage: "flashlight.on.fill")
                }
                .buttonStyle(.glassCapsule)
                .disabled(isPreviewing)
            } else {
                Text("This device has no flashlight.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .animation(.smooth, value: settings.torchEnabled)
        .onDisappear { torch.off() }
    }

    private var placementHint: String {
        if posture?.isFoldable == true {
            return "The flashlight is on the back, so it shines on the wall behind the phone. Fold it with the camera half on top, near a light-colored wall."
        }
        return "The flashlight is on the back, so it shines on the wall behind the phone. Works best with a light-colored wall close behind the nightstand."
    }
}
