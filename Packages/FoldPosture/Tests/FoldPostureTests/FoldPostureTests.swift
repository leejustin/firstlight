import CoreGraphics
import Testing
@testable import FoldPosture

struct GravityOrientationTests {
    @Test func lyingOnItsBackIsFaceUp() {
        #expect(GravityOrientation(gravity: SIMD3(0, 0, -0.98)) == .faceUp)
    }

    @Test func screenDownIsFaceDown() {
        #expect(GravityOrientation(gravity: SIMD3(0.1, 0, 0.95)) == .faceDown)
    }

    @Test func proppedUpIsUpright() {
        #expect(GravityOrientation(gravity: SIMD3(0, -0.8, -0.5)) == .upright)
    }

    @Test func missingGravityIsUnknown() {
        #expect(GravityOrientation(gravity: nil) == .unknown)
    }
}

struct DevicePostureTests {
    let hinge = CGRect(x: 0, y: 400, width: 600, height: 20)

    @Test func halfOpenHingeWinsOverGravity() {
        let posture = DevicePosture(hinge: .halfOpen(frame: hinge), orientation: .faceUp)
        #expect(posture == .halfFolded(hinge: hinge))
        #expect(posture.isAimable)
    }

    @Test func regularPhoneFallsBackToGravity() {
        #expect(DevicePosture(hinge: .unavailable, orientation: .faceUp) == .flat)
        #expect(DevicePosture(hinge: .unavailable, orientation: .upright) == .standing)
        #expect(!DevicePosture.flat.isAimable)
    }

    @Test func closedIsClosed() {
        #expect(DevicePosture(hinge: .closed, orientation: .upright) == .closed)
    }
}

struct HingeReadingTests {
    let window = CGSize(width: 800, height: 700)

    @Test func noReadingMeansNoHinge() {
        #expect(HingeState(reading: nil, windowSize: window) == .unavailable)
    }

    @Test func unknownStatusDefaultsToTheLaptopPose() {
        let state = HingeState(reading: HingeReading(status: .unknown, angle: 0), windowSize: window)
        #expect(state == .halfOpen(frame: CGRect(x: 0, y: 350, width: 800, height: 0)))
    }

    @Test func partlyOpenIsHalfOpenAcrossTheMiddle() {
        let state = HingeState(reading: HingeReading(status: .partiallyOpen, angle: 1.9), windowSize: window)
        #expect(state == .halfOpen(frame: CGRect(x: 0, y: 350, width: 800, height: 0)))
    }

    @Test func openAndClosed() {
        #expect(HingeState(reading: HingeReading(status: .fullyOpen, angle: .pi), windowSize: window) == .open)
        #expect(HingeState(reading: HingeReading(status: .closed, angle: 0), windowSize: window) == .closed)
    }
}

struct FoldLayoutTests {
    @Test func splitsAtTheHinge() {
        let posture = DevicePosture.halfFolded(hinge: CGRect(x: 0, y: 400, width: 600, height: 20))
        let layout = FoldLayout.compute(posture: posture, viewFrameInWindow: CGRect(x: 0, y: 0, width: 600, height: 820))
        #expect(layout.isSplit)
        #expect(layout.upper == CGRect(x: 0, y: 0, width: 600, height: 400))
        #expect(layout.lower == CGRect(x: 0, y: 420, width: 600, height: 400))
    }

    @Test func convertsFromWindowCoordinates() {
        let posture = DevicePosture.halfFolded(hinge: CGRect(x: 0, y: 400, width: 600, height: 0))
        let layout = FoldLayout.compute(posture: posture, viewFrameInWindow: CGRect(x: 0, y: 100, width: 600, height: 600))
        #expect(layout.upper.height == 300)
        #expect(layout.lower.minY == 300)
    }

    @Test func viewEntirelyAboveTheHingeIsNotSplit() {
        let posture = DevicePosture.halfFolded(hinge: CGRect(x: 0, y: 400, width: 600, height: 0))
        let layout = FoldLayout.compute(posture: posture, viewFrameInWindow: CGRect(x: 0, y: 0, width: 600, height: 300))
        #expect(!layout.isSplit)
        #expect(layout.upper.height == 300)
    }

    @Test func standingIsOneSurface() {
        let layout = FoldLayout.compute(posture: .standing, viewFrameInWindow: CGRect(x: 0, y: 0, width: 390, height: 844))
        #expect(!layout.isSplit)
        #expect(layout.lower.height == 0)
    }

    @Test func estimatedHingeSitsMidway() {
        #expect(estimatedHinge(in: CGSize(width: 600, height: 800)).midY == 400)
    }
}
