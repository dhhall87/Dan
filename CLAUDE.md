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
- Deployment target: iOS 26 (CarPlay widget support requires it)
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
| latitude, longitude | actual capture coordinates, never overwritten |
| horizontalAccuracy | meters |
| course, courseReliable | degrees; false when speed is too low for course to mean anything |
| speed | m/s |
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
- While the capture screen is open, location updates run (When In Use), so the latest fix is already fresh at tap time. For captures from Siri or the widget, request a one-shot fix and record `fixTimestamp`. At highway speed a 3-second-old fix is ~90 m off, so flag a pin as approximate when the car could have moved more than ~50 m between the fix and the tap (speed × time apart). A parked car's older fix stays exact. If the fix has no speed, fall back to flagging fixes more than 3 s from the tap.
- If no usable fix arrives, still save the pin with the timestamp and a clear "no location" state. Never substitute an old coordinate.
- **Confirmation is non-visual:** haptic plus a short tone. Optional spoken confirmation ("Left, far, saved") as a setting. No alerts, sheets, or navigation changes on the capture screen.
- Debounce repeat taps on the same zone within ~0.75 s.
- Keep the screen awake while the capture screen is showing.

## Main screen

Dark, high contrast, no map, no clutter. Mode switch lives in Settings, not on the capture screen.

**Quick mode (default):** the entire screen is one capture button.

**Four-zone mode:** four full-height vertical columns, laid out left to right exactly as the road looks:

```
| Far Left | Near Left | [car] | Near Right | Far Right |
```

- Near zones sit next to the car; far zones are on the outer edges. The layout must be spatially literal so it works without reading labels. Do not use a 2x2 grid or stack left zones above right zones.
- Near and far zones use two distinct colors, mirrored on both sides.
- The car is a narrow center divider. Tapping it saves a pin with side unknown.

**"+1 mi back" button** (bottom strip, both modes):
- One action. A tap creates a pin placed 1 mile back along the breadcrumb trail.
- Tapping again within ~4 s bumps that same pin to 2 mi, 3 mi, and so on, with tone/haptic per step (and spoken "2 miles back" if spoken confirmation is on).
- No separate "pending offset" state that requires a second tap somewhere else. Side defaults to unknown and is editable in review.

## Voice confirmation options

- Spoken confirmation stays optional and off by default.
- When Passing speaks, other audio (music, podcasts) pauses and resumes afterwards, rather than playing underneath. A setting switches this to lowering the volume instead. The short tone always mixes with music.
- **Voice picker:** choose from the voices installed on the phone (`AVSpeechSynthesisVoice.speechVoices()`), labeled by quality (Default / Enhanced / Premium), with a preview button. The default is the system voice for the phone's language. Siri voices aren't available to third-party apps, and no voice files are bundled. Better voices are free downloads in iOS Settings → Accessibility → Spoken Content → Voices, and the app explains how to get them. Refresh the list when installed voices change. Optionally offer the user's Personal Voice, with their permission.
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
6. **Review polish.** Look Around, reverse geocoding, pin groups (folders), KML export for a Google My Maps "Passing pins" map, optional listen-after-tap.

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
- Every voice prompt is optional and can be turned off.
