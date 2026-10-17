import CoreGraphics

/// The two halves of a view when the phone is half-folded, in the view's own coordinates.
public struct FoldLayout: Equatable, Sendable {
    /// True when the view straddles a horizontal hinge.
    public var isSplit: Bool
    /// Everything above the hinge, or the whole view when not split.
    public var upper: CGRect
    /// Everything below the hinge, or an empty rect at the bottom when not split.
    public var lower: CGRect

    /// Splits a view at a hinge. Both rects are in window coordinates; the result is local.
    public static func compute(posture: DevicePosture, viewFrameInWindow frame: CGRect) -> FoldLayout {
        let whole = CGRect(origin: .zero, size: frame.size)
        let unsplit = FoldLayout(
            isSplit: false,
            upper: whole,
            lower: CGRect(x: 0, y: frame.height, width: frame.width, height: 0)
        )
        // Only a horizontal hinge gives a top half to aim; treat anything else as one surface.
        guard let hinge = posture.hingeFrame, hinge.width >= hinge.height else { return unsplit }

        let top = min(max(hinge.minY - frame.minY, 0), frame.height)
        let bottom = min(max(hinge.maxY - frame.minY, top), frame.height)
        guard top > 0, bottom < frame.height else { return unsplit }

        return FoldLayout(
            isSplit: true,
            upper: CGRect(x: 0, y: 0, width: frame.width, height: top),
            lower: CGRect(x: 0, y: bottom, width: frame.width, height: frame.height - bottom)
        )
    }
}

#if canImport(UIKit)
import SwiftUI

/// Hands its content the current fold layout. Re-renders when the posture or size changes.
public struct FoldReader<Content: View>: View {
    @Environment(PostureMonitor.self) private var monitor: PostureMonitor?
    private let content: (FoldLayout) -> Content

    public init(@ViewBuilder content: @escaping (FoldLayout) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            content(
                FoldLayout.compute(
                    posture: monitor?.posture ?? .unknown,
                    viewFrameInWindow: geometry.frame(in: .global)
                )
            )
        }
    }
}
#endif
