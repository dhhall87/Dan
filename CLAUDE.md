# CLAUDE.md - Passing (working name)

Native iPhone app for capturing things you pass while driving so you can look them up later. Capture takes one action. Identifying the thing happens later, or hands-free through Siri.

**Safety is the core requirement.** A capture must never depend on typing, reading, answering a question, or looking at a confirmation.

---

## How to work in this repo

- Dan created the Xcode project in Xcode (App template, SwiftUI, SwiftData). Xcode 16+ uses folder-synced groups, so new Swift files written to disk join the target automatically. Anything that needs Xcode's UI (adding targets, capabilities, App Groups, signing) gets exact click-by-click steps for Dan.
- Build in small milestones (see below). Finish one milestone, build with `xcodebuild`, run tests, then stop and give Dan a short manual test checklist. Don't start the next milestone until he confirms.
- Dan is an intermediate vibe coder. Explain important decisions in a sentence or two, recommend a default when there's a trade-off, and move on.
- Don't invent APIs. If you're unsure an API exists or behaves a certain way on the deployment target, say so and check Apple's docs before relying on it.
- Never ship a placeholder or stub as if it were finished. Call it out.
- Prefer native frameworks. No third-party dependencies without asking.
- Dan tests while parked, not while driving.

## Stack

- Swift, SwiftUI, SwiftData, Core Location, MapKit, App Intents, WidgetKit
- Deployment target: iOS 26 (CarPlay widget support requires it). Built with Xcode 27 and tuned for iOS 27 on Dan's iPhone 16 Pro (402 × 874 points). Raising the target to 27 would lock out iPhones still on iOS 26, and nothing needs it yet.
- No accounts, backend, analytics, subscriptions, or paid map APIs. All data stays on device.
- Network is only used for map tiles, reverse geocoding, and Look Around, and capture never waits on it.

## Architecture

- **CaptureService** - the single entry point that saves a pin. The phone UI, Siri intent, Control Center control, Action Button, widget buttons, and any future CarPlay UI all call this. Never duplicate save logic.
- **LocationProvider** - supplies a fresh fix. Defines max fix age and accuracy thresholds. Never returns a stale coordinate as current.
- **BreadcrumbBuffer** - rolling in-memory trail of recent positions while the app is foregrounded (powers "miles back").
- **RetentionService** - expiry, Recently Deleted, purge.
- **Shared store** - the SwiftData store lives in an App Group container so the app, intents, and widget extension read and write the same data.

## Data model: Pin

| Field | Notes |
|---|---|
| id | UUID |
| capturedAt | when the user acted |
| fixTimestamp | when the GPS fix was taken (can differ from capturedAt) |
| latitude, longitude | actual capture coordinates, never overwritten (rounded to ~1 km as the pin is saved when the "Precise location" setting is off) |
| horizontalAccuracy | meters |
| course, courseReliable | degrees; false when speed is too low for course to mean anything |
| speed | m/s; not stored with "Precise location" off, and never exported |
| side | left / right / unknown |
| distance | near / far / unknown |
| milesBack | Double, default 0 |
| targetLatitude, targetLongitude | optional estimated location of the thing itself |
| targetSource | direct / breadcrumb / textOnly |
| trail | optional encoded breadcrumb segment for miles-back pins |
| label | optional, spoken or typed |
| placeName | optional, reverse geocoded town/area, filled lazily |
| source | app / siri / widget / control / actionButton |
| isReviewed, isKept | Bool |
| deletedAt | nil unless in Recently Deleted |

Keep capture coordinates and target coordinates separate. The app records where the car was plus the driver's directional clue. It never claims to know where the building actually is.

## Capture behavior

- **Save first.** A tap writes the pin immediately. Labels are always optional and added after.
- While the capture screen is open, location updates run (When In Use), so the latest fix is already fresh at tap time. For captures from Siri or the widget, request a one-shot fix and record `fixTimestamp`. At highway speed a 3-second-old fix is ~90 m off, so flag a pin as approximate when the car could have moved more than ~50 m between the fix and the tap (speed × time apart), combined with the fix's own accuracy (square root of the sum of the squares). A parked car's older fix stays exact. If the fix has no speed, fall back to flagging fixes more than 3 s from the tap.
- If no usable fix arrives, still save the pin with the timestamp and a clear "no location" state. Never substitute an old coordinate.
- **Confirmation is non-visual:** haptic plus a short tone. Optional spoken confirmation ("Left, far, saved") as a setting. No alerts, sheets, or navigation changes on the capture screen.
- Debounce repeat taps on the same zone within ~0.75 s.
- Keep the screen awake while the capture screen is showing.

## Main screen

Dark, high contrast, no map, no clutter. Settings picks the layout Passing opens with. At Dan's request the two-line title ("Passing" over "Simple" or "Four zones") is also a button that switches layout for the drive; coming back after more than 30 minutes away starts on the Settings layout again (`CaptureModeChoice`). A GPS pill in the title bar, above the title, says whether a tap now gets a position (GPS ready / Finding GPS… / Location off / Precise Location off). It's a standing notice, never a reaction to a tap. The rest of the app follows Settings → Appearance (System by default, or Light/Dark); the capture screen stays dark in every appearance.

**Simple mode (default; stored as `quick`):** the entire screen is one capture button, labeled "Pin it".

**Look (option A, chosen October 2026):** colors from the app icon (`Shared/Views/PassingColors.swift`), the icon's pin on the Simple button and the Pin widget (`PinGlyph`), rounded type. Capture buttons are solid colors, not Liquid Glass, so iOS 27's glass slider can't fade them. Glass is only on the system title-bar buttons and the GPS pill.

**Four-zone mode:** four full-height vertical columns, laid out left to right exactly as the road looks:

```
| Far Left | Near Left | [car] | Near Right | Far Right |
```

- Near zones sit next to the car; far zones are on the outer edges. The layout must be spatially literal so it works without reading labels. Do not use a 2x2 grid or stack left zones above right zones.
- Near and far zones use two distinct colors, mirrored on both sides.
- The center divider is narrow and drawn as the road with the car on it. Tapping it saves a pin with side unknown.

**"+1 mi back" button** (bottom strip, both modes):
- One action. A tap creates a pin placed 1 mile back along the breadcrumb trail.
- Tapping again within ~4 s bumps that same pin to 2 mi, 3 mi, and so on, with tone/haptic per step (and spoken "2 miles back" if spoken confirmation is on).
- No separate "pending offset" state that requires a second tap somewhere else. Side defaults to unknown and is editable in review.

## Voice confirmation options

- Spoken confirmation stays optional and off by default.
- When Passing speaks, other audio (music, podcasts) pauses and resumes afterwards, rather than playing underneath. A setting switches this to lowering the volume instead. The short tone always mixes with music.
- **Voice picker:** choose from the voices installed on the phone (`AVSpeechSynthesisVoice.speechVoices()`), labeled by quality (Default / Enhanced / Premium), with a preview button. The default is "Best available": the most natural voice installed for the phone's language (Premium, then Enhanced, then the system default; never novelty or Personal Voice unless chosen), re-picked when voices are downloaded. Siri voices aren't available to third-party apps, and no voice files are bundled. Better voices are free downloads in iOS Settings → Accessibility → Spoken Content → Voices, and the app explains how to get them. Refresh the list when installed voices change. Optionally offer the user's Personal Voice, with their permission.
- **Custom phrases:** Dan can type his own confirmation phrases ("Location saved", "Got it boss", "I'll look this up later", "Writing this down for you now"). One is picked at random per capture. Option to say the side/distance first ("Left, far. Got it boss."). Keep phrases short (about 60 characters max) so confirmations stay brief, and add a preview button. Miles-back bumps still say the number ("2 miles back").

## Miles back

- While the app is foregrounded, keep a rolling in-memory trail of the last ~25 miles, sampled roughly every 50 m. This is not persisted and not background tracking.
- On a miles-back capture, walk backward along the trail by N miles (cumulative haversine distance) to get the target coordinate. Store both capture point and target, `targetSource = breadcrumb`, and attach the trail segment so the review screen can show it.
- If the trail is shorter than N (app just opened), leave target nil, set `targetSource = textOnly`, and keep milesBack plus course so review can say "about 2 mi back, heading southwest from here."
- v1 uses When In Use authorization only. No Always permission, no background location.

## Siri and system triggers

- **CapturePinIntent** (AppIntent) with optional parameters: label, side, distance, milesBack.
- In `perform()`: capture and save the pin first. Then, if label is nil, ask with the parameter's `requestValue` ("What did you see?"). On an answer, update the pin. On cancel, timeout, or error, keep the pin unlabeled. A failed or skipped label must never lose the pin. Verify this flow in the simulator and through CarPlay.
- **AppShortcutsProvider** phrases. App Shortcut phrases must include the app name, so the final app name should sound natural spoken aloud ("Pin that in Passing", "Mark this in Passing").
- The same intent powers a Control Center control (ControlWidget), the Action Button, and Back Tap via Shortcuts.
- **QuickPinIntent** saves without asking anything. Use it for the Action Button, Back Tap and Control Center: outside Siri, a `requestValue` question appears on screen and needs typing, which breaks the safety rules. It calls the same CaptureService path.
- Runs without opening the app.

## Widget (CarPlay path, no entitlement needed)

- WidgetKit `systemSmall` widget with `Button(intent:)` calling the capture intent. iOS 26 shows small widgets in CarPlay, and buttons work on touchscreen cars without a CarPlay app.
- Two variants: a single "Pin" button, and a 2x2 side/distance grid (match the left/right logic of the phone layout).
- Widget captures are silent (no voice prompt). Labels get added later.
- Native CarPlay template app is out of scope unless Dan decides to publish. It would need the Driving Task entitlement from Apple, approval isn't guaranteed, and it would be limited to templates (grid of buttons, not the custom layout).

## Review screen

- List grouped by day, plus a map view. Each row: time, label or "Unlabeled", side/distance, miles back, place name, accuracy, "expires in X days".
- Detail: map with capture point, target, and trail if present; Look Around preview at the target (or capture point); edit label/side/distance; mark reviewed; keep (star); delete.
- Map links use the target if present, otherwise capture point:
  - Apple: `https://maps.apple.com/?ll=LAT,LON&q=LABEL`
  - Google: `https://www.google.com/maps/search/?api=1&query=LAT,LON`
- Reverse geocode lazily when online to fill `placeName` (answers "what town was that" automatically).
- Export JSON and CSV through the share sheet.
- **Groups (folders):** Dan can put pins into named groups in the review list (e.g. "Road trip", "Houses to check") and filter by group. A pin belongs to at most one group. Deleting a group never deletes its pins.
- **"Passing pins" collection in a maps app:** Apple Maps has no public API for creating Guides or adding places to them (checked October 2026), so the app can't fill an Apple Maps Guide automatically. Instead, export a KML file that Google My Maps imports as a "Passing pins" map, and keep "Open in Apple Maps" on each pin so it can be added to a Guide by hand. Revisit if Apple adds an API.
- Optional (later): in-app "listen after tap" setting - chime, listen a few seconds with on-device speech recognition, save silently if nothing is said.

## Retention

- Active pins expire 7 days after `capturedAt` (rolling, per pin), unless the pin is kept (star) or the global "Keep records indefinitely" setting is on.
- Expired pins and manually deleted pins move to **Recently Deleted** (set `deletedAt`). From there: Recover, or Delete Now.
- Recently Deleted purges permanently 30 days after `deletedAt`. "Keep records indefinitely" stops auto-expiry of active pins; it does not stop the 30-day purge of things already in Recently Deleted.
- Run retention on launch and whenever the scene becomes active; also schedule an opportunistic background refresh. Never depend on exact timing.
- Use absolute time intervals, not calendar days, so time zones and DST don't shift boundaries.
- Don't run retention while an export is in progress.
- Tests: exactly 7 days, just under/over, 30-day purge, kept pin, keep-forever on, app closed for 10+ days then opened.

## Privacy

- When In Use location only, requested when the user first captures, with a clear purpose string.
- No analytics. No location data leaves the device except map, geocoding, and Look Around requests to Apple.

## Milestones

1. **Core capture.** Quick and four-zone modes, CaptureService, LocationProvider with freshness rules, App Group SwiftData store with the full Pin model, review list and detail with map links, haptic/tone confirmation, screen stays awake.
2. **Retention.** 7-day rolling expiry, keep star, keep-forever setting, Recently Deleted with 30-day purge, export, tests.
3. **Miles back and voice options.** BreadcrumbBuffer, +1 mi back button with bump-on-repeat, target estimation, trail on review map. Voice picker and custom confirmation phrases.
4. **Siri.** CapturePinIntent with save-then-ask label flow, Quick Pin (never asks), App Shortcuts, Action Button and Back Tap setup, spoken confirmations pause other audio. The Control Center control moves to Milestone 5, because it needs the same widget extension target as the widget.
5. **Widget / CarPlay.** Widget extension with the systemSmall widget (single and 2x2) and the Control Center control, tested in the CarPlay Simulator.
6. **Review polish.** Look Around, reverse geocoding, pin groups (folders), KML export for a Google My Maps "Passing pins" map, and the all-pins map view from the review screen spec.
7. **Listen after tap (optional).** Split out of Milestone 6: it's the only remaining piece that changes capture, and it needs microphone and speech-recognition permission.

Later / maybe: native CarPlay app (only if publishing).

### Milestone 1 acceptance

- One tap saves a pin without requiring a label.
- Each of the four zones saves the correct side and distance.
- Coordinates and accuracy are visible and plausible.
- Apple and Google Maps links open the right spot.
- Pins persist after the app is closed and reopened.
- Denied or failed GPS never saves an old position as current.
- Capture and review work with no network (apart from map tiles).

## Risks to verify, not assume

- Whether the intent can get a fresh location when invoked from Siri, the widget, or Control Center with the app not in the foreground under When In Use authorization. If not, propose the smallest fix and explain the trade-off.
- Which process the widget's intent runs in, and whether that process can use Core Location.
- `requestValue` behavior and cancel handling inside `perform()`, especially through CarPlay Siri.
- Widget button behavior in the CarPlay Simulator.

## Safety rules (non-negotiable)

- Capture never requires reading, typing, or answering.
- Nothing pops up or changes screens on the capture screen after a tap.
  - One exception, at Dan's request: with listen-after-tap on, a "Stop listening" button replaces the GPS pill in the title bar while Passing asks or listens. It never moves or covers the capture buttons, and listening ends by itself, so it never has to be pressed.
- Every voice prompt is optional and can be turned off.

## Current status

- Milestones 1–7 are done (Milestone 5 confirmed in the Simulator, including its CarPlay window; Dan ran 7 and its follow-ups without issues). Work happens on branch `claude/road-marker-pin-app-flj2qm`.
- **Design refresh (option A) is built and waiting for Dan's test run** (README, "Design refresh checklist"). Notes:
  - Checked against WWDC26 "What's new in SwiftUI": iPhone apps can be resized on iOS 27 (so the capture layout stays flexible, and the Simple pin shrinks first), the new Liquid Glass slider changes glass tint (so capture buttons stay solid), and `@State` is now a macro (a default value plus an assignment in `init` is an error; there are none here). `confirmationDialog(_:item:)` and `alert(_:item:)` are iOS 27-only, so the iOS 26 forms stay.
  - `Text + Text` is deprecated in the iOS 26 SDK; use separate `Text` views or interpolation.
- Notes from Milestone 7:
  - Listen-after-tap uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition` (not deprecated in iOS 26; simpler than `SpeechAnalyzer`). On iPhone it's on-device only, and the setting stays off if the language isn't supported on device. In the Simulator only, it may fall back to server recognition so the feature can be tried.
  - `CaptureFeedback` owns the whole flow: a `.playAndRecord` session (pausing or ducking other audio per the existing setting), the chime, `SpeechListener.listen()`, then `CaptureService.setLabel`. Only `.app` taps listen. Permission is requested only from Settings.
  - The audio-thread and Speech callbacks are built in `nonisolated` helpers, so they never run as main-actor closures on other threads.
  - Follow-ups Dan asked for: Passing asks "What are you passing?" (spoken, can be switched to a chime) before listening; "stop"/"cancel" end listening after a 0.6 s grace; a Stop listening button in the capture screen's title bar; while listening, the widgets show a Stop button (`StopListeningIntent` posts a Darwin notification the app observes via `ListeningSignal`, and the app reloads widget timelines when listening starts and ends); multi-select (Keep, Reviewed, Group, Delete) on the Pins list.
- Notes from Milestone 6:
  - Town names use iOS 26's `MKReverseGeocodingRequest` (`try await request.mapItems`, `addressRepresentations.cityWithContext`), and Look Around uses `MKLookAroundSceneRequest(...).scene`. Both async forms come from Apple's own examples rather than the reference pages, which only list the completion-handler methods. If either doesn't compile, switch to `getMapItems(completionHandler:)` / `getSceneWithCompletionHandler(_:)`.
  - Groups added `PinGroup` and `Pin.group` (lightweight migration). `SharedStore` now tries the App Group store three times, 0.5 s apart, before falling back, in case the app and widget open it mid-migration.
- Notes from Milestone 5:
  - The widget extension target (`PassingWidgetExtension`, folder `PassingWidget/`) was added to the hand-written `project.pbxproj` directly instead of through Xcode's New Target wizard. The wizard would have needed a round trip and several manual file moves, and the project file was hand-written to begin with.
  - Code used by both targets lives in `Shared/` (a synced folder in both targets). `CaptureService.shared` is defined per target: `Passing/Services/CaptureService+App.swift` and `PassingWidget/CaptureService+Widget.swift`. Siri intents and `PassingShortcuts` stay app-only, so the system never runs them in the extension (`allowedExecutionTargets` is iOS 27+, so it can't be used to pin them).
  - Per Apple's docs, widget buttons and controls run their intent in the widget extension. Widgets get location through `NSWidgetWantsLocation` ("While Using the App or Widgets"). Still unverified: whether CarPlay widget buttons work with the iPhone locked, and location from the widget in a real car (only testable in a car).
  - This environment can't build iOS. Pure-logic tests run on Linux through a scratch SwiftPM package; Dan runs ⌘U in Xcode.
- **Schema changes:** after an update, the app and the widget extension can both open the store at once and both try the migration. `SharedStore` retries, then falls back to a private store, which would hide pins (in the widget, silently). Keep model changes additive (new optional fields, new models) so migrations stay lightweight.
- **Keep the build warning-free** (Dan asked). Two Swift 6 warnings have come up: a `Sendable` conformance declared outside the type's own file, and a one-line `Task { … }` whose last call returns a non-Sendable value (it becomes the task's result; write `_ =`). When Xcode offers "Update to recommended settings", Dan sends the list and the settings get written into `project.pbxproj` here.
- **Privacy settings Dan chose (October 2026):** "Precise location" (on by default; off rounds each pin to ~1 km via `Pin.coarsenLocation()` at save, drops speed and the route, keeps the compass direction; stored in App Group defaults via `LocationPrivacy` so the widget follows it). "Delete pins after exporting" (off by default; only after a completed share; kept pins stay). "Delete All Pins" in Settings (permanent, groups stay). Exports never include speed. Groups are deleted by hand in Manage Groups (swipe, Edit, or tap → Delete Group).
- **Privacy and footprint review (October 2026):** added App Store privacy manifests (`Passing/Resources/PrivacyInfo.xcprivacy`, `PassingWidget/PrivacyInfo.xcprivacy`; UserDefaults reasons CA92.1 app-only and 1C8F.1 App Group; no tracking, no collected data). Update them if a new required-reason API is used. Exports are deleted after sharing and at launch. Look Around loads only on tap. Town-name lookups can be turned off in Settings → Privacy. The capture screen's GPS pill says when Precise Location is off (those fixes never pass `FixPolicy`). README "Privacy and footprint" is the user-facing summary.
- **Reviewed and declined (October 2026):** keeping GPS on in the background or asking for Always (battery; Dan wants location only while the app is open, plus the short burst per capture); `requestLocation()` for intents (it can hand back a cached fix, and the burst keeps going until a fresh one arrives); `ModelActor` (all store access is already on the main actor, one container per process); `usesApplicationAudioSession = false` (speech would stop pausing or lowering music); background-task wrappers against `0xdead10cc` (every save finishes while the app is on screen or before the Siri/widget intent returns). Revisit the last one if a crash report ever shows `0xdead10cc`.
- **Future, not now:** `ROADMAP.md` holds the Passing Pro and sales-workflow roadmap. Don't implement any of it or change the milestones until Dan asks. When it starts, inspect the code and propose a focused plan first.
