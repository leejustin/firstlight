# firstlight
Firstlight — a sunrise wake-up light alarm for iPhone Duo

The phone stands half-folded on the nightstand with its top half aimed at your pillow, glows from deep red to daylight over 1–30 minutes, and wakes you with light before sound. See [SPEC.md](SPEC.md).

## Build

Open `Firstlight.xcodeproj` and run the **Firstlight** scheme. The scheme uses `Firstlight.storekit`, so Pro can be bought in the simulator.

- Target: iOS 27, iPhone only, Swift 6 with main-actor default isolation.
- Ship with Xcode 27.1 and the iOS 27.1 SDK, which adds the Duo's posture and hinge traits (without it the inner screen shows black borders). The project currently builds with Xcode 27.0.
- iCloud sync needs a development team. Set it under Signing, then make sure the container `iCloud.com.leejustin.firstlight` exists. Without a team, settings stay on the device.

## Layout

| Path | What's there |
| --- | --- |
| `Packages/FoldPosture` | Shared fold-posture helper for Carriage, Grid Fleet and Firstlight: `PostureMonitor`, `DevicePosture`, `FoldReader` |
| `Firstlight/Sunrise` | Color and brightness math: blackbody colors, styles, the brightness curve, HDR boost |
| `Firstlight/Night` | `NightSession` state machine (wind-down → night → sunrise → ringing/snooze → morning) and the full-screen night views |
| `Firstlight/Home` | Home screen and the time, light and sound sheets |
| `Firstlight/Setup` | Onboarding, animated placement guide, bedtime checklist |
| `Firstlight/Services` | Screen brightness, power/heat/volume, sound engine, AlarmKit backup alarm |
| `Firstlight/Store` | StoreKit 2 Pro unlock and paywall |
| `Firstlight/Settings` | Settings and the **Light check** diagnostic |
| `tools/` | Generators for the bundled sounds and the app icon |

## Hinge detection

The iOS 27.0 SDK has no hinge or posture traits yet. `PostureMonitor` already combines a `HingeState` with gravity from CoreMotion. When building against 27.1, register for the new traits in `FoldTraitBridge` (`PostureMonitor.swift`) and call `monitor.update(hinge:)`; nothing else changes. Until then a regular-iPhone posture (flat / standing / face down) comes from gravity, and **Settings › Simulate half-fold** splits the screen at its midpoint, as on a folded Duo.

## Sounds and icon

All audio is synthesized, so there are no third-party assets:

```bash
tools/make_sounds.sh
```

```bash
swift tools/make_icon.swift Firstlight/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Debug launch arguments

Debug builds can open straight to any screen, which is handy for design review and App Store screenshots:

```bash
xcrun simctl launch booted com.leejustin.firstlight -screen sunrise:0.4 -simulateFold YES -pro YES
```

Screens: `onboarding`, `home`, `time`, `light`, `sound`, `windDown`, `settings`, `pro`, `bedtime`, `windDownNight`, `night`, `sunrise:<0…1>`, `ringing`, `snoozed`, `morning`, `test`.

## The brightness question

The spec's go/no-go risk is whether a phone can put enough light on the pillow and hold full brightness for 30 minutes. **Settings › Light check** holds full white (optionally with HDR boost) for 5–45 minutes. It logs the brightness iOS reports, the heat state and the battery every 5 seconds, and has a field for the lux your meter reads at the pillow. Run it on a real Duo before committing to the build.
