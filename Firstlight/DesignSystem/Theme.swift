import SwiftUI

enum Palette {
    /// Near-black with a trace of violet, so pure black light screens still read as "different".
    static let night = Color(red: 0.031, green: 0.027, blue: 0.051)
    static let nightRaised = Color(red: 0.071, green: 0.063, blue: 0.102)
    static let ink = Color(red: 0.965, green: 0.933, blue: 0.902)
    static let inkSecondary = ink.opacity(0.62)
    static let inkTertiary = ink.opacity(0.52)
    static let hairline = Color.white.opacity(0.08)

    static let ember = Color(red: 1.0, green: 0.478, blue: 0.239)
    static let amber = Color(red: 1.0, green: 0.698, blue: 0.361)
    static let blush = Color(red: 0.949, green: 0.635, blue: 0.549)
    /// The night clock. Long-wavelength red disturbs sleep least.
    static let nightRed = Color(red: 0.62, green: 0.09, blue: 0.05)
    /// Text drawn on top of daylight.
    static let daylightInk = Color(red: 0.24, green: 0.13, blue: 0.07)

    static let warmGradient = LinearGradient(
        colors: [amber, ember],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Font {
    /// Editorial serif for headlines and the wordmark.
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Thin rounded numerals for clocks.
    static func clock(_ size: CGFloat, weight: Font.Weight = .thin) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

/// A rounded system font that follows the user's text size, like a text style, at the size the
/// design calls for. Use it for anything smaller than display type.
struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: size <= 13 ? .footnote : .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .rounded) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}

/// Small tracked caps above a section: "WAKE", "SUNRISE".
struct Eyebrow: View {
    let text: String
    var color: Color = Palette.inkTertiary

    init(_ text: String, color: Color = Palette.inkTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .scaledFont(13, weight: .semibold, design: .rounded)
            .foregroundStyle(color)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Palette.night)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Palette.warmGradient, in: Capsule())
    }
}

// MARK: - Buttons

/// The one warm, glowing call to action on a screen.
struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(17, weight: .semibold, design: .rounded)
            .foregroundStyle(Color(red: 0.16, green: 0.07, blue: 0.03))
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                Capsule()
                    .fill(Palette.warmGradient)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                    .shadow(color: Palette.ember.opacity(configuration.isPressed ? 0.15 : 0.25), radius: 10, y: 4)
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Quiet glass capsule for secondary actions.
struct GlassCapsuleButtonStyle: ButtonStyle {
    var tint: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(15, weight: .medium, design: .rounded)
            .foregroundStyle(tint)
            .padding(.horizontal, 20)
            .frame(minHeight: 46)
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlowButtonStyle {
    static var glow: GlowButtonStyle { GlowButtonStyle() }
}

extension ButtonStyle where Self == GlassCapsuleButtonStyle {
    static var glassCapsule: GlassCapsuleButtonStyle { GlassCapsuleButtonStyle() }
}

// MARK: - Surfaces

extension View {
    /// A Liquid Glass panel with the app's corner radius.
    func glassPanel(cornerRadius: CGFloat = 28, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// Hides the status bar and home indicator for full-screen light.
    func immersive() -> some View {
        self
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .ignoresSafeArea()
    }
}

// MARK: - Sheets

extension View {
    func nightSheetStyle() -> some View {
        self
            .presentationBackground(Palette.nightRaised.opacity(0.92))
            .presentationCornerRadius(36)
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
    }
}

/// Title row for sheets.
struct SheetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.display(28))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
