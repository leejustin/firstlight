#if canImport(UIKit)
import CoreMotion
import Observation
import SwiftUI
import UIKit

/// Watches the hinge and gravity and publishes a single `DevicePosture`.
///
/// Folding is a trait change, so nothing here tears down view state; views just re-read `posture`.
@MainActor
@Observable
public final class PostureMonitor {
    public private(set) var hinge: HingeState = .unavailable
    public private(set) var orientation: GravityOrientation = .unknown
    public private(set) var windowSize: CGSize = .zero

    /// Development aid: behave like a half-folded Duo on hardware or simulators without a hinge.
    public var simulatesHalfFold = false

    public var posture: DevicePosture {
        let effectiveHinge: HingeState = simulatesHalfFold
            ? .halfOpen(frame: estimatedHinge(in: windowSize))
            : hinge
        return DevicePosture(hinge: effectiveHinge, orientation: orientation)
    }

    /// Whether this device has reported a hinge at all.
    public var isFoldable: Bool {
        simulatesHalfFold || hinge != .unavailable
    }

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var activeClients = 0

    public init() {}

    public func start() {
        activeClients += 1
        guard activeClients == 1, motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 0.5
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let gravity = data?.gravity else { return }
            let next = GravityOrientation(gravity: SIMD3(gravity.x, gravity.y, gravity.z))
            MainActor.assumeIsolated {
                guard let self, next != self.orientation else { return }
                self.orientation = next
            }
        }
    }

    public func stop() {
        activeClients = max(0, activeClients - 1)
        if activeClients == 0 {
            motion.stopDeviceMotionUpdates()
        }
    }

    /// Feed hinge changes from the system's fold traits.
    public func update(hinge: HingeState) {
        if hinge != self.hinge { self.hinge = hinge }
    }

    func update(windowSize: CGSize) {
        if windowSize != self.windowSize { self.windowSize = windowSize }
    }
}

public extension View {
    /// Starts posture monitoring while this view is on screen and makes the monitor available to
    /// descendants through `@Environment(PostureMonitor.self)`.
    func foldPosture(_ monitor: PostureMonitor) -> some View {
        modifier(FoldPostureModifier(monitor: monitor))
    }
}

private struct FoldPostureModifier: ViewModifier {
    let monitor: PostureMonitor

    func body(content: Content) -> some View {
        content
            .background(FoldTraitBridge(monitor: monitor).allowsHitTesting(false))
            .environment(monitor)
            .onAppear { monitor.start() }
            .onDisappear { monitor.stop() }
    }
}

/// A zero-content UIKit view that reports its window's size and fold traits to the monitor.
private struct FoldTraitBridge: UIViewRepresentable {
    let monitor: PostureMonitor

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.monitor = monitor
        return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
        uiView.monitor = monitor
    }

    final class BridgeView: UIView {
        weak var monitor: PostureMonitor?
        private var isRegistered = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
            guard !isRegistered else { return }
            isRegistered = true
            // The iOS 27.1 SDK adds the hinge and posture traits. Register for them here and pass
            // the result to `monitor.update(hinge:)`; until then the hinge stays `.unavailable` and
            // posture falls back to gravity alone.
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) {
                (view: BridgeView, _: UITraitCollection) in
                view.report()
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let window else { return }
            monitor?.update(windowSize: window.bounds.size)
        }
    }
}
#endif
