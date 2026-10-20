import CoreGraphics
import Foundation

/// What the hinge is doing, as reported by the system's fold traits.
public enum HingeState: Equatable, Sendable {
    /// Not a foldable, or the system hasn't said.
    case unavailable
    /// Fully open and flat.
    case open
    /// Bent partway, like a laptop. `frame` is the hinge band in window coordinates.
    case halfOpen(frame: CGRect)
    /// Folded shut. Apps on the inner screen rarely see this, but handle it.
    case closed
}

/// One reading from the system's hinge sensor (`UIHinge` on iOS 27.1), without UIKit types so it
/// can be tested anywhere.
public struct HingeReading: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case unknown
        case closed
        case partiallyOpen
        case fullyOpen
    }

    public var status: Status
    /// Radians, as reported. Apple warns the update rate and precision vary, so posture is decided
    /// from `status`; the angle is kept for display and finer tuning.
    public var angle: Double

    public init(status: Status, angle: Double) {
        self.status = status
        self.angle = angle
    }
}

public extension HingeState {
    /// Translates a sensor reading. iOS reports the hinge's status and angle but not where it sits
    /// in the window, so a partly open hinge is placed across the middle (`estimatedHinge`).
    /// A nil reading means the view isn't in a hierarchy with a hinge: a regular iPhone.
    init(reading: HingeReading?, windowSize: CGSize) {
        switch reading?.status {
        case nil, .unknown?: self = .unavailable
        case .closed?: self = .closed
        case .fullyOpen?: self = .open
        case .partiallyOpen?: self = .halfOpen(frame: estimatedHinge(in: windowSize))
        }
    }
}

/// Which way gravity points relative to the screen.
public enum GravityOrientation: Equatable, Sendable {
    case faceUp
    case faceDown
    case upright
    case unknown

    /// Classifies a CoreMotion gravity vector (in g). `z` is -1 when the phone lies on its back.
    public init(gravity: SIMD3<Double>?, threshold: Double = 0.75) {
        guard let gravity else {
            self = .unknown
            return
        }
        if gravity.z < -threshold {
            self = .faceUp
        } else if gravity.z > threshold {
            self = .faceDown
        } else {
            self = .upright
        }
    }
}

/// How the phone is sitting right now, combining the hinge and gravity.
public enum DevicePosture: Equatable, Sendable {
    /// A foldable bent partway open, standing on its lower half.
    case halfFolded(hinge: CGRect)
    /// Standing or propped up: an open foldable held upright, or any iPhone on a stand.
    case standing
    /// Lying on its back, screen to the ceiling.
    case flat
    /// Screen down on the table.
    case faceDown
    /// A foldable folded shut.
    case closed
    case unknown

    public init(hinge: HingeState, orientation: GravityOrientation) {
        switch hinge {
        case .halfOpen(let frame):
            self = .halfFolded(hinge: frame)
        case .closed:
            self = .closed
        case .open, .unavailable:
            switch orientation {
            case .faceUp: self = .flat
            case .faceDown: self = .faceDown
            case .upright: self = .standing
            case .unknown: self = .unknown
            }
        }
    }

    public var isHalfFolded: Bool {
        if case .halfFolded = self { return true }
        return false
    }

    /// True when the screen can face something across the room instead of the ceiling.
    public var isAimable: Bool {
        switch self {
        case .halfFolded, .standing: true
        case .flat, .faceDown, .closed, .unknown: false
        }
    }

    public var hingeFrame: CGRect? {
        if case .halfFolded(let frame) = self { return frame }
        return nil
    }
}

/// Where the hinge is, given that iOS doesn't say: a horizontal line across the middle of the window.
/// In the laptop pose (phone sideways, bottom half flat) the interface is landscape and the hinge
/// runs left to right.
public func estimatedHinge(in windowSize: CGSize) -> CGRect {
    CGRect(x: 0, y: windowSize.height / 2, width: windowSize.width, height: 0)
}
