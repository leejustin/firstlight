# App Store submission

## Listing

**Name:** Firstlight: Sunrise Alarm
**Subtitle:** Wake to light before sound
**Promotional text:** Made for iPhone Duo. Fold it like a tent and the sunrise aims itself at your pillow.
**Category:** Lifestyle (secondary: Health & Fitness)
**Price:** Free, with a $3.99 one-time Firstlight Pro (`app.firstlight.pro`, non-consumable, Family Sharing on)

**Keywords:** sunrise,alarm,wake up light,dawn,light alarm,gentle alarm,sleep,morning,duo,fold

**Description**

A sunrise alarm made for iPhone Duo.

Fold your Duo halfway like a tent and set it on the nightstand. The top half aims the light straight at your pillow, and the bottom half lies flat with the snooze and stop buttons. You don't need a lamp or a stand.

Firstlight turns your iPhone into a sunrise. In the half hour before your alarm, the screen glows from deep red through amber to bright daylight, so light starts waking you before any sound does. Birdsong fades in over the last few minutes, and a soft marimba rings at wake time.

Using another iPhone? Firstlight works on any iPhone with iOS 27. Prop it on a stand so the screen faces you.

• A sunrise from 1 to 30 minutes, from about 1800 K to 6500 K
• A night screen that's pure black, with a dim red clock that moves a little each minute to protect the display
• A backup alarm that still rings if Firstlight was closed overnight
• A 60-second test sunrise to check your placement
• An optional flashlight boost for the last few minutes, bounced off the wall behind the phone
• Snooze keeps the light on full
• Bedtime checks for charging, position, Low Power Mode and volume

Firstlight Pro, one purchase with no subscription:
• Ember, Coastal and Nordic sunrises, plus a custom finish from candle-warm to crisp daylight
• Steady and late-bloom brightness curves
• Soft rain and wind chimes
• A wind-down sunset that sinks to black as you fall asleep

## App Review notes

> Firstlight is a sunrise alarm. While a night is running, the app stays open in the foreground: it disables auto-lock (`isIdleTimerDisabled`) and sets screen brightness itself, ramping it up over the sunrise. It restores the user's brightness when the night ends or the app leaves the foreground.
>
> On iPhone Duo, when the phone is half-folded, the light is drawn only on the top half (above the hinge), which faces the pillow, and the controls are on the bottom half. On other iPhones the whole screen is used, and the setup guide asks people to use a stand.
>
> AlarmKit is used only for a backup alarm two minutes after wake time, so the user still wakes up if the app was closed overnight. Dismissing the in-app alarm cancels that morning's backup.
>
> The optional flashlight boost (Light › Flashlight boost, off by default) turns on the rear torch through `AVCaptureDevice` for the last few minutes before wake. The app never starts a capture session and never uses the camera.
>
> To see the whole sunrise quickly: Home › "Test sunrise · 60 s". Pro can be tested with the sandbox purchase on the Settings screen.

## Privacy (App Privacy questionnaire)

- **Data collection:** none. Select "Data Not Collected".
- Alarm settings sync through the user's own iCloud private database (CloudKit). Apple hosts it, and the developer can't read it, so it doesn't count as collection.
- No analytics, no ads, no tracking, no third-party SDKs.
- `PrivacyInfo.xcprivacy` declares UserDefaults (reason CA92.1).

## Positioning

Firstlight is installable on every iPhone, but it presents itself as a Duo app. There is no supported way to limit installs to the Duo (no device-capability key for the hinge), and Apple won't allow adding install restrictions in a later update. Regular iPhones are a supported "with a stand" mode.

- Lead every surface with the Duo: promotional text, the first lines of the description, and the first screenshots.
- Keep "iPhone Duo" out of the app name, subtitle and icon. Apple's trademark guidelines allow "for iPhone"-style references in the description, but not Apple trademarks in the app name. Check the current wording before submitting.
- On regular iPhones, onboarding says "Made for iPhone Duo · works with a stand".

## Screenshots

Lead with the Duo set: the half-folded sunrise is the hero shot. Regular-iPhone screenshots come after it.

From April 2027 iPhone Duo screenshots are required. Debug builds open any screen directly (see README › Debug launch arguments):

| # | Screen | Launch arguments |
| --- | --- | --- |
| 1 | Home | `-screen home` |
| 2 | Sunrise in progress (Duo, half-folded) | `-screen sunrise:0.45 -simulateFold YES` |
| 3 | Wake-up | `-screen ringing` |
| 4 | Choose your sunrise | `-screen light -pro YES` |
| 5 | Night clock | `-screen night` |
| 6 | Bedtime checklist | `-screen bedtime` |

Take the Duo set on a real Duo (or a 27.1 Duo simulator) so the hinge is real, not simulated.

## Before submitting

- [ ] Build with Xcode 27.1 / iOS 27.1 SDK (avoids black borders on the Duo's inner screen)
- [ ] Wire the 27.1 hinge traits into `FoldTraitBridge` (see README › Hinge detection)
- [ ] Test in every posture in Device Hub, and on a regular iPhone
- [ ] Set the development team, enable iCloud and register `iCloud.app.firstlight`
- [ ] Create the Pro in-app purchase in App Store Connect and test it in the sandbox
- [ ] Run Light check on a real Duo for 30 minutes and record pillow lux
- [ ] Confirm on device that the flashlight works without a camera permission prompt
- [ ] Let a real overnight run with the backup alarm finish (close the app, confirm the backup rings)
- [ ] Privacy questionnaire, review notes, Duo and regular screenshots
