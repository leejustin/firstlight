import AVFoundation

/// The rear flashlight, used as an optional boost in the last minutes of a sunrise. It points away
/// from the screen, so the light reaches the pillow by bouncing off the wall behind the phone.
@MainActor
final class TorchController {
    private let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    private var applied: Float = 0

    /// False on devices without a flashlight, including the simulator.
    static var isSupported: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)?.hasTorch ?? false
    }

    /// 0 turns it off. Small changes are skipped; the torch doesn't need 4 updates a second.
    func set(level: Double) {
        guard let device, device.hasTorch else { return }
        let target = Float(min(max(level, 0), 1))
        guard abs(target - applied) >= 0.02 || (target == 0 && applied != 0) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            // iOS makes the torch unavailable when the phone is too hot; just stay off then.
            if target < 0.01 || !device.isTorchAvailable {
                device.torchMode = .off
                applied = 0
            } else {
                try device.setTorchModeOn(level: min(target, AVCaptureDevice.maxAvailableTorchLevel))
                applied = target
            }
        } catch {
            applied = 0
        }
    }

    func off() {
        set(level: 0)
    }

    /// A few seconds of the boost: fade up, hold, fade down.
    func preview(level: Double) async {
        let steps = 12
        for i in 1...steps {
            set(level: level * Double(i) / Double(steps))
            try? await Task.sleep(for: .milliseconds(120))
        }
        try? await Task.sleep(for: .seconds(3))
        for i in stride(from: steps - 1, through: 0, by: -1) {
            set(level: level * Double(i) / Double(steps))
            try? await Task.sleep(for: .milliseconds(80))
        }
        off()
    }
}
