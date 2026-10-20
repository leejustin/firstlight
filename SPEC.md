# Dawnfold — spec

Working name Firstlight. Renamed to Dawnfold because another developer already uses the Firstlight name on the App Store.

Pitch: a wake-up light alarm built for the Duo's half-fold. The phone sits sideways on the nightstand, folded like a laptop, with its top half aimed at your pillow, glows from deep red to bright white over 30 minutes, and wakes you with light before sound. Regular phones lie flat and light the ceiling; the Duo can aim at your face. Competitors: LightWake Alarm Clock and Light Alarm (regular iPhone screens) and HomeKit bulb apps. None aim the light or support the Duo.

## Platform rules (all apps)
- Build with Xcode 27.1 and the iOS 27.1 SDK, or the app shows black borders on the inner screen.
- Draw only on the inner screen while open. Third-party apps get no general way to use the outer screen while open, and no API says which panel a window is on.
- Detect half-fold posture and the hinge with Apple's posture and trait APIs. Folding is a trait change, so the app keeps its state.
- It must run well on regular iPhones too (with a stand).
- From April 2027 every submission needs iPhone Duo screenshots.
- Shared stack: Swift and SwiftUI, support iOS 27+, SwiftData plus iCloud, StoreKit 2, AlarmKit. One shared fold-posture helper is reused across all three apps (Carriage, Grid Fleet, Dawnfold).

## How a night works
1. Setup: pick a wake time and sunrise length. The app shows placement: half-folded, 40–60 cm from your head, top half facing the pillow, plugged in.
2. Bedtime: pure black screen with a dim red clock. Optional wind-down: a warm glow fades out over 10 minutes.
3. Sunrise: starting up to 30 minutes before wake time (the sunrise length), the screen fades from black to deep red, amber, warm white, and finally full bright white at wake time.
4. Sound: an optional nature sound fades in over the last 5 minutes.
5. Wake: a gentle alarm sound at wake time. Snooze keeps the light on full.
6. Backup: a regular alarm fires 2 minutes after wake time if the app was closed overnight.

## MVP features
- Sunrise curve: 1–30 minutes (default 30), color from about 1800 K to 6500 K, brightness ramping slowly at first and faster near the end.
- Night screen: pure black with a dim red clock that drifts a few pixels every minute to avoid burn-in.
- Backup alarm through AlarmKit, so it sounds even if the app is closed.
- Animated placement guide showing the half-fold pose and distance.
- Test sunrise: the full sunrise in 60 seconds, to check placement.
- Charging check: a warning at bedtime if the phone isn't plugged in.
- Sounds: birds, rain and soft chimes, with a fade-in length setting.
- Regular iPhone support (the setup guide says to use a stand).
- Flashlight boost (free, off by default): the rear flashlight fades in over the last few minutes, lighting the wall behind the phone. On a Duo, fold it with the camera half on top. Users can try it from settings.

## Later
Built ahead of plan: wind-down sunset and HomeKit lamps following the same sunrise (both Pro), a Lock Screen "Next sunrise" widget, and a Live Activity that gives the backup alarm a Snooze button. Later: sleep stats from Apple Health.

## Technical notes
- The app stays open all night: it disables auto-lock while running and sets screen brightness itself.
- Override auto-brightness during the sunrise. Detect Night Shift and True Tone and tell people to turn them off for the night.
- Power: require or strongly suggest charging. Pause and warn if Low Power Mode would dim the screen.
- Posture: show the light on the top half only when half-folded. If the phone is flat or closed at bedtime, prompt the user to fold it.
- Suggest turning on the Sleep Focus.

## Monetization
Free with one sunrise style, one sound, the flashlight boost and the backup alarm. A $3.99 one-time Pro adds custom curves and colors, all sounds, the wind-down sunset and HomeKit lights.

## Positioning
Installable on every iPhone but presented as a Duo app: Duo-first App Store text and screenshots, and "Made for iPhone Duo" in onboarding on other iPhones. There's no supported way to limit installs to the Duo, and an update can't add install restrictions later.

## Risks and open questions
- Brightness: roughly 30–70 lux at the pillow, against 250–300 lux for a dedicated wake-up lamp. Test before building. The half-fold lights only half the inner screen, so a regular iPhone on a stand gives about the same light; the Duo's edge is aiming without a stand, not brightness.
- Apple's StandBy already runs on the Duo and could add a sunrise feature.
- It's niche and harder to charge for, so keep it small and cheap to build.
- Open question: will iOS let an app hold full brightness for 30 minutes without dimming for heat? Test on a real Duo.

## Submission checklist
Built with the iOS 27.1 SDK; tested in all postures in Device Hub; works on a regular iPhone; Duo and regular screenshots; original name, icon and art; App Review notes explain the fold features; privacy details filled in; in-app purchases tested in the sandbox.
