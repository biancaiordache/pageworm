# Pageworm

Pageworm is an iPhone app where you read to unlock the apps that eat your day. Inky, a bookworm, keeps the streak, the shield, and the guilt.

The blocking half uses Apple's Screen Time APIs (`FamilyControls`, `ManagedSettings`, `DeviceActivity`). Books, sessions, streaks, and forecasts stay on the phone in SwiftData. There is no backend in v1.

Core rules (CSV import, forecasts, streaks, unlock windows, tiers) live in `Packages/PagewormCore` and are tested with `swift test`. That package does not import UIKit, so it runs on Linux and on a Mac without the iOS SDK.

## Open the project

Requirements:

- Xcode 15.4 or newer (Xcode 16 is fine)
- iOS 17 or newer
- A paid Apple Developer account. Family Controls will not activate on a free personal team.
- A physical iPhone for shields, the report, and authorization. The Simulator can run onboarding, the library, the timer, forecasts, and the paywall UI. Screen Time authorization fails in the Simulator.

```bash
open Pageworm.xcodeproj
```

The first open resolves the RevenueCat Swift package (`purchases-ios` 5.103.1) and the three local packages. That needs a network connection.

Regenerate the Xcode project after adding source files:

```bash
make project
```

Run the core tests from a Mac or Linux machine with Swift 5.9+:

```bash
make test
```

## Signing

Pageworm is one app plus five extensions. Automatic signing is on. A development team is not set in the project, so Xcode will not build until you pick one.

1. Select the **Pageworm** target → **Signing & Capabilities** → Team.
2. Repeat for **ShieldConfiguration**, **ShieldAction**, **DeviceActivityMonitor**, **DeviceActivityReport**, and **PagewormWidget**.
3. Use the same team for every target. Extension bundle IDs must stay prefixed by the app id.

| Target | Bundle ID |
| --- | --- |
| Pageworm | `com.pageworm.app` |
| ShieldConfiguration | `com.pageworm.app.shield-configuration` |
| ShieldAction | `com.pageworm.app.shield-action` |
| DeviceActivityMonitor | `com.pageworm.app.monitor` |
| DeviceActivityReport | `com.pageworm.app.report` |
| PagewormWidget | `com.pageworm.app.widget` |

If `com.pageworm.app` is already taken, change **all six** bundle IDs together and keep the suffixes. The URL scheme `pageworm` is in `App/Info.plist`.

## App Group

Shared state (the shield copy, the widget, the blocked-app selection, the unlock deadline) is a file in an App Group. The id is `group.com.pageworm.shared`.

It is already in every entitlements file, and in `PagewormIDs.appGroup` inside `Packages/PagewormCore`.

1. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list/applicationGroup), register an App Group with that exact id.
2. On each of the six App IDs, enable **App Groups** and select `group.com.pageworm.shared`.
3. If you have to rename it, change the string in `PagewormIDs` and in all six `.entitlements` files. They have to match or the shield and the widget will look empty.

With automatic signing, toggling the capability in Xcode usually creates the portal record. Do it once on the app target, then confirm the other targets show the same group instead of a signing error.

## Family Controls entitlement

Distribution and development both need Apple to grant `com.apple.developer.family-controls`. The entitlement is already in the app and in the shield, action, monitor, and report extensions. The widget does not have it; it only reads the App Group.

Request it here: [Family Controls distribution request](https://developer.apple.com/contact/request/family-controls-distribution).

Ask for the individual authorization path (this is a self-blocker, not a parental-control app). Include every bundle ID that has the entitlement: the app, both shield extensions, the monitor, and the report. Approval is a manual review and can take a while.

Until the capability is on the App ID, device installs fail with a provisioning error about Family Controls. You can still compile. To run the rest of the app on a phone before approval, temporarily delete the `com.apple.developer.family-controls` key from the entitlements, run what you need, and put the key back before you test shields. The app already treats a denied or missing authorization as "not guarding yet" and lets onboarding finish.

The in-app request is `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.

## Extension targets

They are already created and embedded in the app target. Do not add them again.

| Target | Extension point | What it does |
| --- | --- | --- |
| ShieldConfiguration | `com.apple.ManagedSettingsUI.shield-configuration-service` | Draws Inky, the current book, and pages left in the chapter. Primary button says "Start reading". |
| ShieldAction | `com.apple.ManagedSettings.shield-action-service` | Closes the blocked app, stores a "please read" flag, and posts a notification that opens Pageworm. |
| DeviceActivityMonitor | `com.apple.deviceactivity.monitor-extension` | Applies the shield when the schedule starts and puts it back when an unlock window ends. |
| DeviceActivityReport | `com.apple.deviceactivityui.report-extension` | Turns this week's Screen Time into "4h back from TikTok is 118 pages". |
| PagewormWidget | WidgetKit | Home-screen widget (Inky, streak, current book) and the reading Live Activity. |

A shield extension cannot open its host app. "Start reading" dismisses the blocked app and relies on the notification (`pageworm://read`) or the next launch to present the timer. That is an Apple limitation, not a missing handler.

Device Activity schedules cannot be shorter than 15 minutes, so the earned unlock defaults to 15 and the choices are 15, 30, 45, and 60. The app also re-checks the deadline whenever it becomes active, because monitor callbacks are sometimes late.

## RevenueCat

The paywall is custom SwiftUI. It uses the `RevenueCat` product from `purchases-ios`. The key and the ids are in `App/Config/RevenueCatConfig.swift`.

```swift
static let apiKey = "appl_REPLACE_WITH_REVENUECAT_PUBLIC_SDK_KEY"
```

While that placeholder is in place, the SDK is not configured and the paywall will not charge anyone. "I'll stay on the free plan" still finishes onboarding.

In the RevenueCat dashboard:

1. Create an iOS app whose bundle ID is `com.pageworm.app` (or whatever you changed it to).
2. Create entitlement **`premium`**.
3. Create App Store products and attach them:
   - `pageworm_annual` — $39.99 per year, 7-day free trial
   - `pageworm_monthly` — $6.99 per month, no trial
4. Create offering **`default`** with the annual package. Use the standard package id `$rc_annual` and make this offering the current one.
5. Create offering **`downsell`** with the monthly package `$rc_monthly`. The monthly price is shown only after someone taps "Not now" on the annual trial.
6. Paste the **public** Apple SDK key into `RevenueCatConfig.apiKey`. Do not put a secret key in the app.

The paywall prefers the store's localized price when offerings load, and falls back to `$39.99` / `$6.99`. Terms and privacy links are `https://pageworm.app/terms` and `https://pageworm.app/privacy`. Replace those before App Review. The renewal disclosure is on the paywall.

A day-6 local notification is scheduled after a successful purchase ("Tomorrow the trial becomes a library card").

## What v1 does

Onboarding, in Inky's voice: welcome, name, why you're here, daily phone hours, which apps steal reading time, a reading-goal, the shock screen (years on the phone, then the books those years could have been), a playback in the person's own words, a hold-to-sign pledge, Screen Time priming and the authorization request, `FamilyActivityPicker`, a schedule, notification priming, then the annual trial paywall and the monthly downsell.

Blocking: a scheduled shield, a 15-minute (or longer) unlock after a qualified reading session, and strict mode with one hold-to-redeem emergency unlock per week. A session counts when it lasts at least five minutes and moves the page by at least one.

Reading: an in-app timer with a start page and an end page. Pages, minutes, and pages per hour are stored.

Library: Goodreads CSV (free) and StoryGraph CSV (Plus) through the Files picker, including `="978..."` ISBNs, blank ISBNs, and quoted commas or newlines. Manual add. Covers and page counts from the Open Library search API, then Google Books. No Goodreads API and no Kindle scraping.

Forecasts: hours, sessions, and a finish date from remaining pages and measured speed, plus a sooner date if one daily scroll hour is swapped in. The to-read shelf gets a "N days at your pace" countdown. A weekly Screen Time report converts hours to pages. Streaks have one freeze per week on Plus. Inky's stage is derived from finished books and the streak; moods are happy, sleepy, and missing you. Story cards render with `ImageRenderer` at 1080×1920 and share through `ShareLink`.

Free: one blocked app, Goodreads import, the base finish forecast, the timer, manual add, and moods. Plus: every additional app, categories and websites, StoryGraph import, custom unlock length, strict mode, the weekly scroll report, the streak freeze, Inky's later stages, share cards, the widget, the Live Activity, the swapped-hour date, and the shelf countdown.

## Layout

```
App/                         SwiftUI app, SwiftData models, Screen Time coordinator
Extensions/                  Shield, monitor, report, widget
Shared/Blocking/             Shield apply/clear, compiled into the app and the monitor
Packages/PagewormCore/       Rules and tests
Packages/PagewormDesign/     Palette, InkyView, App Group file store
Packages/PagewormActivity/   Live Activity attributes shared by the app and the widget
```

Inky is drawn with SwiftUI shapes in `InkyView`. Replace that view when real art exists. Call sites only pass stage, mood, and size. The shield renders the same view to a `UIImage`.

Imported "read" books are kept on the Finished shelf and do **not** count toward Inky's growth. Books finished inside Pageworm do.

Chapter boundaries are estimated. The default chapter is 20 pages (`ChapterMath`), editable per book. Open Library does not give a table of contents.

## What is not in v1

- A server, accounts, or iCloud sync
- Real Inky illustration files (the icon is a generated placeholder)
- A configured RevenueCat project or App Store products
- Family Controls, until Apple grants the entitlement
- A shield that can launch Pageworm by itself
- Guaranteed on-time monitor callbacks (the app reconciles on foreground)
- Real per-chapter data
- Kindle or Goodreads API access
