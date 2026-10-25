# Passing

Capture things you pass while driving, then look them up later. One tap saves a pin, and identifying the thing happens afterwards. The full spec is in [CLAUDE.md](CLAUDE.md).

**Status:** Milestone 1 (core capture) is verified. Milestone 2 (retention and export) is ready to test. Miles back, Siri, the widget/CarPlay path and review polish come in milestones 3–6.

## What it does so far

**Capture (Milestone 1)**
- **Quick mode (default):** the whole screen is one capture button.
- **Four-zone mode** (Settings → Capture screen): `| Far left | Near left | car | Near right | Far right |` as full-height columns. Near zones are green, far zones blue. Tapping the car saves a pin with the side unknown.
- **Save first:** a tap writes the pin immediately with no label. If GPS has no usable fix yet, the pin is still saved, marked "No location", and picks up the first good fix within 15 seconds. An old position is never used.
- **Approximate flag:** a pin is marked approximate when the car could have moved more than about 50 m between the GPS reading and the tap (speed × time apart), or when the reading was imprecise. A parked car's older reading counts as exact.
- **Non-visual confirmation:** a haptic and a short tone. Spoken "Left, far, saved" is optional. Repeat taps within 0.75 s are ignored, and the screen stays awake.
- **Review:** pins grouped by day. Each pin's detail screen has a map, editable label/side/distance, Reviewed, and Apple Maps / Google Maps links.

**Retention and export (Milestone 2)**
- **7-day expiry:** pins move to **Recently Deleted** 7 days after you pin them. Each pin's row counts down ("Expires in 3 days").
- **Keep:** swipe right on a pin, or use the Keep toggle on its detail screen, to star it. Kept pins never expire.
- **Keep records indefinitely** (Settings) stops expiry for every pin.
- **Recently Deleted** (bottom of the Pins list): tap **Recover** on a pin, swipe left to delete it now, or use **Delete All Now**. Pins there are deleted for good 30 days after they arrive. That happens even with "Keep records indefinitely" on.
- **Deleting** a pin (swipe left, or Delete on its detail screen) moves it to Recently Deleted.
- **Export** (share button on the Pins list): JSON or CSV of all active pins, through the share sheet (AirDrop, Files, Mail, …).
- **When the clean-up runs:** on launch, whenever the app comes back to the front, when you open the Pins list, and in the background when iOS allows. It never runs in the middle of an export.

## Run it

You need **Xcode 26 or newer** (the app targets **iOS 26**).

1. Open `Passing.xcodeproj`.
2. Pick an iPhone simulator and press Run (⌘R). Press ⌘U to run the tests.
3. Give the Simulator a location: **Features → Location → Apple** (parked) or **Freeway Drive** (moving). To set it for every run, choose **Product → Scheme → Edit Scheme… → Run → Options → Default Location**.

### Build and test from Terminal

```sh
xcodebuild -project Passing.xcodeproj -scheme Passing \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Run `xcrun simctl list devices available` to see which simulator names you have.

## Testing the 7- and 30-day rules without waiting

Debug builds (what ⌘R makes) have a **Testing** section at the bottom of Settings. **Clock: +N days** moves the clock that expiry and Recently Deleted use, so pins act as if that many days have passed. Set it back to **0** when you're done. This section doesn't exist in App Store builds.

## Milestone 2 manual test checklist

1. Make 3 pins. In **Pins**, each row says "Expires in 7 days".
2. Swipe right on one pin and tap **Keep**. It gets a star and loses its countdown.
3. Settings → Testing → set the clock to **+7 days**. Go back to **Pins**. The two un-starred pins have moved to **Recently Deleted** (bottom of the list), and the starred one is still there.
4. Open **Recently Deleted**. Each pin says "Deleted for good in 30 days". Tap **Recover** on one. It's back in Pins with a star, because it was already past 7 days.
5. Swipe left on a pin in Pins: it goes to Recently Deleted. In Recently Deleted, swipe left and tap **Delete Now**: it's gone.
6. Set the clock to **+40 days**. Open Recently Deleted: it's empty.
7. Turn on **Keep records indefinitely**, make a pin, and set the clock to **+60**. The pin stays and shows no countdown. Set the clock back to **0** first, then turn the setting off.
8. Pins → share button → **Export JSON**, then **Export CSV (spreadsheet)**. Save each to Files and open it. Every active pin is there, and Recently Deleted pins are not.
9. Force-quit and reopen the app. Stars, Recently Deleted and settings are all still there.

## Set up the App Group (needed for your own iPhone)

The project ships with the App Group `group.com.example.passing`. To run on your phone, the bundle ID and App Group have to be yours:

1. In Xcode, click the blue **Passing** project at the top of the file list, then the **Passing** target, then **Signing & Capabilities**.
2. **Team:** choose your team.
3. **Bundle Identifier:** change `com.example.passing` to something unique, e.g. `com.yourname.passing`.
4. In **App Groups**, click **+** and add `group.com.yourname.passing`. Untick or remove `group.com.example.passing`.
5. Open `Support/Info.plist` and set **PassingAppGroup** to exactly the same `group.…` value.

If the App Group doesn't match, the app still works, but Settings shows an orange **Storage** warning. Fix it before milestones 4–5, or Siri and widget pins won't show up.

## Decisions so far

- **Fix freshness:** a reading up to 10 s old and within 200 m accuracy can be used. The numbers are in `Passing/Model/FixPolicy.swift`.
- **The tone plays even with the ring switch on silent**, because a haptic is easy to miss with the phone in a dash mount. It mixes with music rather than pausing it.
- **Darker zone colors than the mock-up**, so the screen isn't glaring at night.
- **Location permission is requested on the first capture** (privacy rule), so that one tap gets a system prompt. Do your first capture while parked.
- **Expired pins are stamped with when they moved, not when they hit 7 days.** Every pin gets its full 30 days in Recently Deleted, even after weeks away from the app, or after turning off "Keep records indefinitely" with old pins.
- **Recovering a pin that's more than 7 days old also keeps (stars) it.** Otherwise it would expire again on the next clean-up.
- **Exports include active pins only**, not Recently Deleted.

## Project layout

| Piece | Where |
| --- | --- |
| Capture screen | `Passing/Views/CaptureView.swift` |
| Single save entry point | `Passing/Services/CaptureService.swift` |
| GPS and freshness rules | `Passing/Services/LocationProvider.swift`, `Passing/Model/FixPolicy.swift` |
| Pin model and App Group store | `Passing/Model/Pin.swift`, `Passing/Services/SharedStore.swift` |
| Retention rules and clean-up | `Passing/Model/RetentionPolicy.swift`, `Passing/Services/RetentionService.swift` |
| Export | `Passing/Services/PinExport.swift`, `Passing/Services/ExportService.swift` |
| Haptic, tone and speech | `Passing/Services/CaptureFeedback.swift` |
| Review screens | `Passing/Views/PinListView.swift`, `PinDetailView.swift`, `RecentlyDeletedView.swift` |
| Tests | `PassingTests/` |
