import UIKit

/// Owns the screen for a night: keeps it awake, drives brightness, and puts both back afterwards.
@MainActor
final class ScreenController {
    private var savedBrightness: CGFloat?

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
            ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    /// The brightness iOS currently reports, which drops below what we asked for if it throttles.
    var reportedBrightness: Double {
        Double(screen?.brightness ?? 0)
    }

    func begin() {
        if savedBrightness == nil {
            savedBrightness = screen?.brightness
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Sets brightness, skipping changes too small to see. Call it repeatedly: re-applying wins
    /// back control if auto-brightness nudges the value.
    func setBrightness(_ value: Double, force: Bool = false) {
        guard let screen else { return }
        let target = min(max(value, 0), 1)
        guard force || abs(Double(screen.brightness) - target) > 0.002 else { return }
        screen.brightness = CGFloat(target)
    }

    func end() {
        if let savedBrightness {
            screen?.brightness = savedBrightness
        }
        savedBrightness = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
