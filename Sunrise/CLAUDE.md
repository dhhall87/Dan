# CLAUDE.md - Sunrise

Native iPhone app that fades Dan's lights in before he wakes, like a Hue/Nanoleaf sunrise: very dim amber → warm gold → soft daylight, reaching full brightness at a set time or at the local sunrise. Dan's lights are Nanoleaf Essentials bulbs in Apple Home. He wears an Oura ring to bed, and doesn't sleep with his Apple Watch on.

Sunrise is a separate app in the same repository as Passing (folder `Sunrise/`, its own `Sunrise/Sunrise.xcodeproj`). The root `CLAUDE.md` is Passing's; its "How to work in this repo" rules apply here too: small milestones with a manual test checklist for Dan, then stop; explain decisions briefly; don't invent APIs (check Apple's docs, `developer.apple.com/tutorials/data/documentation/<framework>/<symbol>.json` works from this environment); no placeholders passed off as finished; native frameworks only; keep the build warning-free.

## Versions

Started at 1.0 (build 1). Same rule as Passing: every push that changes the app steps `MARKETING_VERSION` (1.0.1, 1.0.2, …) and `CURRENT_PROJECT_VERSION` (+1) in all four target configurations in `Sunrise.xcodeproj/project.pbxproj` (app and tests, Debug and Release). Tell Dan the new number. Passing's version doesn't change for Sunrise-only pushes.

## Stack

Swift 5 language mode, SwiftUI, Observation (`@Observable`), HomeKit, Core Location, Swift Testing. iOS 26.0 deployment target (AlarmKit, planned for Milestone 2, needs it). iPhone only, portrait, dark appearance (`UIUserInterfaceStyle` Dark in `Support/Info.plist`). Signing: team `8SS7RZ89R8` set at project level and inherited (like Passing); bundle IDs `com.danhall.sunrise` and `com.danhall.sunrise.tests`. HomeKit entitlement in `Support/Sunrise.entitlements` (available on free developer accounts, checked October 2026). Privacy strings live in `Support/Info.plist` (not `INFOPLIST_KEY_` settings) so a missing key can't crash HomeKit on first use. No third-party dependencies, no accounts, no network beyond Apple's.

## How it works (the key decision)

An iOS app can't run at 6:30 AM in the background to ramp lights, so the sunrise lives in Apple Home and the **home hub** runs it:

- `HomeSchedule.install` writes one `HMActionSet` (scene) of `HMCharacteristicWriteAction`s plus one `HMEventTrigger` (automation) per step. Fixed time: `HMCalendarEvent(fire: DateComponents(hour:minute:))`. At sunrise: `HMSignificantTimeEvent(significantEvent: .sunrise, offset:)` (negative hours/minutes, `SunriseSchedule.sunriseOffset`), so the hub tracks the seasons itself. Days go in `recurrences` (weekday-only `DateComponents`); a fixed-time step before midnight shifts its days back one (`ClockTime.dayShift`).
- A trigger can only be enabled once it's in the home with an action set that has actions (Apple's `enable` docs), so the order is: add scene → add actions → add trigger → attach scene → enable.
- **Prep step** (`SunriseCurve.prepOffset`, a minute before the start, `turnsOn = false`): Apple's docs say a scene's actions run in no set order, so a scene that powers on and dims can flash the old brightness. Every real step turns the light on (robustness over "stays off if Dan turns it off"; revisit if he asks).
- Names: `SunriseStep.name` = "Sunrise App Step 00"… Saves remove everything Sunrise recorded (`HomeInstall`, in UserDefaults) **and** anything with that name pattern (`HomeSchedule.isSunriseName`), then build fresh. A failed build is rolled back. `HomeSchedule.state` reports `.damaged` for missing/disabled steps or unrecorded leftovers.
- At most 16 steps (`SunriseCurve.maxIntervals` = 15 gaps): each step is a visible scene and automation in the Home app, and every save is a few hundred HomeKit round trips through the hub.
- HomeKit never tells an app about its own changes, so `HomeStore.refresh()` runs after every change Sunrise makes, and `revision` tells views to re-read HomeKit's in-place objects.
- HomeKit permission is asked only when Dan taps Connect to Home (`HomeStore.connect`); later launches connect at once. The app shows a plain view under XCTest so tests never create an `HMHomeManager`.

## Curve and colors (pure, tested)

- `SunriseCurve`: offsets (whole minutes, `-duration…0`, spread over at most 15 gaps), brightness `1 + (final − 1)·p²`, color linear in mireds from 1,500 K to the final white (2,700–6,500 K, default 4,000).
- `LightWrites`: per light, brightness (never below 1), then color, then power. White tuning when the bulb can make that white (mireds ≤ its warmest), otherwise hue/saturation from `ColorMath` (Tanner Helland blackbody fit → HSV) on color bulbs, otherwise the warmest white. Values use the characteristic's type (Bool / Int / Double).
- `SolarCalculator`: NOAA equations; within ~1 min of the astral Python library everywhere tested except the far north in summer (72 s at Reykjavík in June). Used only for showing times (and for Milestone 2's alarm); the lights use the hub's own sunrise.
- Location is asked only from "Show sunrise times here", once, rounded to ~1 km (`SavedPlace`), and kept apart from `SunriseSettings` because it never changes Home.

## Files

- `Sunrise/Model/`: `SunriseSettings` (+ `SunriseStep`, `HomeInstall`, `SavedPlace`; hand-written decoding with defaults so new fields stay additive), `SunriseCurve` (+ `ColorMath`), `LightWrites`, `SunriseSchedule`, `SolarCalculator`, `Weekday`.
- `Sunrise/Services/`: `HomeStore` (the one `HMHomeManager`), `HomeLights` (dimmable lightbulb services → `LightOption`/`LightTarget`), `HomeSchedule` (writes Home), `SunrisePreview` ("Try it now", ~45 s, written straight to the characteristics while the app is open), `LocationService`, `SunriseModel` (screen state, every Home change).
- `Sunrise/Views/`: `ContentView`, `PreviewCard`, `WakeCard`, `LightCard`, `LightsCard`, `HomeCard`, `ConnectCard`, `Theme` (background, `card()`, `SunriseStrip`).
- `SunriseTests/`: Swift Testing for everything pure.
- This environment can't build iOS or run Swift (download.swift.org is blocked); the curve and sunrise math were checked in Python (`astral`) before writing the tests. Dan builds and runs ⌘U.

## Milestones

1. **Lights sunrise** (built October 30, 2026 as 1.0 (1); waiting for Dan's test run, README "Milestone 1 manual test checklist"): connect to Home, pick lights, set time or sunrise, length, final brightness, colors, days; save to Home; on/off; update; remove; Try it now.
2. **Alarm (AlarmKit).** `AlarmManager.shared.schedule(id:configuration:)`; `NSAlarmKitUsageDescription` required; `Alarm.Schedule.relative(.init(time:repeats: .weekly([Locale.Weekday])))` for set times; for sunrise mode, fixed-date alarms for the coming days from `SolarCalculator`, refreshed when the app opens. Snooze (secondary button `.countdown` with `postAlert`) needs a widget extension with a Live Activity, or alarms may be dismissed unexpectedly (Apple's AlarmKit article). Alarms sound through Silent and Focus.
3. Maybe: "at sunrise but not before X" (`HMEventTrigger` predicates), lights off after the wake time, several sunrises.

**Declined for now (October 2026), with reasons given to Dan in the README:** sleep-stage wake from Oura (no live data; stages are computed after waking, and Health gets them only on sync) or from the microphone (needs the phone running all night by the bed with the mic on, can't be validated here, and changing Home from the background is unconfirmed). A "restless in the last minutes → wake now" experiment could pair with the alarm later if Dan wants it.

## Risks to verify on Dan's devices

- Nanoleaf Essentials' behavior when brightness is written while off (prep step), and whether hue/saturation → white tuning hand-over looks smooth.
- Whether writing color turns off Adaptive Lighting on those bulbs (expected; Sunrise colors off avoids it).
- Whether HomeKit accepts a 61-minute sunrise offset (60-minute sunrise in sunrise mode).
- The hub's sunrise vs the phone's computed time (should be within a minute or two).
