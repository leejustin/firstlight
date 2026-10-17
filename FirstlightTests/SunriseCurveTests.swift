import Foundation
import Testing
@testable import Firstlight

struct SunriseCurveTests {
    let curve = SunriseCurve(style: .dawn, shape: .gentle, hdrBoost: true)

    @Test func startsBlackAndEndsAtFullBrightness() {
        let start = curve.frame(at: 0)
        #expect(start.color == .black)
        #expect(start.screenBrightness == SunriseCurve.minimumBrightness)

        let end = curve.frame(at: 1)
        #expect(end.screenBrightness == 1)
        #expect(end.boostStops == SunriseCurve.maxBoostStops)
        #expect(end.spread == 1)
    }

    @Test func brightnessOnlyEverRises() {
        var previous = -1.0
        for i in 0...100 {
            let output = curve.relativeOutput(at: Double(i) / 100)
            #expect(output >= previous - 1e-9)
            previous = output
        }
    }

    @Test func rampsSlowlyThenFaster() {
        let firstHalf = curve.frame(at: 0.5).screenBrightness - curve.frame(at: 0).screenBrightness
        let secondHalf = curve.frame(at: 1).screenBrightness - curve.frame(at: 0.5).screenBrightness
        #expect(secondHalf > firstHalf * 2)
    }

    @Test func colorWarmsFromRedToDaylight() {
        let early = SunriseStyle.dawn.color(at: 0.1)
        #expect(early.red > early.green * 3)
        let late = SunriseStyle.dawn.color(at: 1)
        #expect(late.blue > 0.9)
    }

    @Test func boostIsOffWhenDisabled() {
        let plain = SunriseCurve(style: .dawn, shape: .gentle, hdrBoost: false)
        #expect(plain.frame(at: 1).boostStops == 0)
    }

    @Test func lateBloomStaysDimmerLonger() {
        let late = SunriseCurve(style: .dawn, shape: .late)
        let steady = SunriseCurve(style: .dawn, shape: .steady)
        #expect(late.frame(at: 0.5).screenBrightness < steady.frame(at: 0.5).screenBrightness)
    }

    @Test func kelvinTracksTemperature() {
        let candle = LightColor(kelvin: 1800)
        let daylight = LightColor(kelvin: 6500)
        #expect(candle.red == 1)
        #expect(candle.blue < 0.2)
        #expect(daylight.blue > 0.95)
    }

    @Test func customStyleClampsTemperature() {
        #expect(SunriseStyle.custom(endKelvin: 99_000).tagline.contains("7500"))
        #expect(SunriseStyle.resolve(id: "nope", customKelvin: 5000) == .dawn)
    }
}

struct SunriseWindowTests {
    let wake = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func progressAcrossTheWindow() {
        let window = SunriseWindow(wake: wake, duration: 1800)
        #expect(window.progress(at: wake.addingTimeInterval(-1801)) == nil)
        #expect(window.progress(at: wake.addingTimeInterval(-900)) == 0.5)
        #expect(window.progress(at: wake.addingTimeInterval(60)) == 1)
    }
}
