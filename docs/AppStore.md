# App Store submission

## Listing

**Name:** Dawnfold: Sunrise Alarm
**Subtitle:** Wake to light before sound
**Promotional text:** Made for iPhone Duo. Fold it like a tent and the sunrise aims itself at your pillow.
**Category:** Lifestyle (secondary: Health & Fitness)
**Price:** Free, with a $3.99 one-time Dawnfold Pro (`app.dawnfold.pro`, non-consumable, Family Sharing on)

**Keywords:** sunrise,alarm,wake up light,dawn,light alarm,gentle alarm,sleep,morning,duo,fold

**Description**

A sunrise alarm made for iPhone Duo.

Fold your Duo halfway like a tent and set it on the nightstand. The top half aims the light straight at your pillow, and the bottom half lies flat with the snooze and stop buttons. You don't need a lamp or a stand.

Dawnfold turns your iPhone into a sunrise. In the half hour before your alarm, the screen glows from deep red through amber to bright daylight, so light starts waking you before any sound does. Birdsong fades in over the last few minutes, and a soft marimba rings at wake time.

Using another iPhone? Dawnfold works on any iPhone with iOS 27. Prop it on a stand so the screen faces you.

• A sunrise from 1 to 30 minutes, from about 1800 K to 6500 K
• A night screen that's pure black, with a dim red clock that moves a little each minute to protect the display
• A backup alarm that still rings if Dawnfold was closed overnight
• A 60-second test sunrise to check your placement
• An optional flashlight boost for the last few minutes, bounced off the wall behind the phone
• Snooze keeps the light on full
• Bedtime checks for charging, position, Low Power Mode and volume

Dawnfold Pro, one purchase with no subscription:
• Ember, Coastal and Nordic sunrises, plus a custom finish from candle-warm to crisp daylight
• Steady and Late brightness curves
• Soft rain and wind chimes
• A wind-down sunset that sinks to black as you fall asleep
• HomeKit lamps that follow the sunrise, for far more light than a screen

## App Review notes

> Dawnfold is a sunrise alarm. While a night is running, the app stays open in the foreground: it disables auto-lock (`isIdleTimerDisabled`) and sets screen brightness itself, ramping it up over the sunrise. It restores the user's brightness when the night ends or the app leaves the foreground.
>
> On iPhone Duo, when the phone is half-folded, the light is drawn only on the top half (above the hinge), which faces the pillow, and the controls are on the bottom half. On other iPhones the whole screen is used, and the setup guide asks people to use a stand.
>
> AlarmKit is used only for a backup alarm two minutes after wake time, so the user still wakes up if the app was closed overnight. Dismissing the in-app alarm cancels that morning's backup.
>
> The optional flashlight boost (Light › Flashlight boost, off by default) turns on the rear torch through `AVCaptureDevice` for the last few minutes before wake. The app never starts a capture session and never uses the camera.
>
> HomeKit (Pro, off by default) lists the user's lights so they can pick some, then sets their power, brightness and color during the sunrise while the app is open. It doesn't create scenes or automations.
>
> A widget extension draws the backup alarm's Live Activity, so the system alarm offers Snooze with a Lock Screen countdown, and provides a "Next sunrise" widget.
>
> To see the whole sunrise quickly: Home › "Try a 60-second sunrise". Pro can be tested with the sandbox purchase on the Settings screen.

## Links

- **Support URL:** https://leejustin.github.io/firstlight/support.html
- **Privacy Policy URL:** https://leejustin.github.io/firstlight/privacy.html
- **Marketing URL:** https://leejustin.github.io/firstlight/

## Privacy (App Privacy questionnaire)

- **Data collection:** none. Select "Data Not Collected".
- Alarm settings sync through the user's own iCloud private database (CloudKit). Apple hosts it, and the developer can't read it, so it doesn't count as collection.
- No analytics, no ads, no tracking, no third-party SDKs.
- HomeKit: the IDs of the lamps the user picks are stored with their alarm settings. Home data never leaves the device except through Apple's HomeKit.
- `PrivacyInfo.xcprivacy` declares UserDefaults (reason CA92.1).

## Positioning

Dawnfold is installable on every iPhone, but it presents itself as a Duo app. There is no supported way to limit installs to the Duo (no device-capability key for the hinge), and Apple won't allow adding install restrictions in a later update. Regular iPhones are a supported "with a stand" mode.

- Lead every surface with the Duo: promotional text, the first lines of the description, and the first screenshots.
- Keep "iPhone Duo" out of the app name, subtitle and icon. Apple's trademark guidelines allow "for iPhone"-style references in the description, but not Apple trademarks in the app name. Check the current wording before submitting.
- On regular iPhones, onboarding says "Made for iPhone Duo".

## Screenshots

Lead with the Duo set: the half-folded sunrise is the hero shot. Regular-iPhone screenshots come after it.

From April 2027 iPhone Duo screenshots are required. `tools/screenshots.sh <simulator>` builds the app and captures the set into `screenshots/<simulator>/`, with the status bar at 9:41 and the in-app clocks set to match (9:41 PM at home, 6:43 AM mid-sunrise, 7:00 at wake):

1. Home
2. Sunrise in progress
3. Wake-up
4. Choose your sunrise
5. Night clock
6. Duo only: sunrise on the half-folded Duo (fold the simulator in DeviceHub first)

App Store Connect's main iPhone slot ("iPhone with Dynamic Island, medium display") takes 1206 × 2622, which an iPhone 17 simulator produces; Apple scales it to the other iPhone sizes. A 6.9" simulator (iPhone 18 Pro Max, 1320 × 2868) covers the large-display slot if you want custom shots there. The iPhone Duo slot needs the Duo simulator, which needs the iOS 27.1 simulator runtime.

## Before submitting

Done in App Store Connect (app ID 6825054414):
- [x] App record: Dawnfold: Sunrise Alarm, `app.dawnfold`, SKU dawnfold-ios
- [x] App information: subtitle, Lifestyle + Utilities, no third-party content, age rating 4+
- [x] App Privacy: privacy policy URL, "Data Not Collected", published
- [x] Price: free, available in all 175 countries or regions (EU needs the trader status below)
- [x] Dawnfold Pro: non-consumable `app.dawnfold.pro`, $3.99, Family Sharing on, all regions, display name and description, review screenshot and notes
- [x] Version 1.0: description, promotional text, keywords, support and marketing URLs, copyright, 5 screenshots, review notes, sign-in not required, manual release
- [x] Developer site: app IDs `app.dawnfold` (HomeKit, iCloud, App Groups, Push, IAP) and `app.dawnfold.widgets`, container `iCloud.app.dawnfold`, group `group.app.dawnfold`
- [x] Support site live at https://leejustin.github.io/firstlight/ (hello@leejustin.com)

Still to do:
- [ ] App Review contact: first and last name, phone number and email (Apple requires the phone number)
- [ ] EU trader status (Business › Digital Services Act), or the app won't be offered in the EU
- [ ] Sign in to Xcode (Settings › Accounts), then archive and upload a build; attach it and Dawnfold Pro to version 1.0
- [ ] Test in every posture in Device Hub (needs the iOS 27.1 simulator runtime), and on a regular iPhone
- [ ] Duo screenshots (required from April 2027)
- [ ] Try HomeKit lamps with a real color lamp and a white-only lamp
- [ ] Test the Pro purchase in the sandbox
- [ ] Run Light check on a real Duo for 30 minutes and record pillow lux
- [ ] Confirm on device that the flashlight works without a camera permission prompt
- [ ] Let a real overnight run with the backup alarm finish (close the app, confirm the backup rings)
