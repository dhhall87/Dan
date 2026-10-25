# Passing

Capture things you pass while driving, then look them up later. One tap saves a pin, and identifying the thing happens afterwards. The full spec is in [CLAUDE.md](CLAUDE.md).

**Status:** Milestones 1–4 are done. Milestone 5 (widgets, CarPlay and Control Center) is built and waiting for its test run. Review polish (groups, maps export) comes in Milestone 6.

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

**Miles back and voice (Milestone 3)**
- **+1 mi back** (amber strip at the bottom of the capture screen): one tap saves a pin 1 mile back along the road you just drove. Tap again within 4 seconds and the same pin moves to 2 miles, 3 miles, and so on, with a haptic and tone each time.
- **How it knows the road:** while the capture screen is open, Passing keeps a trail of the last ~25 miles in memory, a point every ~50 m. It's never saved and never recorded in the background.
- **On the map:** the pin's detail screen shows your car (blue), the estimate (orange "About here") and the road between them. Apple and Google Maps links go to the estimate.
- **Not enough trail yet** (app just opened): no estimate goes on the map. Instead the pin says "About 2 miles back the way you came. You were heading southwest, so look northeast of this spot."
- **Voice** (Settings → Spoken confirmation → Voice): every voice installed on the iPhone, best quality first, each with ▶︎ to preview. Siri's own voices aren't available to apps. Better ones are free downloads in iOS Settings → Accessibility → Spoken Content → Voices. Your Personal Voice can be used too, with permission.
- **Phrases** (Settings → Spoken confirmation → Phrases): type your own, like "Got it boss" or "I'll look this up later". One is picked at random after each pin. "Say side and distance first" adds "Left, far." before it. Phrases max out at 60 characters. "+1 mi back" always says the distance instead ("2 miles back").

**Siri, Action Button and Back Tap (Milestone 4)**
- **"Hey Siri, pin that in Passing"** (or "pin this", "mark that", "mark this"): the pin is saved straight away, then Siri asks **"What did you see?"**. Answer and it becomes the label. Say "cancel" or stay quiet and the pin is still kept, unlabeled. Works from CarPlay's voice button, AirPods and the phone.
- **"Hey Siri, I missed something in Passing"**: a pin 1 mile back along the road, then the same question.
- **Quick Pin**: saves without asking anything. Use it for the Action Button and Back Tap, where a question would appear on screen and need typing.
- Siri replies with one short line ("Saved “red barn”.") and says so if it couldn't get a location.
- **Music pauses while Passing speaks** (spoken confirmations and previews), then picks up again. Turn off **Pause music while speaking** in Settings to have it lowered instead. The short tone never interrupts music.

**Widgets, CarPlay and Control Center (Milestone 5)**
- **Pin widget:** a small home-screen widget that's one big button. Tap it to save a pin. Passing doesn't open and nothing is asked.
- **Pin by Side widget:** four buttons. The left column is the left side of the road and the right column the right side, as on the phone. The top row is far and the bottom row near, like looking up the road. Near is green and far is blue, as on the capture screen.
- **CarPlay:** both widgets are small, so they can go on CarPlay's Widgets screen. On a touchscreen car, tapping a button saves a pin. Passing doesn't need its own CarPlay app for this.
- **Control Center:** a **Pin That** control. It can also go on the Lock Screen, or on the Action Button on recent iPhones.
- Widget and Control Center pins are **silent**: no tone, no voice. For about 5 seconds, the button you tapped shows a tick with "Saved", or "No location" if no GPS reading arrived. Labels get added later in Pins.
- **Location:** when you add a widget, iOS asks whether Passing's widgets may use your location. Allow it, and Passing's location setting becomes "While Using the App or Widgets". Each widget tap saves the pin first, then waits up to 15 seconds for a GPS reading, as Siri does.
- Repeat taps on the same widget button within 0.75 s count as one, as on the capture screen.

## Run it

You need **Xcode 26 or newer** (the app targets **iOS 26**).

1. Open `Passing.xcodeproj`.
2. Pick an iPhone simulator and press Run (⌘R). Press ⌘U to run the tests.
3. Give the Simulator a location. While the app runs, click the **location arrow** in Xcode's debug bar (the strip above the console) and pick **KansasDrive** for a moving car, or a city to stay parked. To use it on every run, choose **Product → Scheme → Edit Scheme… → Run → Options → Default Location**.

### The test drive

`TestRoutes/KansasDrive.gpx` is a recorded 16-mile drive at 65 mph: 8 miles east, then 8 miles north, about 15 minutes. Xcode replays it so the Simulator moves like a car, which makes "+1 mi back" testable at a desk. It's only for testing and isn't part of the app.

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

## Milestone 3 manual test checklist

1. Run the app, then click the **location arrow** in Xcode's debug bar and choose **KansasDrive**. Keep the capture screen open for about 4 minutes. In debug builds, Settings → Testing shows **Trail recorded** growing. After about 7.5 minutes the route turns north, so 1–2 miles back from there lands around the corner on the first road.
2. Tap **+1 mi back** once. In **Pins**, the new pin says "1 mi back". Open it: the map shows the blue car, the orange "About here" about a mile back along the road, and a blue line between them. **Open in Google Maps** goes to the orange spot.
3. Back on the capture screen, tap **+1 mi back** three times, less than 4 seconds apart. (Leaving the capture screen pauses the trail, so give it a few seconds to pick back up.) You get one new pin, "3 mi back", with a haptic and tone on each tap.
4. Wait 5 seconds and tap **+1 mi back** again. That makes a separate new pin, "1 mi back".
5. Force-quit and reopen, then immediately tap **+1 mi back**. That pin has no orange spot and says "About 1 mile back the way you came…" instead, because the trail starts empty.
6. Settings → turn on **Spoken confirmation** → **Voice**. Tap ▶︎ on a few voices, then tap one to choose it. The Simulator has fewer voices than a real iPhone.
7. **Phrases:** add "Got it boss" and "I'll look this up later", and swipe left to remove "Saved". Tap ▶︎ to hear each one. Back in Settings, tap **Preview**.
8. On the capture screen in Four zones, tap a few zones. You should hear things like "Left, far. Got it boss." Turn off **Say side and distance first** and you just hear the phrase.
9. Tap **+1 mi back** twice quickly. You hear "1 mile back", then "2 miles back".

## Milestone 4 manual test checklist

Siri works best on your iPhone (see "Set up the App Group" below for running it there). In the Simulator, you can run the same actions from the Shortcuts app (**Shortcuts → App Shortcuts → Passing**) and type the answer.

1. With Passing open on the capture screen, say **"Hey Siri, pin that in Passing."** Siri asks "What did you see?". Say "red barn". Siri replies "Saved “red barn”." In Pins, the pin is labeled "red barn" and has a location.
2. Do it again, but say **"cancel"** (or say nothing) when Siri asks. The pin is still in Pins, "Unlabeled".
3. **The important one:** swipe Passing away completely in the app switcher, then say "Hey Siri, pin that in Passing". Afterwards, open Passing. **Does that pin have a location?** Tell me either way. Apple's docs don't say whether this works, and the spec asks us to check rather than assume.
4. Say **"Hey Siri, I missed something in Passing."** Siri replies "Saved, 1 mile back."
5. **Action Button** (iPhone 15 Pro or newer): iOS **Settings → Action Button**, swipe to **Shortcut**, tap **Choose a Shortcut → Passing → Quick Pin**. Press the Action Button: a pin is saved with no question.
6. **Back Tap:** in the **Shortcuts** app tap **+**, search for **Quick Pin**, add it and tap **Done**. Then iOS **Settings → Accessibility → Touch → Back Tap → Double Tap**, and pick that shortcut. Double-tap the back of the phone: a pin is saved.
7. **Music pausing:** play something in Music or Podcasts. In Passing, turn on **Spoken confirmation**, then tap a zone. The music pauses, Passing speaks, and the music resumes. Turn off **Pause music while speaking**, tap again, and the music just gets quieter.
8. Settings now has a **Siri and the Action Button** section with a Siri tip and a Shortcuts button.

## Milestone 5 manual test checklist

Before you start: in Xcode, choose **Integrate → Pull** (or **Source Control → Pull**) to get the new code, and keep the **Passing** scheme selected next to the Run button. A new **PassingWidgetExtension** scheme may appear. Ignore it, because running Passing installs the widgets too. If you've set a Team on the Passing target, set the same Team on **PassingWidgetExtension** too (Signing & Capabilities).

1. Press ⌘U. All tests pass. Then press ⌘R. Set the Simulator's location (location arrow in the debug bar → a city).
2. **Add the Pin widget:** go to the Simulator's home screen (⇧⌘H). Click and hold an empty spot → **Edit** → **Add Widget** → search **Passing** → **Pin** → **Add Widget** → **Done**. If iOS asks whether Passing's widgets may use your location, choose **Allow**.
3. **Tap the widget.** Within a few seconds it shows a tick and **Saved**, then goes back to normal after about 5 seconds. Open Passing → **Pins**: there's a new unlabeled pin with a location, and **Saved from** says **Widget**.
4. **Add Pin by Side** the same way. Tap each of the four buttons, a few seconds apart. Each one gets the tick. In Pins they read Left, far / Right, far / Left, near / Right, near, matching what you tapped.
5. Double-tap one widget button quickly. Only one pin is saved.
6. **List refresh:** open Passing's Pins list, go to the home screen, tap a widget, then switch back to Passing. The new pin is in the list.
7. **Control Center:** swipe down from the top-right corner of the Simulator screen. Click and hold an empty spot (or tap **+**) → **Add a Control** → search **Passing** → **Pin That**. Close the editor and tap the control. Open Passing → Pins: a new pin, and **Saved from** says **Control Center**. **Does it have a location?** Tell me either way. Apple doesn't document whether Control Center counts as "in use" for location.
8. **CarPlay:** in the Simulator's menu bar choose **I/O → External Displays → CarPlay**. In the CarPlay window, go to the **Widgets** screen, click and hold to edit, and add Passing's **Pin** or **Pin by Side**. Tap a button in the CarPlay window. **Tell me:** does the button respond, does the tick appear, and does the pin in Pins have a location? Apple's docs say buttons work on touchscreen cars, but CarPlay's handling of widget location isn't documented.
9. **No location:** iOS Settings → Privacy & Security → Location Services → Passing → choose **While Using the App** (not "…or Widgets"). Tap the Pin widget. After about 15 seconds it shows **No location**, and the pin is saved anyway with no position. Set it back to **While Using the App or Widgets**.
10. iOS Settings → Privacy & Security → Location Services → Passing: the purpose text now mentions widgets, Control Center and Siri.

## Set up the App Group (needed for your own iPhone)

The project ships with the App Group `group.com.example.passing`. To run on your phone, the bundle IDs and App Group have to be yours. There are two targets to change, the app and the widget:

1. In Xcode, click the blue **Passing** project at the top of the file list, then the **Passing** target, then **Signing & Capabilities**.
2. **Team:** choose your team.
3. **Bundle Identifier:** change `com.example.passing` to something unique, e.g. `com.yourname.passing`.
4. In **App Groups**, click **+** and add `group.com.yourname.passing`. Untick or remove `group.com.example.passing`.
5. Open `Support/Info.plist` and set **PassingAppGroup** to exactly the same `group.…` value.
6. Now click the **PassingWidgetExtension** target and repeat: same **Team**, Bundle Identifier `com.yourname.passing.widget` (it must start with the app's ID), and tick the same App Group.
7. Open `Support/PassingWidget-Info.plist` and set **PassingAppGroup** to the same value.

If the App Group doesn't match, the app still works, but Settings shows an orange **Storage** warning, and the widgets show **Not set up** instead of their buttons, because their pins would never reach the app.

## Decisions so far

- **Fix freshness:** a reading up to 10 s old and within 200 m accuracy can be used. The numbers are in `Shared/Model/FixPolicy.swift`.
- **The tone plays even with the ring switch on silent**, because a haptic is easy to miss with the phone in a dash mount. It mixes with music rather than pausing it.
- **Darker zone colors than the mock-up**, so the screen isn't glaring at night.
- **Location permission is requested on the first capture** (privacy rule), so that one tap gets a system prompt. Do your first capture while parked.
- **Expired pins are stamped with when they moved, not when they hit 7 days.** Every pin gets its full 30 days in Recently Deleted, even after weeks away from the app, or after turning off "Keep records indefinitely" with old pins.
- **Recovering a pin that's more than 7 days old also keeps (stars) it.** Otherwise it would expire again on the next clean-up.
- **Exports include active pins only**, not Recently Deleted.
- **The trail only records while the capture screen is open** (no background location). Opening the Pins list mid-drive pauses it. A gap of more than 2 minutes, or an impossible jump (faster than ~155 mph, like a GPS glitch), starts a fresh trail. Passing can't know which road joined the two ends.
- **"+1" taps aren't debounced**, because quick taps are how you say "3 miles". Each extra tap measures back from where you first tapped, not from where the car is by then.
- **Miles-back confirmations say the distance, not your phrase**, so you always know how far back it went.
- **Two kinds of shortcut:** "Pin That" asks a question through Siri. "Quick Pin" never asks, because outside Siri the question would pop up on screen and need typing.
- **The Control Center button moved to Milestone 5.** It needs the same widget extension as the CarPlay widget, so it was simpler to add both at once.
- **Widget and Control Center taps run in the widget extension, not the app.** Apple's docs say so, and say widgets can use location once you allow it for them. The widget extension shares the capture code in `Shared/` with the app, so there's still one save path. Whether Control Center and CarPlay count as "in use" for location isn't documented, so the checklist asks you to check.
- **No "+1 mi back" on the widgets.** It needs the trail, which only exists while the app's capture screen is open.
- **The grid widget is 2x2, unlike the phone screen.** The spec asks for that, and a small widget is too narrow for five columns you can hit while driving.
- **No automatic Apple Maps Guide:** Apple doesn't let apps create Guides or add places to them. Milestone 6 adds a KML export that Google My Maps turns into a "Passing pins" map. Each pin also keeps "Open in Apple Maps", where you can tap "Add to Guide" yourself.

## Project layout

| Piece | Where |
| --- | --- |
| Code used by both the app and the widget | `Shared/` |
| Capture screen | `Passing/Views/CaptureView.swift` |
| Single save entry point | `Shared/Services/CaptureService.swift`, wired up per target in `Passing/Services/CaptureService+App.swift` and `PassingWidget/CaptureService+Widget.swift` |
| Siri, Shortcuts, Action Button | `Passing/Intents/CaptureIntents.swift`, `Shared/Services/IntentCapture.swift` |
| Widgets and Control Center | `PassingWidget/`, `Shared/Intents/WidgetIntents.swift` |
| GPS and freshness rules | `Shared/Services/LocationProvider.swift`, `Shared/Model/FixPolicy.swift` |
| Pin model and App Group store | `Shared/Model/Pin.swift`, `Shared/Services/SharedStore.swift`, `Shared/Services/AppGroup.swift` |
| Miles back (trail and estimate) | `Shared/Model/BreadcrumbBuffer.swift`, `Shared/Services/CaptureService.swift` |
| Voice and phrases | `Shared/Model/SpokenConfirmation.swift`, `Passing/Views/VoicePickerView.swift`, `PhrasesView.swift` |
| Retention rules and clean-up | `Shared/Model/RetentionPolicy.swift`, `Passing/Services/RetentionService.swift` |
| Export | `Passing/Services/PinExport.swift`, `Passing/Services/ExportService.swift` |
| Haptic, tone and speech | `Passing/Services/CaptureFeedback.swift` |
| Review screens | `Passing/Views/PinListView.swift`, `PinDetailView.swift`, `RecentlyDeletedView.swift` |
| Tests | `PassingTests/` |
