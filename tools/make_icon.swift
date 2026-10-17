// Draws the Firstlight app icon: a sun cresting a horizon that doubles as the hinge.
//
//   swift tools/make_icon.swift Firstlight/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
}

// CoreGraphics' origin is bottom-left; work in top-down coordinates.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

let s = CGFloat(size)
let horizon = s * 0.6

// Sky
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizon))
ctx.drawLinearGradient(
    gradient([(0, rgb(0x06050E)), (0.42, rgb(0x150A22)), (0.72, rgb(0x4A1230)), (0.9, rgb(0xA8301C)), (1, rgb(0xE8642A))]),
    start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: horizon), options: []
)
ctx.restoreGState()

// Ground / water
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: horizon, width: s, height: s - horizon))
ctx.drawLinearGradient(
    gradient([(0, rgb(0x2A0A14)), (0.3, rgb(0x10060D)), (1, rgb(0x050408))]),
    start: CGPoint(x: 0, y: horizon), end: CGPoint(x: 0, y: s), options: []
)
ctx.restoreGState()

// Stars
var seed: UInt64 = 42
func rand() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat(Double(seed >> 11) / Double(1 << 53))
}
for _ in 0..<38 {
    let x = s * 0.08 + rand() * s * 0.84
    let y = s * 0.08 + pow(rand(), 1.6) * horizon * 0.55
    let r = 1.2 + pow(rand(), 3) * 3.2
    ctx.setFillColor(rgb(0xFFFFFF, 0.25 + rand() * 0.5))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

let sunCenter = CGPoint(x: s / 2, y: horizon + s * 0.05)
let sunRadius = s * 0.22

// Bloom around the sun in the sky, and a fainter one on the water
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizon))
ctx.drawRadialGradient(
    gradient([(0, rgb(0xFFB25C, 0.85)), (0.35, rgb(0xFF6A2E, 0.45)), (1, rgb(0xFF4A1E, 0))]),
    startCenter: sunCenter, startRadius: 0, endCenter: sunCenter, endRadius: s * 0.62, options: []
)
ctx.restoreGState()
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: horizon, width: s, height: s - horizon))
ctx.translateBy(x: sunCenter.x, y: horizon)
ctx.scaleBy(x: 1.4, y: 0.55)
ctx.drawRadialGradient(
    gradient([(0, rgb(0xFF9A50, 0.42)), (0.4, rgb(0xE0502A, 0.16)), (1, rgb(0xC0401E, 0))]),
    startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: s * 0.5, options: []
)
ctx.restoreGState()

// The sun, clipped at the horizon
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizon))
ctx.addEllipse(in: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2))
ctx.clip()
ctx.drawLinearGradient(
    gradient([(0, rgb(0xFFF6E8)), (0.5, rgb(0xFFD49A)), (1, rgb(0xFF9A48))]),
    start: CGPoint(x: 0, y: sunCenter.y - sunRadius), end: CGPoint(x: 0, y: horizon), options: []
)
ctx.restoreGState()

// Reflection: soft horizontal bands under the horizon
for i in 0..<6 {
    let y = horizon + 22 + CGFloat(i) * CGFloat(24 + i * 4)
    let width = sunRadius * (1.05 - CGFloat(i) * 0.16)
    let alpha = 0.5 - CGFloat(i) * 0.075
    ctx.setFillColor(rgb(0xFFC48A, alpha))
    let band = CGRect(x: s / 2 - width, y: y, width: width * 2, height: 8 - CGFloat(i))
    ctx.addPath(CGPath(roundedRect: band, cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.fillPath()
}

// The horizon line, brightest at the center: the hinge.
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: horizon - 3, width: s, height: 6))
ctx.drawLinearGradient(
    gradient([(0, rgb(0xFFE8CC, 0)), (0.5, rgb(0xFFF1DE, 1)), (1, rgb(0xFFE8CC, 0))]),
    start: CGPoint(x: s * 0.04, y: 0), end: CGPoint(x: s * 0.96, y: 0), options: []
)
ctx.restoreGState()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: out)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(url.path)")
