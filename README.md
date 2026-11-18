# Pageworm

Pageworm is an iPhone app where you read to unlock the apps that eat the day. Inky, a bookworm, keeps the door. A finished reading session opens the blocked apps for a short window. When the window ends, the shield comes back.

The app is SwiftUI, iOS 17+, with SwiftData on the phone and no backend. The rules that have to be right — CSV import, finish dates, streaks, unlock windows — live in `Packages/PagewormCore` and are tested with `swift test`.

Inky is drawn with SwiftUI shapes in `Shared/InkyView.swift`. Replace that view's body when real art exists. Call sites take a stage and a mood, so they can stay put. The shield uses a small UIKit drawing of the same worm in `Extensions/ShieldConfiguration`.

## Open the project

Xcode 16 or newer. Open `Pageworm.xcodeproj`. The first launch resolves two Swift packages: local `PagewormCore`, and [RevenueCat](https://github.com/RevenueCat/purchases-ios-spm.git) (`purchases-ios` 5.x, product `RevenueCat`). Wait for that resolution before building.

Screen Time does not work in the Simulator. Build to a physical iPhone for blocking. The rest of the app, including onboarding up to the Apple prompt, runs in the Simulator. If the Screen Time request fails, onboarding lets you continue.

Core tests, from a Mac or Linux:

```sh
cd Packages/PagewormCore
swift test
```

## Signing

1. Select the Pageworm project, then each target, and set your Team under Signing & Capabilities. Automatic signing is already on.
2. Change the bundle identifiers if `com.pageworm.app` is not yours. Keep the suffixes, and use the same prefix everywhere:

| Target | Bundle ID | Role |
| --- | --- | --- |
| Pageworm | `com.pageworm.app` | App |
| PagewormShieldConfiguration | `com.pageworm.app.ShieldConfiguration` | Shield look |
| PagewormShieldAction | `com.pageworm.app.ShieldAction` | Shield buttons |
| PagewormDeviceActivityMonitor | `com.pageworm.app.DeviceActivityMonitor` | Schedule start/end, re-lock |
| PagewormDeviceActivityReport | `com.pageworm.app.DeviceActivityReport` | Weekly scroll report |
| PagewormWidgets | `com.pageworm.app.Widgets` | Home Screen widget and Live Activity |

The app target embeds the five extensions. Do not delete a target to get a quicker build. Blocking, the report, the widget, and the Live Activity each need theirs.

## App Group

The shared identifier is `group.com.pageworm.shared`.

1. In the Apple Developer portal, register an App Group with that exact identifier.
2. On every target, add the App Groups capability and select that group. The entitlements files already request it: `Config/Entitlements/Pageworm.entitlements` for the app and the Screen Time extensions, and `Config/Entitlements/Widget.entitlements` for the widget.
3. If you rename the group, change `SharedKeys.appGroupID` in `Packages/PagewormCore/Sources/PagewormCore/SharedKeys.swift` to the same string. Shields, the widget, and the report all read the book title and the unlock window from this container.

## Family Controls

`com.apple.developer.family-controls` is in `Config/Entitlements/Pageworm.entitlements`, which is used by the app, both shield extensions, the Device Activity monitor, and the Device Activity report. The widget does not need it.

Development on your own phone often works once the Family Controls capability is on the App IDs. Distribution does not. Apple approves Family Controls (Distribution) per team:

1. For each of the five bundle IDs that use the entitlement (app + four Screen Time extensions, not the widget), enable Family Controls in Certificates, Identifiers & Profiles.
2. Request the distribution entitlement from Apple: [Family Controls](https://developer.apple.com/contact/request/family-controls-distribution) (or the current form under Account → Services). Approval is separate from the capability checkbox. Until it lands, TestFlight and App Store builds fail at upload even when a device build succeeds.
3. Add the Family Controls capability in Xcode on those same five targets so the provisioning profiles include the entitlement. The entitlements file is already wired up.

The authorization call is `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.

## Extension points

These are already set in `Config/Info`. They are easy to mistype, and a wrong value fails App Store validation.

| Extension | `NSExtensionPointIdentifier` |
| --- | --- |
| Shield configuration | `com.apple.ManagedSettingsUI.shield-configuration-service` |
| Shield action | `com.apple.ManagedSettings.shield-action-service` |
| Device Activity monitor | `com.apple.deviceactivity.monitor-extension` |
| Device Activity report | `com.apple.deviceactivityui.report-extension` |
| Widget | `com.apple.widgetkit-extension` |

Shield configuration, shield action, and the monitor name a principal class with `$(PRODUCT_MODULE_NAME)`. The report and the widget use `@main`.

## Names

The App Store listing is **Pageworm: Read More** (Apple ID 6836330820). The name under the icon is `CFBundleDisplayName`: **Pageworm**. That display name is set on every target and again in `Config/Info/Pageworm-Info.plist`. Leave it as Pageworm when the store name is edited in App Store Connect.

## RevenueCat

The public iOS SDK key is in `Pageworm/Purchases/RevenueCatConfig.swift`. It is a client key. The secret key stays in the RevenueCat dashboard.

The app looks up:

| | |
| --- | --- |
| Entitlement | `premium` |
| Offering | `default` (falls back to the current offering) |
| Packages | `$rc_annual`, `$rc_monthly` |
| Products | `pageworm_annual` ($39.99/year, 7-day trial), `pageworm_monthly` ($6.99/month) |

A package match tries the `$rc_` identifier first, then the App Store product id, then the annual or monthly package type.

The annual paywall is three pages: what Plus includes, a day 1 / day 6 / day 7 trial timeline, then the price. Declining it reveals the monthly plan only. Restore sits on both.

## What the free plan includes

One blocked app, Goodreads CSV import, and the finish forecast. Plus is everything else: more apps and categories, StoryGraph import, strict mode and the weekly emergency unlock, a custom unlock length, the streak freeze, Inky's later stages, the shelf countdown, the weekly scroll report, story wraps, the Home Screen widget's full face, and the reading Live Activity. Streaks are still counted on the free plan. The freeze and the grown-up worm are not.

Unlocks are 15, 30, 45, or 60 minutes. Fifteen is the floor because Device Activity rejects a schedule shorter than that. A session has to last at least a minute before it opens the door.

## How blocking is wired

- The app stores the `FamilyActivitySelection` and a `ShieldSnapshot` (current book, pages to the next chapter, mood, streak, schedule, unlock deadline) in the App Group.
- A reading session is a start page, a running timer, and an end page. Pages, minutes, and pages per hour are saved in SwiftData. The measured speed is total pages over total time.
- Finishing a long-enough session clears the shield and starts a one-shot Device Activity schedule for the unlock window. When that interval ends, the monitor extension puts the shield back if the weekly schedule is still active.
- Strict mode keeps you from switching blocking off without holding to confirm. The emergency unlock is one hold per calendar week, Monday-based.
- The shield's Start reading button cannot open Pageworm. iOS does not let a shield extension foreground the host app. The button closes the blocked app and sets a pending-launch flag. If Pageworm is already running it notices. The next time you open Pageworm, it goes to the timer. The shield copy says to open Pageworm.
- Chapter breaks are estimated. `pagesPerChapter` defaults to 15. Open Library and Google Books do not give a table of contents.

## Library

Goodreads and StoryGraph exports come in through the Files picker. The parser handles `="978..."`, blank ISBNs, and quotes that contain commas or newlines. Shelves shown are Currently reading, To read, and Read. Covers and page counts come from the Open Library API, then Google Books if something is still missing. There is no Goodreads API and no Kindle scraping. Books you mark finished inside Pageworm are what grow Inky. A Goodreads "read" shelf does not.

## Inky

Stages, from streaks or finished books: Bookling, Page Nibbler (3 days or 1 book), Chapter Chomper (7 or 3), Novel Nommer (21 or 8), Library Legend (60 or 20). Moods are happy, sleepy (just finished a sitting, or late and unread), missing you (no session for 36 hours), and cheering (a book finished in the last 12 hours). One missed day each week can be a streak freeze on Plus. Today never burns the freeze.

Story cards are 360×640 points at 3×, rendered with `ImageRenderer` and shared with `ShareLink`.

## Project map

```
Pageworm.xcodeproj
Pageworm/                 app, SwiftData, onboarding, paywall
Shared/                   Inky, colors, Live Activity attributes
ScreenTimeShared/         selection codec and shield apply/clear
Extensions/               shield, monitor, report, widget
Packages/PagewormCore/    rules and unit tests
Config/                   Info.plists and entitlements
```

`scripts/generate_xcodeproj.py` rewrites the Xcode project if you add a target. You do not need it to build.
