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
- **Version numbers (Dan's request, October 2026):** every push that changes the app steps the version: `MARKETING_VERSION` 1.0.1, 1.0.2, … and `CURRENT_PROJECT_VERSION` (the build) up by one, in all six target configurations in `project.pbxproj` (the widget's must match the app's). A bigger batch goes to 1.1 (then 1.1.1, …) when Dan agrees. Tell Dan the new number in the summary. Settings → About shows it (`AppVersion`), and the drive log's `opened` events record it. 1.0 (build 1) was the first install on his iPhone; 1.0.1 (build 2) added the version display; 1.0.2 (build 3) fixed the late-fix crash in tests; Dan confirmed the build is clean and all tests pass on it (iPhone 18 simulator, iOS 27.0). 1.0.3 (build 4): the screen follows Auto-Lock, with a Keep screen on switch.

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
| targetSource | direct / breadcrumb / textOnly / manual (moved by hand in review via `Pin.moveTarget`) |
| trail | optional encoded breadcrumb segment for miles-back pins |
| label | optional, spoken or typed |
| placeName | optional, reverse geocoded town/area, filled lazily |
| source | app / siri / widget / control / actionButton |
| isReviewed, isKept | Bool |
| deletedAt | nil unless in Recently Deleted |
| isNote | Bool, default false; a text note with no location (text in `label`) |
| placeID | optional Apple Maps Place ID of the business chosen in "What's here?"; cleared by Move Pin |
| notes | optional free text added in review, separate from `label` (pins only; a note's text is its `label`); in JSON, CSV and KML |

Keep capture coordinates and target coordinates separate. The app records where the car was plus the driver's directional clue. It never claims to know where the building actually is.

## Capture behavior

- **Save first.** A tap writes the pin immediately. Labels are always optional and added after.
- While the capture screen is open, location updates run (When In Use), so the latest fix is already fresh at tap time. For captures from Siri or the widget, request a one-shot fix and record `fixTimestamp`. At highway speed a 3-second-old fix is ~90 m off, so flag a pin as approximate when the car could have moved more than ~50 m between the fix and the tap (speed × time apart), combined with the fix's own accuracy (square root of the sum of the squares). A parked car's older fix stays exact. If the fix has no speed, fall back to flagging fixes more than 3 s from the tap. A fix more than 3 s *after* the tap is always approximate, whatever its speed, because the car may have braked after passing (ChatGPT review F6).
- If no usable fix arrives, still save the pin with the timestamp and a clear "no location" state. Never substitute an old coordinate.
- **Confirmation is non-visual:** haptic plus a short tone. Optional spoken confirmation ("Left, far, saved") as a setting. No alerts, sheets, or navigation changes on the capture screen.
- Debounce repeat taps on the same zone within ~0.75 s.
- The screen follows iOS Auto-Lock by default (Dan, October 2026: rough positions are fine, and the phone needn't stay lit). Settings → Capture screen → **Keep screen on** (`SettingsKey.keepScreenOn`, off by default) keeps it awake for a dash mount. GPS runs only while the capture screen is actually on screen, so it stops when the phone locks.

## Main screen

Dark, high contrast, no map, no clutter. Settings picks the layout Passing opens with. At Dan's request the two-line title ("Passing" over "Simple" or "Four zones") is also a button that switches layout for the drive; coming back after more than 30 minutes away starts on the Settings layout again (`CaptureModeChoice`). A GPS pill in the title bar, above the title, says whether a tap now gets a position (GPS ready / Finding GPS… / Location off / Precise Location off). It's a standing notice, never a reaction to a tap. The rest of the app follows Settings → Appearance (System by default, or Light/Dark); the capture screen stays dark in every appearance.

**Simple mode (default; stored as `quick`):** the entire screen is one capture button, labeled "Pin it".

**Look (option A, chosen October 2026):** colors from the app icon (`Shared/Views/PassingColors.swift`), the icon's pin on the Simple button and the Pin widget (`PinGlyph`), rounded type. Zones use a gradient sampled from Dan's mockup with a subtle smoky variation he picked (`ZoneFill`: a `MeshGradient` through `ZoneShade.grid`, ±9%, a fixed pattern per zone; brightest near the top and darkening while staying green or blue; slightly darker side edges); the Simple button and the Pin widget get the same subtle smoke over the icon's navy (`ZoneShade.Surface.pin`, Dan's request). Capture buttons are never Liquid Glass, so iOS 27's glass slider can't fade them. Glass is only on the system title-bar buttons and the GPS pill.

**Four-zone mode:** four full-height vertical columns, laid out left to right exactly as the road looks:

```
| Far Left | Near Left | [car] | Near Right | Far Right |
```

- Near zones sit next to the car; far zones are on the outer edges. The layout must be spatially literal so it works without reading labels. Do not use a 2x2 grid or stack left zones above right zones.
- Near and far zones use two distinct colors, mirrored on both sides.
- The center divider is narrow and drawn as the road with the car on it. Tapping it saves a pin with side unknown.

**"Add a note" button** (bottom strip, next to "+1 mi back", Dan's request): asks "What's your note?" and listens (same flow as listen-after-tap, `CaptureFeedback.addSpokenNote()`). What's said is saved as a note: a `Pin` with `isNote = true`, the text in `label`, and no location or GPS. The note is saved before listening and removed if nothing is said (`CaptureService.discardEmptyNote`). Voice only on the capture screen; typed or keyboard-dictated notes come from **New Note** in the Pins list. Never prompts for permission on the capture screen; without speech permission it says how to enable it. Notes follow pin retention, keep, groups and delete; exports mark them `isNote`; KML leaves them out.

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
- Two consecutive fixes more than 300 m apart (`BreadcrumbBuffer.maxJoin`), a gap over 120 s, or an implausible jump start a fresh trail, so a gap (tunnel, capture screen closed at speed) never becomes a straight line that cuts a corner (ChatGPT review F7).
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
- Two small variants: a single "Pin" button, and a 2x2 side/distance grid (match the left/right logic of the phone layout). Plus a medium "Pin Left or Right" widget (Dan's request, for medium Smart Stacks; iPhone only, since CarPlay shows small widgets): split 50/50 into left and right arrow buttons that save the side with distance unknown. "Passing" sits on the seam as a label only (`allowsHitTesting(false)`); the two buttons cover the whole widget, seam and edges included, so no tap opens the app.
- Widget captures are silent (no voice prompt). Labels get added later.
- **Tap feedback:** WidgetKit only redraws after `perform()` returns, and the widget intent waits up to 15 s for a GPS reading first. So each widget's content is wrapped in `SavingAware` with `.invalidatableContent()`, which reads `redactionReasons.contains(.invalidated)`: from the tap until the redraw the whole widget shows green with a tick and "Saving…" (it can't know which button was tapped yet), then the tapped button shows green "Saved", amber "No location", or red "Not saved" (the write failed) for 5 s (`SavedFace`, `WidgetSavedNote`). Green rather than grey was Dan's choice. Dan asked for this after the tick arrived too late on his phone.
- Native CarPlay template app is out of scope unless Dan decides to publish. It would need the Driving Task entitlement from Apple, approval isn't guaranteed, and it would be limited to templates (grid of buttons, not the custom layout).

## Review screen

- List grouped by day, plus a map view. Each row: time, label or "Unlabeled", side/distance, miles back, place name, accuracy, "expires in X days".
- Detail: map with capture point, target, and trail if present; **Move Pin** (`MovePinView`) drags a crosshair map to set the target by hand, never touching the capture point; Look Around preview at the target (or capture point); edit label/side/distance; a **Notes** field (pins, not notes; Dan's request); mark reviewed; keep (star); delete. Details shows the time and town, with coordinates, accuracy, GPS fix, speed, heading and "Saved from" under a **More Details** disclosure, closed by default and remembered for every pin (`SettingsKey.showsPinDetails`).
- **What's here?** (`NearbyPlacesSection`, on request only): `MKLocalPointsOfInterestRequest` around the pin (300 m near, 600 m far/unknown, "Look Farther" 2 km), closest first, up to 5 (Dan's choice). Choosing one (`Pin.choosePlace`) sets the label to its name, the target to its location (`targetSource = .manual`), `placeID`, and the town. Apple link then opens the place card (`maps.apple.com/place?place-id=`, unified Maps URLs, iOS 18.4+); Google link searches "name, town" (Google place IDs need a paid key). Labeled pins without a place also get "Search “label” Here in Apple Maps" (`/search?query=&center=&span=`). If `MKLocalSearch(request:)` doesn't accept the POI request in Xcode, the docs also list `init(pointsOfInterestRequest:)`.
- Map links use the place card if a place was chosen, otherwise the target if present, otherwise capture point:
  - Apple: `https://maps.apple.com/?ll=LAT,LON&q=LABEL`
  - Google: `https://www.google.com/maps/search/?api=1&query=LAT,LON`
- Reverse geocode lazily when online to fill `placeName` (answers "what town was that" automatically).
- Export JSON and CSV through the share sheet.
- **Needs Review:** a smart list (`GroupFilter.needsReview`, `Pin.needsReview`) of active widget and Control Center pins (`CaptureSource.needsReviewUntilReviewed`) not marked Reviewed. Dan asked that phone and Siri pins stay out. It's not a group, so it doesn't conflict with "a pin belongs to at most one group". Filing one of those pins in a group marks it Reviewed (`PinGroups.move`, Dan's request). A row at the top of Pins shows the count; elsewhere in the list those pins get a faint amber row tint and a tray icon; in Needs Review a full swipe right marks Reviewed. `Route.needsReview` opens Pins on it.
- **Review reminders** (`ReviewReminders`, `ReviewReminderSettings` in App Group defaults; off by default): Passing's own local notifications, not Apple Reminders (Dan wants it light and private; EventKit is a possible later option). Armed by `CaptureService` after each widget/Control Center pin (`reviewWaiting`), so they fire only while something waits: the next `hour:minute` (8:00 AM default, `UNCalendarNotificationTrigger`) and/or arrival at saved Work/Home (`UNLocationNotificationTrigger`, 150 m; per Apple's docs it needs only When In Use because iOS monitors the region). Cancelled when Needs Review empties. Notification permission is asked only in Settings. Tapping one opens Needs Review (`ReviewReminderDelegate`, `ReviewRoute`); while Passing is open they go to Notification Center with no banner (`.list`). Unverified: whether iOS lets the widget extension arm the location trigger; if `add` fails, a retry flag makes the app arm it on next open.
- **Groups (folders):** Dan can put pins into named groups in the review list (e.g. "Road trip", "Houses to check") and filter by group. A pin belongs to at most one group. Deleting a group never deletes its pins. Groups are listed in Dan's order (`PinGroup.sortOrder`, then name; `PinGroup.displayOrder`), set by dragging in Manage Groups (Edit); new groups go at the bottom.
- **"Passing pins" collection in a maps app:** Apple Maps has no public API for creating Guides or adding places to them (checked October 2026), so the app can't fill an Apple Maps Guide automatically. Instead, export a KML file that Google My Maps imports as a "Passing pins" map, and keep "Open in Apple Maps" on each pin so it can be added to a Guide by hand. Revisit if Apple adds an API.

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
- No analytics. No location data leaves the device except map, geocoding, and Look Around requests to Apple. Review-reminder places (work/home) stay on the device; an address search sends the typed text to Apple Maps. "What's here?" sends a pin's location to Apple only when tapped.

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
  - One exception, at Dan's request: with listen-after-tap on, a big "Stop listening" button takes the Passing title's place (same fixed height; the GPS pill hides) while Passing asks or listens. It never moves or covers the capture buttons, and listening ends by itself, so it never has to be pressed.
- Every voice prompt is optional and can be turned off.

## Current status

- Milestones 1–7 are done (Milestone 5 confirmed in the Simulator, including its CarPlay window; Dan ran 7 and its follow-ups without issues). Work happens on branch `claude/road-marker-pin-app-flj2qm`.
- **Design refresh (option A) is built and waiting for Dan's test run** (README, "Design refresh checklist"). Notes:
  - Checked against WWDC26 "What's new in SwiftUI": iPhone apps can be resized on iOS 27 (so the capture layout stays flexible, and the Simple pin shrinks first), the new Liquid Glass slider changes glass tint (so capture buttons stay solid), and `@State` is now a macro (a default value plus an assignment in `init` is an error; there are none here). `confirmationDialog(_:item:)` and `alert(_:item:)` are iOS 27-only, so the iOS 26 forms stay.
  - `Text + Text` is deprecated in the iOS 26 SDK; use separate `Text` views or interpolation.
  - Never read a `Pin`'s properties after an `await` until `pin.modelContext != nil` (and `!pin.isDeleted`) has been checked: a pin whose store is gone crashes when read. Read what's needed before the wait. (The drive log's late-fix entry broke this once and crashed the test host, so every SwiftData test showed "Testing was canceled".)
  - Keep expressions small enough for the type checker ("unable to type-check this expression in reasonable time"). It hit twice in `PinListView`: a 9-term `||` chain with `!= nil` checks (split into typed `let`s), then the whole `body` modifier chain (split into `body` → `presented` → `titled` + `@ToolbarContentBuilder toolbarItems`, with longer handlers as named methods). Add new modifiers to the piece they belong in, not all to `body`.
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
- **Schema changes:** after an update, the app and the widget extension can both open the store at once and both try the migration. `SharedStore` retries three times. If the App Group store still won't open, it never falls back to a private on-disk store (pins saved there would be stranded): `SharedStore.state` becomes `.unavailable`, it runs on an empty in-memory store, and `SharedStore.save` refuses, so every capture reports failure until the next launch. With no App Group at all (`.appOnly`), the app uses its own store and the widget extension refuses to save (`sharedOnly`). Keep model changes additive (new optional fields, new models) so migrations stay lightweight.
- **Honest save results (ChatGPT review, October 2026):** success feedback depends on the write, never on the pin existing in memory. `CaptureService` takes an injectable `persist`, tracks `unsavedPinIDs` (`isSaved`, `retrySave`; any later successful save writes them too), and calls `failed` instead of `confirm` for phone taps (`CaptureFeedback.captureFailed()`: error haptic, "Pin not saved." if spoken confirmation is on). Siri says "Sorry, I couldn't save that pin." The capture screen's pill shows "Can't save pins" ahead of any GPS state. Exports report which pins they contain (`ExportFile.pinIDs`, `PinExport.includedIDs`), so "Delete pins after exporting" never deletes notes or no-location pins a KML file left out. Moving a pin changes `Pin.lookUpKey`: the detail screen drops Look Around and re-runs the town lookup, "What's here?" clears its results unless the move came from choosing one of them, and async results for the old spot are discarded. `PlaceNameService` keys in-flight and no-name entries by pin and spot, checks the Privacy switch before every request, and spaces requests across callers (`lastRequestAt`). `LocationProvider.nextUsableFix` returns nil at once when location is denied or iOS Precise Location is off (F8). The capture screen counts as closed while Settings covers it (`CaptureView.isCovered`): GPS stops and the screen may sleep.
- **Keep the build warning-free** (Dan asked). Two Swift 6 warnings have come up: a `Sendable` conformance declared outside the type's own file, and a one-line `Task { … }` whose last call returns a non-Sendable value (it becomes the task's result; write `_ =`). When Xcode offers "Update to recommended settings", Dan sends the list and the settings get written into `project.pbxproj` here.
- **Privacy settings Dan chose (October 2026):** "Precise location" (on by default; off rounds each pin to ~1 km via `Pin.coarsenLocation()` at save, drops speed and the route, keeps the compass direction; stored in App Group defaults via `LocationPrivacy` so the widget follows it). "Delete pins after exporting" (off by default; only after a completed share; kept pins stay). "Delete All Pins" in Settings (permanent, groups stay). Exports never include speed. Groups are deleted by hand in Manage Groups (swipe, Edit, or tap → Delete Group).
- **Drive log (October 2026, Dan's request for real-drive feedback):** opt-in, off by default (`DriveLog.enabledKey` in App Group defaults, so the widget follows). `DriveLogEntry` (pure, Linux-tested) with `DriveLogSummary` for the screen and the shared text; `DriveLog` writes one JSON line per event to `DriveLog-app.jsonl` / `DriveLog-widget.jsonl` in the App Group container (one file per process, so they never collide; each trims to its newer half past 400 KB) and skips writing under XCTest. Logged after the thing it records, so capture never waits: captures and bumps (`CaptureService`), late fixes, intents with Siri's question outcome (`IntentCapture`), GPS sessions and skipped waits and trail restarts (`LocationProvider`, `BreadcrumbBuffer.add` returns `Restart`), listening (`CaptureFeedback`), store open, save failures, clean-up, town lookups, and launch time (`LaunchClock`). Never coordinates, labels, notes or speed. Settings → Feedback → Drive Log (`DriveLogView`): summary, newest 100 events, Share (text file, tidied by `ExportService.removeExportedFiles`), Clear. No new required-reason APIs (durations use `Date`, sizes come from `FileHandle.seekToEnd`).
- **Privacy and footprint review (October 2026):** added App Store privacy manifests (`Passing/Resources/PrivacyInfo.xcprivacy`, `PassingWidget/PrivacyInfo.xcprivacy`; UserDefaults reasons CA92.1 app-only and 1C8F.1 App Group; no tracking, no collected data). Update them if a new required-reason API is used. Exports are deleted after sharing and at launch. Look Around loads only on tap. Town-name lookups can be turned off in Settings → Privacy. The capture screen's GPS pill says when Precise Location is off (those fixes never pass `FixPolicy`). README "Privacy and footprint" is the user-facing summary.
- **Efficiency review (October 2026):** no unused declarations found. Launch does only the store, retention (now fetching only pins at least 7 days old), and small audio/haptic setup. Removed a duplicate compass helper (`Geo.compassName(for:short:)` covers both) and an unused `AppSettings.captureMode`. Left on purpose: Recently Deleted's full fetch and in-memory sort (small, and that screen once froze), the GPS pill's 1 s refresh (one tiny view), debug-only `#Preview`s and error `print`s.
- **Reviewed and declined (October 2026):** keeping GPS on in the background or asking for Always (battery; Dan wants location only while the app is open, plus the short burst per capture); `requestLocation()` for intents (it can hand back a cached fix, and the burst keeps going until a fresh one arrives); `ModelActor` (all store access is already on the main actor, one container per process); `usesApplicationAudioSession = false` (speech would stop pausing or lowering music); background-task wrappers against `0xdead10cc` (every save finishes while the app is on screen or before the Siri/widget intent returns). Revisit the last one if a crash report ever shows `0xdead10cc`.
- **Gemini architecture review (October 2026), checked against the code:** added a town-name cache (`PlaceNaming.cacheKey`, ~1 km squares, memory only) so nearby pins share one lookup, and only real requests are spaced. Not changed, with reasons: file protection is already the iOS default (Complete Until First User Authentication; no data-protection entitlement), and locked-phone widget buttons don't run anyway; the review's `BestForNavigation`/`CLGeocoder` claims don't match the code (`kCLLocationAccuracyBest`, `MKReverseGeocodingRequest`); turning on auto-pause or a distance filter would starve the 10 s freshness rule when parked; cross-process refresh already works on activate. Offered to Dan, pending: long-press for the title layout switch, a short pause before speaking over Bluetooth hands-free (test in the car first), live list refresh while open. Dan's answers: no long press (the title stays a tap), Bluetooth pause later maybe, live refresh yes: the widget extension posts a Darwin notification after each save (`WidgetActivity.pinSaved`), and RootView rebuilds the Pins list at once, holding the list's filter (`listFilter`) so a rebuild keeps it. The rebuild waits while the list reports it's busy (`PinListView.isBusy` → `holdsRefresh`: Select, map, scrolled down, New Note, export, Move Pin, group alerts) or has anything pushed on top (`listCanRebuild`), then runs when that clears (ChatGPT review F4). The Pro morning-email limit (no background mail UI) is noted for when ROADMAP work starts.
- **Parked: Apple Watch app (Milestone 8, planned October 2026).** Dan has an Apple Watch Series 10 and wants a full watch app, but first he's running Passing for a few weeks to gather logs and tune efficiency. Don't start it until he asks. The agreed plan:
  - Watch screens: one big "Pin it" button with a wrist haptic on save, pressable by double tap (`.handGestureShortcut(.primaryAction)`, watchOS 11+); a second page with four side/distance buttons laid out like the 2x2 widget (left/right columns, far top, near bottom, same colors); a complication that opens the app; a small status line (GPS ready / pins waiting to send).
  - Location from the watch's own GPS, with the same `FixPolicy` freshness rules (the app is on screen when tapped, so When In Use is enough).
  - Pins sync to the iPhone with WatchConnectivity `transferUserInfo` (queued, in order, no server), arriving as a new `CaptureSource.watch` (additive raw value) that goes into Needs Review and arms review reminders. Add a CaptureService entry point that saves a pin with a fix supplied by the watch, so save logic isn't duplicated. Apple's docs say the Simulator doesn't support `transferUserInfo`, so sync is tested on Dan's real devices.
  - Later options, not in v1: +1 mi back on the watch (needs a trail, battery cost), voice labels, a watchOS 26 Control Center control.
  - Process: Dan's signing settings are already in the repo. He adds the watch target with Xcode's New Target wizard (click-by-click steps; safer than hand-editing the project for watch embedding) and pushes; then the code goes into the wizard's synced folder. Developer Mode must be on for the watch too.
- **Signing setup (Dan's, pushed October 2026; the correct model, keep it):** team `8SS7RZ89R8`, set once in the project-level Debug and Release build settings and inherited by every target (Xcode 27.1's "Inherit Development Team from Project Settings", applied by Dan; targets carry no `DEVELOPMENT_TEAM` of their own, so don't add one back; `LastUpgradeCheck` 2710); bundle IDs `com.danhall.passing` (app), `com.danhall.passing.widget` (widget extension), `com.danhall.passing.tests` (tests); App Group `group.com.danhall.passing` in both entitlements files and in `PassingAppGroup` in `Support/Info.plist` and `Support/PassingWidget-Info.plist` (tests have none). Never revert these to `com.example`. A future watch target follows the same pattern (`com.danhall.passing.watchkitapp`).
- **Future, not now:** `ROADMAP.md` holds the Passing Pro and sales-workflow roadmap. Don't implement any of it or change the milestones until Dan asks. When it starts, inspect the code and propose a focused plan first.
