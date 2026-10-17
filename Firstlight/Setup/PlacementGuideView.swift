import SwiftUI

/// A looping side-view diagram: the phone folds into a tent on the nightstand, its top half
/// glows toward the pillow, and the distance is marked. `foldable: false` shows a regular iPhone
/// on a stand instead.
struct PlacementGuideView: View {
    var foldable = true
    var style: SunriseStyle = .dawn

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let loop: Double = 9

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 5.5 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: time)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(foldable
            ? "Fold the phone halfway like a tent, 40 to 60 centimeters from your head, top half facing the pillow, plugged in."
            : "Stand the phone up on a stand, 40 to 60 centimeters from your head, screen facing the pillow, plugged in.")
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let w = size.width
        let h = size.height
        let line = Palette.ink.opacity(0.42)
        let faint = Palette.ink.opacity(0.18)

        // Timeline: 0–1.4 s flat, fold until 3 s, glow until 8 s, fade out by 9 s.
        let foldT = ease(clamp((time - 1.4) / 1.6))
        let glowT = clamp((time - 3.0) / 5.0)
        let fadeOut = 1 - clamp((time - 8.2) / 0.8)

        let tableY = h * 0.70
        let standLeft = w * 0.06
        let standRight = w * 0.40

        // Nightstand
        var stand = Path()
        stand.addRoundedRect(in: CGRect(x: standLeft, y: tableY, width: standRight - standLeft, height: h * 0.24), cornerSize: CGSize(width: 6, height: 6))
        canvas.fill(stand, with: .color(Palette.ink.opacity(0.04)))
        canvas.stroke(stand, with: .color(faint), lineWidth: 1)
        var drawerLine = Path()
        drawerLine.move(to: CGPoint(x: standLeft + 10, y: tableY + h * 0.10))
        drawerLine.addLine(to: CGPoint(x: standRight - 10, y: tableY + h * 0.10))
        canvas.stroke(drawerLine, with: .color(faint), lineWidth: 1)

        // Bed, pillow and head
        let bedTop = h * 0.66
        var bed = Path()
        bed.addRoundedRect(in: CGRect(x: w * 0.58, y: bedTop, width: w * 0.46, height: h * 0.28), cornerSize: CGSize(width: 10, height: 10))
        canvas.fill(bed, with: .color(Palette.ink.opacity(0.035)))
        canvas.stroke(bed, with: .color(faint), lineWidth: 1)

        let pillow = CGRect(x: w * 0.62, y: bedTop - h * 0.075, width: w * 0.30, height: h * 0.10)
        canvas.fill(Path(roundedRect: pillow, cornerRadius: h * 0.05), with: .color(Palette.ink.opacity(0.06)))
        canvas.stroke(Path(roundedRect: pillow, cornerRadius: h * 0.05), with: .color(line), lineWidth: 1.2)

        let headCenter = CGPoint(x: w * 0.71, y: pillow.minY - h * 0.035)
        let headRadius = h * 0.075
        let head = Path(ellipseIn: CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius, width: headRadius * 2, height: headRadius * 2))
        canvas.fill(head, with: .color(Palette.night))
        canvas.stroke(head, with: .color(line), lineWidth: 1.2)
        // Closed eye, facing the phone
        var eye = Path()
        eye.addArc(center: CGPoint(x: headCenter.x - headRadius * 0.45, y: headCenter.y - headRadius * 0.05), radius: headRadius * 0.18, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        canvas.stroke(eye, with: .color(line), lineWidth: 1.2)

        // Phone
        let hinge = CGPoint(x: w * 0.17, y: tableY - 2)
        let panel = w * 0.14
        let screenSegment: (CGPoint, CGPoint)

        if foldable {
            // Bottom half lies flat toward the bed; top half rises at the hinge.
            let bottomEnd = CGPoint(x: hinge.x + panel, y: hinge.y)
            let opening = 180 - foldT * 78 // degrees between the halves
            let angle = Angle.degrees(opening).radians
            let topEnd = CGPoint(x: hinge.x + cos(angle) * panel, y: hinge.y - sin(angle) * panel)

            var body = Path()
            body.move(to: bottomEnd)
            body.addLine(to: hinge)
            body.addLine(to: topEnd)
            canvas.stroke(body, with: .color(Palette.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            canvas.fill(Path(ellipseIn: CGRect(x: hinge.x - 3, y: hinge.y - 3, width: 6, height: 6)), with: .color(Palette.amber.opacity(0.9)))
            screenSegment = (hinge, topEnd)
        } else {
            // Regular iPhone on a little stand, leaning back slightly.
            let base = CGPoint(x: hinge.x + panel * 0.15, y: hinge.y)
            let lean = Angle.degrees(78).radians
            let top = CGPoint(x: base.x - cos(lean) * panel * 1.15, y: base.y - sin(lean) * panel * 1.15)
            var standShape = Path()
            standShape.move(to: CGPoint(x: base.x - panel * 0.35, y: hinge.y))
            standShape.addLine(to: CGPoint(x: base.x + panel * 0.25, y: hinge.y))
            standShape.addLine(to: CGPoint(x: base.x - panel * 0.12, y: hinge.y - panel * 0.55))
            standShape.closeSubpath()
            canvas.stroke(standShape, with: .color(line), lineWidth: 1.2)
            var phone = Path()
            phone.move(to: base)
            phone.addLine(to: top)
            canvas.stroke(phone, with: .color(Palette.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            screenSegment = (base, top)
        }

        // Light from the screen to the face
        if glowT > 0 {
            let color = style.color(at: 0.15 + glowT * 0.85).color
            // A widening cone that fades out just past the head, so it has no hard far edge.
            let far = headCenter.x + headRadius * 1.6
            var beam = Path()
            beam.move(to: screenSegment.0)
            beam.addLine(to: screenSegment.1)
            beam.addLine(to: CGPoint(x: far, y: headCenter.y - headRadius * 2.4))
            beam.addLine(to: CGPoint(x: far, y: pillow.maxY + 6))
            beam.closeSubpath()
            let strength = (0.12 + 0.42 * glowT) * fadeOut
            let source = CGPoint(
                x: (screenSegment.0.x + screenSegment.1.x) / 2,
                y: (screenSegment.0.y + screenSegment.1.y) / 2
            )
            canvas.fill(beam, with: .linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(strength), location: 0),
                    .init(color: color.opacity(strength * 0.35), location: 0.7),
                    .init(color: color.opacity(0), location: 1),
                ]),
                startPoint: source,
                endPoint: CGPoint(x: far, y: source.y)
            ))
            var screenLine = Path()
            screenLine.move(to: screenSegment.0)
            screenLine.addLine(to: screenSegment.1)
            canvas.stroke(screenLine, with: .color(color.opacity(fadeOut)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        // Distance marker
        let markerAlpha = clamp((time - 3.2) / 0.6) * fadeOut
        if markerAlpha > 0 {
            let y = h * 0.20
            let from = CGPoint(x: screenSegment.1.x, y: y)
            let to = CGPoint(x: headCenter.x - headRadius, y: y)
            var dash = Path()
            dash.move(to: from)
            dash.addLine(to: to)
            canvas.stroke(dash, with: .color(Palette.ink.opacity(0.5 * markerAlpha)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            for end in [from, to] {
                var tick = Path()
                tick.move(to: CGPoint(x: end.x, y: y - 6))
                tick.addLine(to: CGPoint(x: end.x, y: y + 6))
                canvas.stroke(tick, with: .color(Palette.ink.opacity(0.6 * markerAlpha)), lineWidth: 1)
            }
            let label = Text("40–60 cm")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(markerAlpha))
            canvas.draw(label, at: CGPoint(x: (from.x + to.x) / 2, y: y - 14))
        }

        // Charging cable dropping off the back of the nightstand
        var cable = Path()
        let plug = CGPoint(x: hinge.x - 6, y: hinge.y)
        cable.move(to: plug)
        cable.addCurve(
            to: CGPoint(x: standLeft - 4, y: tableY + h * 0.2),
            control1: CGPoint(x: plug.x - w * 0.08, y: plug.y),
            control2: CGPoint(x: standLeft - 10, y: tableY + h * 0.05)
        )
        canvas.stroke(cable, with: .color(Palette.amber.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        let bolt = Text(Image(systemName: "bolt.fill"))
            .font(.system(size: 11))
            .foregroundStyle(Palette.amber.opacity(0.8))
        canvas.draw(bolt, at: CGPoint(x: standLeft - 2, y: tableY + h * 0.24))
    }

    private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
