# firstlight
Firstlight — a sunrise wake-up light alarm for iPhone Duo

The phone stands half-folded on the nightstand with its top half aimed at your pillow, glows from deep red to daylight over 1–30 minutes, and wakes you with light before sound. See [SPEC.md](SPEC.md).

## Build

Open `Firstlight.xcodeproj` and run the **Firstlight** scheme. The scheme uses `Firstlight.storekit`, so Pro can be bought in the simulator.

- Target: iOS 27, iPhone only, Swift 6 with main-actor default isolation.
- Build with Xcode 27.1 and the iOS 27.1 SDK; older SDKs show black borders on the Duo's inner screen. The deployment target stays iOS 27.0, and hinge support switches on at 27.1.
- Signing needs a development team, with these registered: the iCloud container `iCloud.app.firstlight`, the app group `group.app.firstlight.alarm` (shared with the widget) and the HomeKit capability. Without a team, settings stay on the device and the widget shows no alarm.

## Layout

| Path | What's there |
| --- | --- |
| `Packages/FoldPosture` | Shared fold-posture helper for Carriage, Grid Fleet and Firstlight: `PostureMonitor`, `DevicePosture`, `FoldReader` |
| `Firstlight/Sunrise` | Color and brightness math: blackbody colors, styles, the brightness curve, HDR boost |
| `Firstlight/Night` | `NightSession` state machine (wind-down → night → sunrise → ringing/snooze → morning) and the full-screen night views |
| `Firstlight/Home` | Home screen and the time, light and sound sheets |
| `Firstlight/Setup` | Onboarding, animated placement guide, bedtime checklist |
| `Firstlight/Services` | Screen brightness, power/heat/volume, sound engine, flashlight, AlarmKit backup alarm, HomeKit lamps |
| `Firstlight/Store` | StoreKit 2 Pro unlock and paywall |
| `Firstlight/Settings` | Settings and the **Light check** diagnostic |
| `FirstlightWidgets` | Widget extension: the "Next sunrise" widget and the backup alarm's Live Activity (snooze countdown) |
| `Shared` | Types compiled into both the app and the widget extension |
| `site` | Product page, privacy policy and support page, published on GitHub Pages |
| `tools/` | Generators for the bundled sounds and the app icon, and `screenshots.sh` for the App Store set |

## Hinge detection

On iOS 27.1, `FoldTraitBridge` (`PostureMonitor.swift`) adds a `UIHingeInteraction` and feeds each `UIHinge` reading to `PostureMonitor`. iOS reports the hinge's status and angle but not where it sits on screen, so a partly open hinge is placed across the middle of the window (`estimatedHinge`). On iOS 27.0, or an iPhone without a hinge, posture comes from gravity alone (flat / standing / face down).

**Settings › Simulate half-fold** splits the screen at its midpoint, for simulators without a hinge. On the iPhone Duo simulator, change postures with Xcode's DeviceHub.

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
xcrun simctl launch booted app.firstlight.alarm -screen sunrise:0.4 -simulateFold YES -pro YES
```

Screens: `onboarding`, `home`, `time`, `light`, `sound`, `windDown`, `settings`, `pro`, `bedtime`, `windDownNight`, `night`, `sunrise:<0…1>`, `ringing`, `snoozed`, `morning`, `test`.

Add `-screenshots YES` to show the alarm as on without touching AlarmKit, and to set the in-app clocks to a believable night. `tools/screenshots.sh` does all of this; see [docs/AppStore.md](docs/AppStore.md).

## Website

`site/` holds the product page, privacy policy and support page that App Store Connect asks for, published at https://leejustin.github.io/firstlight/ from the `gh-pages` branch. After changing `site/`, publish with:

```bash
git subtree push --prefix site origin gh-pages
```

To serve it from firstlight.app later, add a `CNAME` file containing the domain to `site/` and point the domain's DNS at GitHub Pages.

## The brightness question

The spec's go/no-go risk is whether a phone can put enough light on the pillow and hold full brightness for 30 minutes. **Settings › Light check** holds full white (optionally with HDR boost) for 5–45 minutes. It logs the brightness iOS reports, the heat state and the battery every 5 seconds, and has a field for the lux your meter reads at the pillow. Run it on a real Duo before committing to the build.
