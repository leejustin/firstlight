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
    /// The latest hinge sensor reading; nil on devices without a hinge.
    public private(set) var hingeReading: HingeReading?
    public private(set) var orientation: GravityOrientation = .unknown
    public private(set) var windowSize: CGSize = .zero

    /// Development aid: behave like a half-folded Duo on hardware or simulators without a hinge.
    public var simulatesHalfFold = false

    public var hinge: HingeState {
        simulatesHalfFold
            ? .halfOpen(frame: estimatedHinge(in: windowSize))
            : HingeState(reading: hingeReading, windowSize: windowSize)
    }

    public var posture: DevicePosture {
        DevicePosture(hinge: hinge, orientation: orientation)
    }

    /// Whether this device has a hinge at all.
    public var isFoldable: Bool {
        simulatesHalfFold || hingeReading != nil
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

    func update(reading: HingeReading?) {
        if reading != hingeReading { hingeReading = reading }
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

/// A zero-content UIKit view that reports its window's size and the hinge to the monitor.
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

        override init(frame: CGRect) {
            super.init(frame: frame)
            if #available(iOS 27.1, *) {
                // Called with the current state when added to a window, then on every change.
                // On iOS 27.0, or an iPhone without a hinge, posture falls back to gravity alone.
                addInteraction(UIHingeInteraction { [weak self] _, update in
                    self?.monitor?.update(reading: update.hinge.map(HingeReading.init))
                })
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
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
@available(iOS 27.1, *)
extension HingeReading {
    @MainActor
    init(_ hinge: UIHinge) {
        let status: Status = switch hinge.status {
        case .closed: .closed
        case .partiallyOpen: .partiallyOpen
        case .fullyOpen: .fullyOpen
        default: .unknown
        }
        self.init(status: status, angle: Double(hinge.angle))
    }
}
#endif
