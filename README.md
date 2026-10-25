# Passing

Capture things you pass while driving, then look them up later. One tap saves a pin, and identifying the thing happens afterwards. The full spec is in [CLAUDE.md](CLAUDE.md).

**Status: Milestone 1 (core capture).** Retention, miles back, Siri, the widget/CarPlay path and review polish come in milestones 2–6.

## What Milestone 1 does

- **Quick mode (default):** the whole screen is one capture button.
- **Four-zone mode** (Settings → Capture screen): `| Far left | Near left | car | Near right | Far right |` as full-height columns. Near zones are green, far zones blue. Tapping the car saves a pin with the side unknown.
- **Save first:** a tap writes the pin immediately with no label. If GPS has no usable fix yet, the pin is still saved, marked "No location", and picks up the first good fix within 15 seconds (flagged approximate). An old position is never used.
- **Non-visual confirmation:** a haptic and a short tone. Spoken "Left, far, saved" is optional (off by default).
- Repeat taps on the same zone within 0.75 s are ignored. The screen stays awake while the capture screen is showing.
- **Review:** pins grouped by day, showing time, label or "Unlabeled", side/distance and accuracy. The detail screen has a map, editable label/side/distance, a Reviewed toggle, Apple Maps and Google Maps links, and the raw GPS details.
- Pins are stored with SwiftData in an App Group container, so Siri and the widget can share them later.

## Run it

You need **Xcode 26** (the app targets **iOS 26**).

1. Open `Passing.xcodeproj`.
2. Pick an iPhone simulator and press Run (⌘R).
3. Give the simulator a location: **Features → Location → Freeway Drive** (moving) or **Apple** (parked).

If Xcode asks for a development team even for the Simulator, pick your Personal Team under **Signing & Capabilities**.

### Build and test from Terminal

```sh
xcodebuild -project Passing.xcodeproj -scheme Passing \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcodebuild -project Passing.xcodeproj -scheme Passing \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Run `xcrun simctl list devices available` if you don't have an "iPhone 17" simulator, and use a name from that list.

## Set up the App Group (needed for your own iPhone)

The project ships with the App Group `group.com.example.passing`. To run on your phone, the bundle ID and App Group have to be yours:

1. In Xcode, click the blue **Passing** project at the top of the file list, then the **Passing** target, then the **Signing & Capabilities** tab.
2. **Team:** choose your team.
3. **Bundle Identifier:** change `com.example.passing` to something unique, e.g. `com.yourname.passing`.
4. In the **App Groups** section, click **+** and add `group.com.yourname.passing` (the bundle ID with `group.` in front). Untick or remove `group.com.example.passing`.
5. Open `Support/Info.plist` and set **PassingAppGroup** to exactly the same `group.…` value.
6. Run on your phone. If the App Group doesn't match, the app still works, but Settings shows an orange **Storage** warning. Fix it before milestones 4–5, or Siri and widget pins won't show up.

## Milestone 1 manual test checklist (parked)

1. Fresh install, Quick mode: tap once. You feel a haptic, hear a tone, and the location permission prompt appears (first capture only). Allow it.
2. Open **Pins**. The pin says "Unlabeled", today's time, and an accuracy like "±5 m". This first pin may say "approximate", because permission was granted after the tap, or "No location" if the prompt took more than 15 seconds to answer.
3. Tap again on the capture screen: haptic and tone, no pop-up, no screen change. Double-tap quickly: only one new pin.
4. Settings → **Four zones**. Tap each column once, left to right, then the car. In Pins, check you get Far left, Near left, Near right, Far right, and one with no side.
5. Open a pin and tap **Open in Apple Maps** and **Open in Google Maps**. Both should show where you were parked.
6. Edit a label, side and distance, then go back. The list updates.
7. Force-quit the app and reopen it. All pins are still there.
8. iOS Settings → Passing → Location → **Never**, then reopen Passing. An orange "Location is off" strip appears. Tap: the pin saves as "No location" and never takes an old position.
9. Turn on Airplane Mode and capture a pin, then review it. Everything works except map tiles.
10. Settings → Spoken confirmation on: a four-zone tap says "Left, far, saved".

## Decisions in this milestone

- **Fix freshness:** a fix up to 10 s old and within 200 m accuracy can be used. More than 3 s from the tap or worse than 50 m counts as approximate. These numbers are in `Passing/Model/FixPolicy.swift`.
- **The tone plays even with the ring switch on silent**, because a haptic is easy to miss with the phone in a dash mount. It mixes with music rather than pausing it.
- **Darker zone colors than the mock-up** (deep green and blue with white text), so the screen isn't glaring at night.
- **Location permission is requested on the first capture** (privacy rule), so that one tap gets a system prompt. Do your first capture while parked.
- **Deleting is permanent for now.** Milestone 2 turns it into Recently Deleted.

## Project layout

| Piece | Where |
| --- | --- |
| Capture screen | `Passing/Views/CaptureView.swift` |
| Single save entry point | `Passing/Services/CaptureService.swift` |
| GPS and freshness rules | `Passing/Services/LocationProvider.swift`, `Passing/Model/FixPolicy.swift` |
| Pin model and App Group store | `Passing/Model/Pin.swift`, `Passing/Services/SharedStore.swift` |
| Haptic, tone and speech | `Passing/Services/CaptureFeedback.swift` |
| Review list and detail | `Passing/Views/PinListView.swift`, `Passing/Views/PinDetailView.swift` |
| Tests | `PassingTests/` |
