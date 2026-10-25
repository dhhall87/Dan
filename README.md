# Passing

Capture things you pass while driving, then look them up later. One tap saves a pin, and identifying the thing happens afterwards. The full spec is in [CLAUDE.md](CLAUDE.md).

**Status:** Milestones 1–7 are done. The refreshed capture screen (design option A, tuned for iOS 27 on an iPhone 16 Pro) is built and waiting for its test run. See "Design refresh checklist".

## What it does so far

**Capture (Milestone 1)**
- **Simple (default):** the whole screen is one capture button, with the app icon's yellow pin.
- **Four zones:** `| Far left | Near left | road | Near right | Far right |` as full-height columns. Near zones are green, far zones blue. The narrow road in the middle, with your car on it, saves a pin with the side unknown.
- **Switching layouts:** Settings → Capture screen picks the one Passing opens with. To switch during a drive, tap the **Passing** title at the top (the line under it says **Simple** or **Four zones**). After more than 30 minutes away, Passing comes back on the Settings layout.
- **Add a note** (next to "+1 mi back"): Passing asks **"What's your note?"** and listens. What you say is saved as a note in Pins, under today, with no pin or location. Saying nothing saves nothing. It's voice only, because a text box can't appear on the driving screen. It needs speech permission, which Passing asks for only in Settings: turn on **Listen after tap** once (you can turn it off again afterwards). Until then the button just says how to turn it on.
- **New Note** (bottom of the Pins list): type a note, or tap the microphone on the keyboard to dictate it. With a group showing, the note goes into that group.
- **Move a pin** (a pin's screen in Pins → **Move Pin**): drag a satellite map until the crosshair is on the right building and save. Where your car was is kept; map links, Look Around, the town and exports use the new spot. A pin saved with no location can be placed this way too.
- **Notes** show in Pins with a note icon. They expire, can be kept (starred), grouped and deleted like pins, and open to an editable text field. Exports include them (CSV and JSON mark them `isNote`); the KML map file leaves them out, because they have no place.
- **GPS pill** in the title bar, above the **Passing** title: **GPS ready** (green), **Finding GPS…** (yellow), **Location asked on first pin** (gray), **Location off** (red) or **Precise Location off** (orange). Pins save in every state; the pill just says whether they'll have a position.
- **Save first:** a tap writes the pin immediately with no label. If GPS has no usable fix yet, the pin is still saved, marked "No location", and picks up the first good fix within 15 seconds. An old position is never used.
- **Approximate flag:** a pin is marked approximate when its total uncertainty is more than about 50 m: how far the car could have moved between the GPS reading and the tap (speed × time apart), combined with how precise the reading itself was. A parked car's older reading counts as exact.
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
- **+1 mi back** (the wide button at the bottom of the capture screen): one tap saves a pin 1 mile back along the road you just drove. Tap again within 4 seconds and the same pin moves to 2 miles, 3 miles, and so on, with a haptic and tone each time.
- **How it knows the road:** while the capture screen is open, Passing keeps a trail of the last ~25 miles in memory, a point every ~50 m. It's never saved and never recorded in the background.
- **On the map:** the pin's detail screen shows your car (blue), the estimate (orange "About here") and the road between them. Apple and Google Maps links go to the estimate.
- **Not enough trail yet** (app just opened): no estimate goes on the map. Instead the pin says "About 2 miles back the way you came. You were heading southwest, so look northeast of this spot."
- **Voice** (Settings → Spoken confirmation → Voice): every voice installed on the iPhone, best quality first, each with ▶︎ to preview. The default, **Best available**, uses the most natural voice installed for your language and switches by itself when you download a better one. Siri's own voices aren't available to apps. Better ones are free downloads in iOS Settings → Accessibility → Spoken Content → Voices. Your Personal Voice can be used too, with permission.
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

**Review polish (Milestone 6)**
- **Town names:** each pin picks up the town it was near ("Garden City, KS") from Apple Maps. It shows in the list row and on the pin's screen. Lookups happen only while you're looking at your pins and online, a few seconds apart, so capture never waits on them. Miles-back pins use the estimated spot.
- **Look Around:** tap **Show Look Around** on a pin's screen for Apple's street-level imagery of the spot, then tap the preview to look around. It loads only when you ask, needs the network, and rural roads often have no imagery.
- **Groups:** file pins in named groups, like "Road trip" or "Houses to check". A pin is in at most one group, and deleting a group keeps its pins.
  - **Make one anywhere:** **New Group…** is in the folder button's menu, a pin's touch-and-hold menu, the Group menu in Select mode, the pin's screen, and Manage Groups. Made from a pin (or a selection), the new group gets that pin. A name that's already taken just uses that group.
  - **Manage groups:** folder button → **Manage Groups…** to make, rename (tap) or delete (swipe left) groups.
  - **Show one group:** pick it from the same folder button.
  - **File a pin:** touch and hold it in the list → **Group**, or use the **Group** picker on its screen.
- **Map:** the map button on the Pins list shows the same pins on a map. Tap one for a card, then tap the card to open it.
- **KML export for Google My Maps:** Export → **KML (Google My Maps)**. Each pin becomes a placemark with its label, time, side, town and group. Pins without a location are left out, and the file says how many.
- **Recently Deleted → Select** recovers or deletes several pins at once (**Select All** is in the bar at the bottom).
- **Appearance** (Settings): System (the default, following the iPhone's Light/Dark setting), Light or Dark. The capture screen always stays dark, so it's never bright on the dash at night.
- **Exports follow what's shown.** With a group picked, JSON, CSV and KML contain just that group, and the file name says which. CSV and JSON now have a group column too.
- **Select several pins:** **Select** on the Pins list, tick pins (or **Select All**), then use the bar at the bottom: **Keep**, **Reviewed**, **Group**, or **Delete** (to Recently Deleted).

**Listen after tap (Milestone 7, optional, off by default)**
- Settings → **Labels by voice** → **Listen after tap**. After a tap on the capture screen, Passing asks **"What are you passing?"** and listens for a few seconds. Say what you saw ("red barn") and it becomes the label. Say nothing, "cancel" or "stop", and the pin stays unlabeled. Turn off **Ask "What are you passing?"** to get a short chime instead of the question.
- It stops listening about 1.5 seconds after you stop talking, after 6 seconds if you say nothing, and after 15 seconds at most. "Stop" or "cancel" ends it after about half a second. If the speech recognizer gives up on the silence early, Passing quietly starts it again, so the microphone stays on for the full 6 seconds.
- **Stop listening:** while Passing asks or listens, a big red **Stop listening** button takes the place of the **Passing** title (the GPS pill hides meanwhile). It turns the microphone off right away and keeps anything you'd already said. The Passing widgets turn into a big **Stop listening** button at the same time, so you can stop it from CarPlay. It never has to be pressed, and it doesn't move or cover the capture buttons.
- The pin is saved before Passing listens, so a missed or garbled answer never loses it. You can fix the label later in Pins.
- With **Spoken confirmation** on, Passing reads the label back ("red barn") instead of saying your phrase.
- Music pauses while it listens (or is lowered, with "Pause music while speaking or listening" off), so the microphone hears you rather than the radio.
- Speech is recognized on the iPhone and the audio never leaves it. iOS shows its orange microphone dot while Passing listens.
- Only taps on the capture screen listen. The widgets, Control Center and Siri work as before.

## Privacy and footprint

**What stays on the iPhone:** everything Passing saves. That means pins (where the car was, when, speed and direction, side and distance, label, town, group), the short stretch of road on miles-back pins, and settings. There's no account, analytics, ads or server. The App Store privacy label would be **Data Not Collected**. The App Store's required privacy declarations are in `Passing/Resources/PrivacyInfo.xcprivacy` and `PassingWidget/PrivacyInfo.xcprivacy`.

**Your controls** (Settings):
- **Precise location** (on by default). Off keeps only roughly where each pin was (within about half a mile) and its general direction: no speed and no miles-back route. Enough to find the town. It applies to the widgets and Control Center too.
- **Look up town names** (on by default). Off means pin locations never go to Apple Maps for town names.
- **Delete pins after exporting** (off by default). After an export is actually shared, the pins in it move to Recently Deleted, except kept ones. Pins still move there after 7 days either way.
- **Delete All Pins.** Erases every pin for good, including kept ones and Recently Deleted. Groups stay; delete them in Manage Groups (swipe left, Edit, or tap a group → Delete Group).
- **Exports never include speed.**

**What leaves it, and when:**
- **Town names:** each pin's location goes to Apple Maps to find its town. Settings → Privacy → **Look up town names** turns this off.
- **Maps and Look Around:** opening a map, or tapping Show Look Around, asks Apple Maps for imagery of that area.
- **Siri:** what you say to Siri goes through Siri, under your iPhone's Siri settings. Listen after tap stays on the iPhone.
- **Exports and map links:** only when you share an export or tap Open in Apple Maps / Google Maps (Google then gets that spot). Passing deletes its own copy of an export once it's shared. A KML file reaches Google only when you upload it yourself.

**How long it's kept:** pins move to Recently Deleted after 7 days unless kept, and Recently Deleted empties after 30. The miles-back trail lives in memory only. Clean-up also runs in the background now and then.

**With the iPhone locked:** the pin database uses iOS's standard protection (encrypted until you first unlock after a restart). That's what lets the widgets and CarPlay save pins while the phone is locked.

**Footprint:**
- **App size:** no bundled voices, maps or third-party code. The icon and tone are about 100 KB. A pin takes about 1 KB.
- **Battery:**
  - The capture screen is the main cost. It keeps the screen on and GPS running, and only while it's open.
  - Otherwise, GPS runs for a few seconds per Siri, widget or Control Center pin.
  - Nothing else runs in the background apart from the occasional clean-up.
- **Listen after tap** (off by default) uses the microphone and speech recognition for a few seconds per tap.
- **Maps and Look Around** are the heaviest screens for memory and data. Look Around loads only when you tap it.

## Run it

You need **Xcode 26 or newer**. The app runs on **iOS 26** and later, and is tuned for **iOS 27 on an iPhone 16 Pro**.

1. Open `Passing.xcodeproj`.
2. Pick the **iPhone 16 Pro** simulator (iOS 27) next to the Run button and press Run (⌘R). Press ⌘U to run the tests. If iPhone 16 Pro isn't in the list: **Window → Devices and Simulators → Simulators → +**, Device Type **iPhone 16 Pro**, OS Version **iOS 27**, then **Create**.
3. Give the Simulator a location. While the app runs, click the **location arrow** in Xcode's debug bar (the strip above the console) and pick **KansasDrive** for a moving car, or a city to stay parked. To use it on every run, choose **Product → Scheme → Edit Scheme… → Run → Options → Default Location**.

### The test drive

`TestRoutes/KansasDrive.gpx` is a recorded 16-mile drive at 65 mph: 8 miles east, then 8 miles north, about 15 minutes. Xcode replays it so the Simulator moves like a car, which makes "+1 mi back" testable at a desk. It's only for testing and isn't part of the app.

### Build and test from Terminal

```sh
xcodebuild -project Passing.xcodeproj -scheme Passing \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
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

## Milestone 6 manual test checklist

1. Pull, then ⌘U and ⌘R. **Your existing pins are all still there.** This update adds groups to the database, so this checks the upgrade worked.
2. **Town names:** open **Pins** (with your Mac online). Within a few seconds, rows with a location show a town after the side and distance. Open one: **Details → Town** shows it.
3. **Look Around:** set the Simulator's location to a city (location arrow in Xcode's debug bar → e.g. San Francisco), make a pin, and open it. The **Look Around** section shows street imagery. Tap it to look around. A pin in rural Kansas probably says there's no imagery; that's expected.
4. **Groups:** Pins → folder button → **Manage Groups…** → add **Road trip** and **Houses**. Adding a second "road trip" is refused.
5. Touch and hold a pin → **Group → Road trip**. The row shows a folder label "Road trip". Open another pin, set **Group** to Houses, and try **New Group…** too.
6. Folder button → **Road trip**. The title becomes "Road trip" and only that pin shows. Pick **All Pins** to see everything again.
7. **Delete a group:** Manage Groups → swipe left on **Houses** → Delete. Its pin is still in Pins, now with no group. If you were showing Houses, the list goes back to All Pins.
8. **Map:** tap the map button. Your pins appear on a map, with miles-back pins at their estimated spot. Tap one: a card appears, and tapping it opens the pin. Pick a group from the folder button: the map shows only that group.
9. **KML:** show **Road trip**, then Export → **KML (Google My Maps)** → **Save to Files**. On your Mac, go to Google My Maps (google.com/mymaps) → **Create a new map** → name it **Passing pins** → **Import** → choose the file. The pin appears with its label, and clicking it shows the time, side, town and group.
10. Export → **CSV** with All Pins showing. The file has a **group** column.
11. Tap the Pin widget on the home screen. The new pin shows up in Pins as before.

## Milestone 7 manual test checklist

The Simulator uses your Mac's microphone. It usually has no on-device speech model, so there (only) recognition may go through Apple's servers. On an iPhone it's on-device only.

1. Pull, then ⌘U and ⌘R.
2. Settings → **Labels by voice** → turn on **Listen after tap**. iOS asks for the microphone and for speech recognition: allow both. The switch stays on.
3. On the capture screen, tap. Passing asks "What are you passing?". Say "red barn". About a second and a half after you stop, you feel a haptic. In **Pins**, the new pin is labeled "red barn".
4. Tap and say nothing. The orange microphone dot stays for about 6 seconds after the question, then listening stops with no sound or haptic. The pin is there, "Unlabeled". Try again, wait about 5 seconds, then say "barn": the pin gets "barn".
5. Tap and say "stop". Listening ends within about a second and the pin stays unlabeled.
6. **Stop button:** tap, and while Passing asks or listens, tap the red **Stop listening** at the top of the screen. The question stops (if it was still talking), the microphone turns off (the orange dot goes away), and the button disappears. Try it again after saying "silo": the pin keeps "silo".
7. **Stop from CarPlay:** open the CarPlay window (I/O → External Displays → CarPlay) with a Passing widget on its Widgets screen. Tap on the phone's capture screen: within a second or two the CarPlay widget turns into **Stop listening**. Tap it: Passing stops listening, and the widget goes back to normal. **Tell me how quickly the widget changes**, because widget refresh timing isn't something Apple promises.
8. Settings → turn off **Ask "What are you passing?"**. A tap now gives a short chime instead, then listens.
9. Turn on **Spoken confirmation**, tap, and say "water tower". Passing says "water tower" back.
10. **+1 mi back:** tap it twice within 4 seconds, then say "diner". You get one pin, "2 mi back", labeled "diner".
11. **Music:** play something in Music. Tap a zone: the music pauses while Passing asks and listens, and comes back after. Turn off **Pause music while speaking or listening** and try again: the music just gets quieter.
12. Tap one zone, say "barn", then quickly tap another zone and say "silo". The first pin is "barn" and the second "silo".
13. iOS Settings → Privacy & Security → Microphone → turn Passing off. Open Passing's Settings: an orange note says listening needs access. Taps still save pins with the normal tone. Turn the microphone back on.
14. Tap the Pin widget when Passing isn't listening: it saves silently and doesn't listen.
15. **New Group everywhere:** folder button → **New Group…**; touch and hold a pin → **New Group…** (the pin goes into it); Select a few pins → Group → **New Group…** (they all go into it); Manage Groups → **New Group…**. Typing a name that already exists files into that group instead of making a duplicate.
16. **Select several pins:** Pins → **Select**. Tick three pins: the title says "3 Selected". Tap the star (**Keep**): all three get a star. Tap the folder (**Group**) → a group: all three move into it. Tap the trash (**Delete**): they move to Recently Deleted. **Select All** / **Deselect All** and **Done** work as expected, and opening a pin is back to normal after **Done**.

## Privacy settings checklist

1. Pull, then ⌘U and ⌘R.
2. Settings → Privacy → turn off **Precise location**. Make a pin. In Pins its accuracy says "±0.6 mi · approximate". Its screen shows no speed, and its coordinates have two decimal places. Tap the Pin widget: that pin is rough too. Turn **Precise location** back on: new pins are exact again, with speed.
3. With precise location on, drive the KansasDrive route a few minutes and tap **+1 mi back**: the blue route still shows. With it off, a miles-back pin has a rough orange estimate and no route.
4. Export a CSV and a JSON: there's no speed column or field.
5. Settings → Keeping pins → turn on **Delete pins after exporting**. Star one pin. Export CSV → **Save to Files**. Back in Pins, the exported pins are in Recently Deleted, apart from the starred one. Export again but **cancel** the share sheet: nothing moves. Turn the setting off again.
6. Settings → Privacy → **Delete All Pins…** → **Delete All Pins**. Settings says how many were deleted. Pins and Recently Deleted are empty, and your groups are still in the folder menu.
7. Manage Groups: **Edit** shows delete buttons. Tapping a group offers **Delete Group** next to Save. Deleting a group keeps its pins.

## Appearance and Recently Deleted checklist

1. Pull, then ⌘U and ⌘R.
2. Settings → **Appearance** shows **System** selected. Switch the Simulator to Light (Settings app → Developer → Dark Appearance off, or ⇧⌘A in the Simulator): Pins, a pin's screen and Settings turn light; the capture screen and its title bar stay dark. Pick **Dark** in Passing's Settings: the Settings sheet itself turns dark straight away, and so do Pins and a pin's screen, even with the iPhone in Light. Pick **Light** with the iPhone in Dark: everything but the capture screen turns light. Set it back to **System**: it follows the iPhone again.
3. In light mode, check the yellow-ish highlights (Recover buttons, ticks, links) are readable. They switch to a deeper amber in light mode.
4. Delete three pins, then open **Recently Deleted** → **Select**. Tick two → **Recover**: both are back in Pins. Select the last one → **Delete Now** → confirm: it's gone. **Select All** / **Deselect All** work, and **Done** brings back the per-pin Recover buttons.

## Design refresh checklist

1. Pull, then ⌘U. Pick the **iPhone 16 Pro** simulator (iOS 27) and ⌘R.
2. **Simple:** a navy button with the yellow pin, **Pin it** and **Tap anywhere**. Tap it: the tone plays and nothing else changes.
3. **GPS pill:** in the Simulator choose **Features → Location → None**: the pill says **Finding GPS…** (yellow) within about 10 seconds. Pick **KansasDrive** in Xcode's location menu: **GPS ready** (green) within a second or two. In the iOS Settings app → Passing → Location → **Never**: **Location off** (red), and a tap still saves a "No location" pin. Set it back to **While Using the App**. On a fresh install, before the first pin, it says **Location asked on first pin** (gray).
4. **Title button:** under the GPS pill, the title says **Passing** (big and bold) with **⇄ Simple** under it in yellow. Tap it: the screen switches to Four zones and the line says **Four zones** (on your iPhone you also feel a light click). Tap again: back to Simple.
5. **Four zones:** the middle is a gray road with white edge lines, a dashed yellow center line and the car near the bottom. Tap each column and the road, then check side and distance in Pins: far left, near left, unknown, near right, far right.
6. **Default:** Settings → Capture screen → **Four zones**: the capture screen shows Four zones straight away. Set it back to **Simple**. Switch to Four zones with the title, then quit Passing (swipe it away in the app switcher) and reopen: it's back on Simple. Switch again, go to the Home Screen for a minute and come back: still Four zones.
7. **Listen after tap** on: tap a zone. The **Passing** title turns into a big red **Stop listening** button and the GPS pill hides. Both come back when listening ends, and the capture buttons don't move.
8. **+1 mi back:** a rounded button at the bottom left, with a yellow arrow. A tap, then quick extra taps, still give 1, 2, 3 miles back.
9. **Landscape:** rotate the Simulator (⌘→). Everything fits, and the Simple pin shrinks to make room. Rotate back.
10. **Widgets:** the **Pin** widget shows the yellow pin. If it still shows the old symbol, remove it and add it again. Check both widgets in the CarPlay window too.
11. **Light mode:** with Settings → Appearance → Light, the capture screen and its title bar stay dark.
12. **Pins by day:** each day has its own card under a bold heading (**Today** or **Yesterday** with the date beside it, then dates) with a pin count. To see it without waiting a day: make a few pins, then Settings → Testing → **Clock: +1 day**. Those pins move under **Yesterday**. New pins still use the real time, so they join them; the test clock only moves "now", not when pins were made. Set it back to 0.
13. **Notes:** on the capture screen tap **Add a note**. Passing asks "What's your note?". Say "call about the farm for sale": in Pins, a note with that text appears under Today, with a note icon and no map. Tap **Add a note** again and say nothing: no empty note appears. In Pins tap **New Note** at the bottom, type (or dictate with the keyboard's microphone) and tap **Save**. Open a note: you can edit the text, star it, group it and delete it. With speech permission never granted, **Add a note** says how to turn it on and saves nothing.
14. **Move a pin:** open a pin in Pins → **Move Pin**. The map opens on satellite with an orange crosshair. Drag it onto the right building and tap **Save**. The pin's map shows the car (blue) and the new spot (orange); **Open in Apple Maps** goes to the new spot, the town is looked up again, and the list says "Moved by you". A "No location" pin offers **Place on Map** instead. **Where my car was** jumps back to the car.
15. **On your iPhone 16 Pro, parked:** check the screen is easy to read in the mount, in daylight and at night, and that the title button isn't easy to hit by accident. The Action Button's **Quick Pin** works as before.

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
- **Capture colors come from the app icon** (navy, verge green, deep blue, asphalt, pin yellow). Near and far differ in brightness as well as color, so they're easy to tell apart at a glance and for color-blind drivers, and nothing is glaring at night.
- **Softly shaded capture buttons, not Liquid Glass.** Each zone is a little lighter at the top and darker at the bottom, with a faint edge, but keeps its full color through the middle where the words are, so contrast doesn't drop. iOS 27 adds a slider that changes how see-through glass is, and the buttons you hit while driving shouldn't change with it. Glass is only on the title-bar buttons (iOS draws those) and the GPS pill.
- **Still runs on iOS 26.** It's tuned for iOS 27 and the iPhone 16 Pro, but the minimum stays iOS 26, so iPhones that haven't updated can still install it. Nothing in the app needs iOS 27 yet.
- **The title switch lasts for the drive.** It resets when Passing is reopened or comes back after more than 30 minutes away, so Settings stays the layout Passing opens with.
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
- **GPS never runs in the background.** It runs while the capture screen is open, stops the moment Passing goes to the background, and otherwise only runs for a few seconds per Siri, widget or Control Center pin. No "Always" permission. Those pins can take a few seconds to get a reading, and occasionally get none, but GPS isn't using battery the rest of the time.
- **No "+1 mi back" on the widgets.** It needs the trail, which only exists while the app's capture screen is open.
- **The grid widget is 2x2, unlike the phone screen.** The spec asks for that, and a small widget is too narrow for five columns you can hit while driving.
- **No automatic Apple Maps Guide:** Apple doesn't let apps create Guides or add places to them. Milestone 6 adds a KML export that Google My Maps turns into a "Passing pins" map. Each pin also keeps "Open in Apple Maps", where you can tap "Add to Guide" yourself.

- **Town names are looked up lazily**, at most 20 each time you open the list, 1.5 seconds apart, because Apple limits how fast apps can ask. Pins Apple has no town for are skipped until the next launch. Offline, nothing happens until next time.
- **Pins in Recently Deleted keep their group**, so recovering one puts it back where it was. Group counts only include active pins.
- **KML placemarks go where map links go:** the estimated spot for miles-back pins, otherwise where the car was.
- **Listen-after-tap is now its own optional Milestone 7.** It's the only remaining piece that changes how capture works, and it needs microphone and speech-recognition permission.

- **Listening only follows taps on the capture screen.** Widgets and Control Center stay silent per the spec, and Siri asks its own question.
- **The question (or chime) always plays when listening**, even with the tone turned off, because it's the cue to start talking.
- **The Stop listening button is the one thing that appears on the capture screen after a tap**, at your request. It takes the title's place, at the same height, so it never moves or covers a capture button, and it never has to be pressed.
- **Microphone and speech permission are asked for in Settings**, when you turn listening on, so no permission prompt can appear on the capture screen.
- **`SFSpeechRecognizer` rather than iOS 26's new `SpeechAnalyzer`.** It's simpler, still supported, and on-device on iPhone. If the iPhone can't recognize its language on the device, the setting stays off rather than sending audio to a server.

## Project layout

| Piece | Where |
| --- | --- |
| Code used by both the app and the widget | `Shared/` |
| Capture screen | `Passing/Views/CaptureView.swift`, colors and pin in `Shared/Views/PassingColors.swift` and `PinGlyph.swift` |
| Layout switch and GPS pill | `Passing/Model/CaptureModeChoice.swift`, `Passing/Model/GPSStatus.swift`, title button in `Passing/App/PassingApp.swift` |
| Single save entry point | `Shared/Services/CaptureService.swift`, wired up per target in `Passing/Services/CaptureService+App.swift` and `PassingWidget/CaptureService+Widget.swift` |
| Siri, Shortcuts, Action Button | `Passing/Intents/CaptureIntents.swift`, `Shared/Services/IntentCapture.swift` |
| Widgets and Control Center | `PassingWidget/`, `Shared/Intents/WidgetIntents.swift` |
| GPS and freshness rules | `Shared/Services/LocationProvider.swift`, `Shared/Model/FixPolicy.swift` |
| Pin model and App Group store | `Shared/Model/Pin.swift`, `Shared/Services/SharedStore.swift`, `Shared/Services/AppGroup.swift` |
| Miles back (trail and estimate) | `Shared/Model/BreadcrumbBuffer.swift`, `Shared/Services/CaptureService.swift` |
| Voice and phrases | `Shared/Model/SpokenConfirmation.swift`, `Passing/Views/VoicePickerView.swift`, `PhrasesView.swift` |
| Retention rules and clean-up | `Shared/Model/RetentionPolicy.swift`, `Passing/Services/RetentionService.swift` |
| Export (JSON, CSV, KML) | `Passing/Services/PinExport.swift`, `Passing/Services/ExportService.swift` |
| Haptic, tone and speech | `Passing/Services/CaptureFeedback.swift` |
| Listen after tap | `Passing/Services/SpeechListener.swift`, `Passing/Model/ListenPolicy.swift`, `Passing/Services/CaptureFeedback.swift` |
| Review screens | `Passing/Views/PinListView.swift`, `PinDetailView.swift`, `PinsMapView.swift`, `RecentlyDeletedView.swift` |
| Groups | `Shared/Model/PinGroup.swift`, `Passing/Services/PinGroups.swift`, `Passing/Model/GroupFilter.swift`, `Passing/Views/GroupsView.swift` |
| Town names | `Passing/Services/PlaceNameService.swift`, `Passing/Model/PlaceNaming.swift` |
| Tests | `PassingTests/` |
