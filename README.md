# Passing

Capture things you pass while driving, then look them up later. One tap saves a pin, and identifying the thing happens afterwards. The full spec is in [CLAUDE.md](CLAUDE.md).

**Status:** Milestones 1–7 are done. Routes (Milestone 8), the Apple Watch app (Milestone 9) and version 1.1's photos and Silent-switch tone are built and waiting for their test runs, as is the refreshed capture screen (design option A, tuned for iOS 27 on an iPhone 16 Pro). See the checklists for Milestone 8, Version 1.1, Milestone 9 and the design refresh.

## What it does so far

**Capture (Milestone 1)**
- **Simple (default):** the whole screen is one capture button, with the app icon's yellow pin.
- **Four zones:** `| Far left | Near left | road | Near right | Far right |` as full-height columns. Near zones are green, far zones blue. The narrow road in the middle, with your car on it, saves a pin with the side unknown.
- **Switching layouts:** Settings → Capture screen picks the one Passing opens with. To switch during a drive, tap the **Passing** title at the top (the line under it says **Simple** or **Four zones**). After more than 30 minutes away, Passing comes back on the Settings layout.
- **Add a note** (next to "+1 mi back") is dimmed for the first 5 seconds after Passing opens or comes back from the background, so a stray touch while picking up the phone doesn't start one. Then Passing asks **"What's your note?"** and listens. What you say is saved as a note in Pins, under today, with no pin or location. Saying nothing saves nothing. It's voice only, because a text box can't appear on the driving screen. It needs speech permission, which Passing asks for only in Settings: turn on **Listen after tap** once (you can turn it off again afterwards). Until then the button just says how to turn it on.
- **New Note** (bottom of the Pins list): type a note, or tap the microphone on the keyboard to dictate it. With a group showing, the note goes into that group.
- **Needs Review** (top of Pins, and in the folder button's menu): pins you saved from the widget, CarPlay or Control Center, which have no label, until you mark them Reviewed, give them a label, or file them in a group (labelling or filing one marks it Reviewed). Pins from the capture screen and Siri don't go in. It's a smart list, not a group, so a pin can be in "Road trip" and still need review. In the rest of the list those pins have a faint amber background and a tray icon, so they're easy to spot. In Needs Review, swipe right to mark a pin Reviewed and it leaves the list. Elsewhere, swipe right shows Keep (full swipe) and Reviewed.
- **Review reminders** (Settings → Needs Review → Review Reminders, off by default): after a widget pin, Passing reminds you to look at Needs Review the next morning at 8:00 (change the time), and/or when you arrive at work or home. Set a place with **Use My Current Location** while you're there, or search for its address. Reminders are only set while something is waiting, and reviewing everything cancels them. Tapping one opens Needs Review. iOS watches for your arrival itself, so Passing doesn't track you or run in the background, and it needs no extra location permission. If a reminder arrives while Passing is open, it goes quietly into Notification Center with no banner over the capture screen.
- **What's here?** (a pin's screen → **Find Places Near This Pin**): the seven closest businesses and landmarks Apple Maps lists around the pin, with their type and distance. **Look Farther** widens the search to about a mile and lists up to 15. Tap the one you passed: the pin takes its name, moves to it, and **Open in Apple Maps** opens that place's own card (hours, photos, **Add to Guide**) instead of a dropped pin. **Open in Google Maps** searches for its name and town. The pin's location goes to Apple only when you tap Find.
- **Search here in Apple Maps:** a labeled pin without a chosen place also gets **Search “diner” Here in Apple Maps**, which looks for that word right around the pin.
- **Move a pin:** on a pin's screen, tap **Move** on the map, or touch and hold the pin in the list → **Move Pin…**. Drag a satellite map until the crosshair is on the right building and save. Where your car was is kept; map links, Look Around, the town and exports use the new spot. A pin saved with no location shows **Place on Map** instead.
- **Notes** show in Pins with a note icon. They expire, can be kept (starred), grouped and deleted like pins, and open to an editable text field. Exports include them (CSV and JSON mark them `isNote`); the KML map file leaves them out, because they have no place.
- **GPS pill** in the title bar, above the **Passing** title: **GPS ready** (green), **Finding GPS…** (yellow), **Location asked on first pin** (gray), **Location off** (red) or **Precise Location off** (orange). Pins save in every state; the pill just says whether they'll have a position.
- **Save first:** a tap writes the pin immediately with no label. If GPS has no usable fix yet, the pin is still saved, marked "No location", and picks up the first good fix within 15 seconds. An old position is never used.
- **Approximate flag:** a pin is marked approximate when its total uncertainty is more than about 50 m: how far the car could have moved between the GPS reading and the tap (speed × time apart), combined with how precise the reading itself was. A parked car's older reading counts as exact. A reading that arrives more than 3 seconds after the tap is always approximate, because the car may have braked after passing the thing.
- **Non-visual confirmation:** a haptic and a short tone. Spoken "Left, far, saved" is optional. Repeat taps within 0.75 s are ignored. The screen dims and locks on your usual Auto-Lock schedule (GPS stops when it locks); Settings → **Keep screen on** keeps it lit for a dash mount.
- **Review:** pins grouped by day. Each pin's detail screen has a map, editable label/side/distance, a **Notes** field for anything else to remember (exports include it), **Photos**, Reviewed, and Apple Maps / Google Maps links. Coordinates, accuracy, the GPS fix, speed and where it was saved from are under **More Details**; open or close it once and every pin follows.

**Retention and export (Milestone 2)**
- **7-day expiry:** pins move to **Recently Deleted** 7 days after you pin them. Each pin's row counts down ("Expires in 3 days").
- **Keep:** swipe right on a pin, or use the Keep toggle on its detail screen, to star it. Kept pins never expire.
- **Keep records indefinitely** (Settings) stops expiry for every pin.
- **Recently Deleted** (bottom of the Pins list): tap **Recover** on a pin, swipe left to delete it now, or use **Delete All Now**. Pins there are deleted for good 30 days after they arrive. That happens even with "Keep records indefinitely" on.
- **Deleting** a pin (swipe left, or Delete on its detail screen) moves it to Recently Deleted.
- **Export** (share button on the Pins list): JSON or CSV of all active pins, through the share sheet (AirDrop, Files, Mail, …).
- **When the clean-up runs:** on launch, whenever the app comes back to the front, when you open the Pins list, and in the background when iOS allows. It never runs in the middle of an export.

**Miles back and voice (Milestone 3)**
- **+1 mi back** (the wide button at the bottom of the capture screen) moves the pin you just dropped a mile back along the road you drove, measured from where you dropped it. It keeps the side and distance you tapped. It works for about 10 seconds after a pin, and each extra tap within about 5 seconds of the last moves it another mile, with a haptic and tone each time. Drop a pin, wait 6 seconds, tap +1, wait 4 seconds, tap +1 again: that pin is 2 miles back. The rest of the time the button is dimmed and never makes a pin of its own; a tap then gives a warning buzz (and "Pin something first." with spoken confirmation on).
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
- **Control Center:** a **Pin That** control. It can also go on the Lock Screen, or on the Action Button on recent iPhones. To put it on the Lock Screen: press and hold the Lock Screen, tap **Customize**, then **Lock Screen**, remove the flashlight or camera button with its **−**, tap **+** in its place and choose Passing's **Pin That**. (Passing's widgets can't go on the Lock Screen: it only takes its own smaller widget sizes, which Passing doesn't have.)
- Widget and Control Center pins are **silent**: no tone, no voice. The moment you tap a widget button, the whole widget turns green with a tick and **Saved**, for about a second and a half (longer if it's still waiting for a GPS reading, at most 15 seconds), then the buttons come back. Only a problem stays on the button you tapped: amber **No location** if no GPS reading arrived, or red **Not saved** if the pin couldn't be written at all. Passing keeps it and writes it with the next save that works, so tapping again can leave two pins; if it keeps happening, close and reopen Passing. Labels get added later in Pins.
- **Pin Left or Right widget** (medium, for the Home Screen and medium Smart Stacks): split down the middle into a left half and a right half with arrows, and a **Passing** label on the seam. Each half saves that side (set the distance later in Pins if you like). The label is just a label: a tap on it counts for the half under your finger. CarPlay only shows small widgets, so use the small ones there.
- **Location:** when you add a widget, iOS asks whether Passing's widgets may use your location. Allow it, and Passing's location setting becomes "While Using the App or Widgets". Each widget tap saves the pin first, then waits up to 15 seconds for a GPS reading, as Siri does.
- Repeat taps on the same widget button within 0.75 s count as one, as on the capture screen.
- **Pins updates by itself:** if Pins is open on the phone while you tap a widget (say, in CarPlay), the new pin appears at the top as soon as it's saved. If you're busy in Pins (Select, the map, a note, an export, Move Pin, an open pin, or scrolled down to older pins), it waits and appears once you're done, so nothing you were doing gets reset.

**Photos (1.1)**
- On a pin's screen (or a note's), **Photos** → **Take Photo** opens the camera, and **Choose Photo** picks from your library (up to 6 per pin). Tap a photo to see it full screen and swipe between them; **Delete Photo** removes one.
- Passing keeps a smaller copy of each (about 0.3–0.5 MB), without the photo's hidden location. The original in your library isn't touched.
- Photos go when their pin does: after 7 days unless it's kept, with Recently Deleted, and with Delete All Pins. Exports say how many photos a pin has (`photos` in CSV, `photoCount` in JSON) but don't include them.
- Pins with photos show a small photo icon in the list. Only while reviewing: there's no camera on the capture screen.
- Camera permission is asked the first time you tap Take Photo. Choose Photo needs no permission.

**Review polish (Milestone 6)**
- **Town names:** each pin picks up the town it was near ("Garden City, KS") from Apple Maps. It shows in the list row and on the pin's screen. Lookups happen only while you're looking at your pins and online, a few seconds apart, so capture never waits on them. Miles-back pins use the estimated spot.
- **Look Around:** tap **Show Look Around** on a pin's screen for Apple's street-level imagery of the spot, then tap the preview to look around. It loads only when you ask, needs the network, and rural roads often have no imagery.
- **Groups:** file pins in named groups, like "Road trip" or "Houses to check". A pin is in at most one group, and deleting a group keeps its pins.
  - **Make one anywhere:** **New Group…** is in the folder button's menu, a pin's touch-and-hold menu, the Group menu in Select mode, the pin's screen, and Manage Groups. Made from a pin (or a selection), the new group gets that pin. A name that's already taken just uses that group.
  - **Manage groups:** folder button → **Manage Groups…** to make, rename (tap) or delete (swipe left) groups. Tap **Edit** and drag the handles to put them in your order; the folder menu and a pin's group picker follow it. New groups go at the bottom.
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

**What stays on the iPhone:** everything Passing saves. That means pins (where the car was, when, speed and direction, side and distance, label, town, group, photos), the short stretch of road on miles-back pins, and settings. There's no account, analytics, ads or server, and Passing doesn't sync anything itself. Like any app's data, though, pins are part of your iPhone's own backups (iCloud Backup, or a backup to a computer). The App Store privacy label would be **Data Not Collected**. The App Store's required privacy declarations are in `Passing/Resources/PrivacyInfo.xcprivacy` and `PassingWidget/PrivacyInfo.xcprivacy`.

**Your controls** (Settings):
- **Precise location** (on by default). Off keeps only roughly where each pin was (within about half a mile) and its general direction: no speed and no miles-back route. Enough to find the town. It applies to the widgets and Control Center too. It only changes pins saved from then on: pins already saved keep their exact position (delete them if that matters).
- **Look up town names** (on by default). Off means pin locations never go to Apple Maps for town names.
- **Delete pins after exporting** (off by default). After an export is actually shared, the pins in it move to Recently Deleted, except kept ones. Only pins that are in the file move: a KML file leaves out notes and pins without a location, so those stay. Pins still move there after 7 days either way.
- **Delete All Pins.** Erases every pin for good, including kept ones and Recently Deleted. Groups stay; delete them in Manage Groups (swipe left, Edit, or tap a group → Delete Group). Work and Home for review reminders stay too; remove them in Settings → Review Reminders.
- **Exports never include speed.** JSON exports do include the stretch of road on miles-back pins (CSV and KML don't).

**What leaves it, and when:**
- **Town names:** each pin's location goes to Apple Maps to find its town. Settings → Privacy → **Look up town names** turns this off.
- **Maps and Look Around:** opening a map, or tapping Show Look Around, asks Apple Maps for imagery of that area.
- **Routes:** a route's stops go to Apple when you tap Show Road Route or Open in Apple Maps, and to Google when you tap a Google Maps link.
- **Siri:** what you say to Siri goes through Siri, under your iPhone's Siri settings. Listen after tap stays on the iPhone.
- **Exports and map links:** only when you share an export or tap Open in Apple Maps / Google Maps (Google then gets that spot). Passing deletes its own copy of an export once it's shared. A KML file reaches Google only when you upload it yourself.

**Apple Watch:** pins made on the watch stay on the watch until Passing on the iPhone has saved them, then the watch deletes its copy. They go directly between your watch and iPhone, never through a server. The watch uses its own location only while Passing is open on it (and for up to 15 seconds after a tap).

**Drive log** (off unless you turn it on): timings and outcomes only, never locations, labels, notes or speeds. It stays on the iPhone until you share it.

**How long it's kept:** pins move to Recently Deleted after 7 days unless kept, and Recently Deleted empties after 30. The rolling trail of where you've driven lives in memory only; a miles-back pin keeps just the stretch of road it measured, and goes when the pin does. Clean-up also runs in the background now and then.

**With the iPhone locked:** the pin database uses iOS's standard protection (encrypted until you first unlock after a restart), so it can still be written while the phone is locked. CarPlay widget buttons work with the iPhone locked: on the October 27 drive, a locked-phone CarPlay tap saved its pin with a 10 m position at once.

**Footprint:**
- **App size:** no bundled voices, maps or third-party code. The icon and tone are about 100 KB. A pin takes about 1 KB, plus about 0.3–0.5 MB per photo you add.
- **Battery:**
  - The capture screen is the main cost. It keeps the screen on and GPS running, and only while it's open.
  - Otherwise, GPS runs for a few seconds per Siri, widget or Control Center pin.
  - On the watch, GPS runs only while Passing is on its screen, plus up to 15 seconds after a tap.
  - Nothing else runs in the background apart from the occasional clean-up.
- **Listen after tap** (off by default) uses the microphone and speech recognition for a few seconds per tap.
- **Maps and Look Around** are the heaviest screens for memory and data. Look Around loads only when you tap it.

## Which version is installed

Settings → About → **Version**, for example "1.0.1 (build 2)". Each update steps it (1.0.1, 1.0.2, …; 1.1 for a bigger batch), and the drive log notes the version each time Passing opens, so a shared log shows which drives used which version.

## Drive log (for real-drive feedback)

Settings → Feedback → **Drive Log** → turn on **Keep a drive log**. From then on Passing notes how each drive went, on the iPhone only:

- **Every pin:** where it came from (phone, Siri, widget, Control Center, Apple Watch), whether GPS was ready at the tap, how long it waited for a reading if not, how accurate the reading was, whether it's approximate, and whether it saved.
- **Siri and widget requests:** how long each took from start to finish, and how Siri's "What did you see?" went (answered, nothing said, cancelled or failed, with the error).
- **GPS:** how long it ran each time (with the capture screen, or a short burst for Siri and widgets), and when it was skipped because location or Precise Location was off.
- **Miles back:** whether the pin landed on the trail or fell back to words, and every trail restart with its reason (a gap that could hide a turn, a GPS jump, or a long break).
- **Apple Watch pins:** how long after the tap each one reached the iPhone.
- **Speed of the app:** how long Passing took to open and the database to load, save failures, clean-up runs that took a while, and town lookups.

It never records where you were, labels, notes or speeds. The Drive Log screen shows a summary and the newest 100 events (pull down to refresh). **Share** makes a text file with the summary and every event, ready to send or paste. **Clear** deletes it. Each part of the app keeps about its newest 2,500 events. Turning it off stops recording and keeps what's there.

**After a drive:** note roughly when you tapped things (for example, "8:14 widget in CarPlay, phone locked"), then share the log. A widget tap with no matching event means the button didn't run at all.

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
2. Tap **Pin it**, then **+1 mi back** within 10 seconds. In **Pins**, that one pin says "1 mi back". Open it: the map shows the blue car, the orange "About here" about a mile back along the road, and a blue line between them. **Open in Google Maps** goes to the orange spot.
3. Back on the capture screen, tap **Pin it**, then **+1 mi back** three times, less than 5 seconds apart. (Leaving the capture screen pauses the trail. If the car moved more than about 300 m meanwhile, which the simulated drive does in about 10 seconds, the trail starts fresh, so stay on the capture screen for about 3 minutes first.) You get one pin, "3 mi back", with a haptic and tone on each tap.
4. Wait 15 seconds: **+1 mi back** dims. Tap it: a warning buzz, and no new pin.
5. Force-quit and reopen, wait about 20 seconds on the moving drive, then tap **Pin it** and **+1 mi back**. The trail is shorter than a mile, so the pin is a **Rough guess**: the blue line shows the road recorded so far, and a dashed orange line carries on straight to the orange pin a mile back.
6. Settings → turn on **Spoken confirmation** → **Voice**. Tap ▶︎ on a few voices, then tap one to choose it. The Simulator has fewer voices than a real iPhone.
7. **Phrases:** add "Got it boss" and "I'll look this up later", and swipe left to remove "Saved". Tap ▶︎ to hear each one. Back in Settings, tap **Preview**.
8. On the capture screen in Four zones, tap a few zones. You should hear things like "Left, far. Got it boss." Turn off **Say side and distance first** and you just hear the phrase.
9. Tap a zone, then **+1 mi back** twice quickly. You hear your phrase, then "1 mile back", then "2 miles back".

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
9. **No location:** iOS Settings → Privacy & Security → Location Services → Passing → choose **While Using the App** (not "…or Widgets"). Tap the Pin widget. It shows **No location** (straight away if iOS tells the widget location is off, otherwise after about 15 seconds), and the pin is saved anyway with no position. Set it back to **While Using the App or Widgets**.
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

## Routes (Milestone 8)

Plan a trip through pins you saved: Pins → **Select**, then tap pins in the order you want to visit them. Each shows its number (1, 2, 3…). Tap **Route** in the bottom bar.

- **Stops:** in the order you picked them; tap **Edit** to drag them into another order. Notes and pins with no location are left out, and the screen says how many. A route takes up to 15 pins.
- **Start and end:** the first and last pin unless you choose otherwise. The start can also be **Where you are**; either end can be **Home** or **Work** (the places set for review reminders) or **An address…** (type it and tap **Find**).
- **Driving or Walking.**
- **Map:** the stops numbered, joined by straight dashed lines, with the straight-line distance. **Show Road Route** asks Apple Maps for the real route, leg by leg, and shows the total distance and time.
- **Open in Apple Maps:** the whole route as one multi-stop trip. **Open in Google Maps:** Google takes up to 9 stops between its start and end, so a longer route opens in parts, each starting where the last ended.
- **Privacy:** stop locations go to Apple only when you tap Show Road Route or Open in Apple Maps, and to Google only when you tap a Google Maps link. A typed address goes to Apple Maps when you tap Find.
- Planned as part of a future Passing Pro; for now it's free in your own build.

## Milestone 8 manual test checklist

1. Make 4 pins in different places (in the Simulator: Features → Location → Custom Location between taps, or use the **Move** button on each pin).
2. Pins → **Select**. Tap three pins in any order: they show 1, 2, 3 in the order you tapped them. Untap the middle one: the numbers close up (1, 2). Tap it again (now 3), then tap **Route**.
3. The route screen lists the stops in your order and the map numbers them, joined by dashed lines, with a straight-line distance under the map.
4. **Edit** → drag the last stop to the top → **Done**: the map renumbers.
5. **Start → Where you are**: the map footer says the Maps apps start from where you are. **End → An address…**: type a town and tap **Find**; it shows a green tick and the map adds an **E** marker.
6. **Show Road Route**: blue road lines replace the dashes, with Distance and Time. Change **Travel** to Walking: the road route clears (tap again for the walking route).
7. **Open in Apple Maps**: Maps opens directions through every stop, in order. **Open in Google Maps** (Safari, or the Google Maps app if installed): the same stops.
8. Select 12 pins (or 11 plus an address end): Google Maps shows **part 1 of 2** and **part 2 of 2**; part 2 starts where part 1 ends.
9. Select a note and a "No location" pin with two real pins: the route has the two real pins and says 2 picked items have no location.

## Version 1.1.2 checklist (CarPlay widget, rough +1 pins, watch)

1. **CarPlay 2x2 and Pin widgets:** tap a button. The whole widget goes green with **Saved**, then the buttons come back by themselves after about a second and a half, without touching the screen again. Same on the iPhone's Home Screen.
2. **Short trail:** open Passing on the moving drive (or after the phone had locked), wait about 20 seconds, then tap a zone and **+1 mi back**. The pin's map now shows an orange **Rough guess** a mile back: blue for the road recorded, dashed orange for the straight-line rest. The note under the map says it's a rough guess. **Move** still lets you put it right.
3. Parked with nothing recorded (stand still, open Passing, pin, +1): no direction to go on, so it still says "About 1 mile back the way you came…" with no orange pin.
4. **Watch:** follow "Installing it" under Apple Watch, then the Milestone 9 checklist. Add the **Passing** complication to a watch face and tap it: Passing opens. On a face that tints its complications, the pin takes the face's color (1.1.3).
5. Pins from before this version keep what they had. For an older "+1" pin without an orange pin (like the haircut one), use **Move** to place it.

## Version 1.1.1 checklist (+1 mi back and Add a note)

1. Open Passing: **Add a note** is dimmed for about 5 seconds, and tapping it then does nothing. Then it lights up and works. Go to the Home Screen and back: dimmed again for 5 seconds. Pulling down Control Center doesn't dim it.
2. **+1 mi back** is dimmed until you pin something. Tap it now: a warning buzz, and no pin appears in Pins.
3. In Four zones tap **Near left**, wait about 6 seconds, tap **+1 mi back**, wait about 4 seconds, tap it again. In Pins there's one pin: "Left, near", "2 mi back", with the orange estimate 2 miles back from where you tapped.
4. Tap **Pin it**, wait 12 seconds, tap **+1 mi back**: a warning buzz, and the pin stays where it was.
5. With **Listen after tap** on: tap a zone, tap **+1 mi back** while it's listening, then say "blue barn". One pin, "1 mi back", labeled "blue barn".
6. Drive log: the summary has "+1 mi back taps: … · moved a pin … · no pin just before …" and how long after the pin you tapped.

## Version 1.1 checklist (photos and the Silent switch)

1. **Silent switch:** turn on Silent mode (Action button or Control Center). Tap the capture screen: a haptic, no tone. Turn Silent off: the tone again. With music playing, the tone mixes in without pausing it.
2. With **Spoken confirmation** on and Silent mode on: no tone, but Passing still speaks (and music pauses for it, then resumes). In CarPlay, check whether you hear the tone with Silent on, and tell me.
3. **Take Photo** on a pin: iOS asks for camera permission the first time. Take one: it appears in the pin's Photos row. The list shows a photo icon on that pin.
4. **Choose Photo:** pick 3 at once: they appear in the order you picked, a spinner while they're added.
5. Tap a photo: full screen, swipe between them. **Delete Photo** → it's gone, the pin stays. Delete the last one: the viewer closes.
6. Add photos until there are 6: Take Photo and Choose Photo turn grey, and the footer says to delete one first.
7. Export CSV: the `photos` column shows each pin's count.
8. Delete the pin, then **Delete Now** in Recently Deleted: its photos go too (Settings → iPhone Storage → Passing should drop back after a while).
9. Settings → Privacy & Security → Camera → Passing off, then Take Photo: an alert offers Open Settings.

## Apple Watch (Milestone 9)

Passing on Apple Watch saves a pin with the watch's own GPS, mostly for walks and sometimes in the car.

- **Four buttons**, laid out like the 2x2 widget: the left and right columns are the sides of the road or path, the top row is far and the bottom row near, in the phone's colors. The app's pin sits where they meet as a label only (1.1.3): a touch there goes to the button underneath.
- **Saved at once, with a tap on the wrist.** The button shows a green tick for a moment, or a red cross if the watch couldn't save it (tap again).
- **Status line** above the buttons: whether a tap now gets a position (GPS ready, Finding GPS…, Location off, Precise Location off), and how many pins the iPhone doesn't have yet ("2 to send").
- **Location:** the watch asks the first time Passing opens on it. GPS runs while Passing is on the watch's screen, and for up to 15 seconds after a tap if there was no reading yet. A pin with no reading in that time goes without a location, never with a late or old one. The freshness rules are the same as the iPhone's.
- **Getting pins to the iPhone:** pins stay on the watch until Passing on the iPhone has saved them, then the watch lets them go. They go straight from the watch to the iPhone (no server), in order, whenever the two are in reach, even with Passing closed on the watch. On the iPhone they're saved when Passing runs. iOS may also start Passing briefly in the background to take them, which is one thing the checklist checks.
- **On the iPhone:** watch pins say **Saved from: Apple Watch**, wait in **Needs Review**, and set off review reminders, like widget pins. They keep the watch's position, never the iPhone's. A pin that arrives twice is saved once.
- **Complication (1.1.2):** the app icon's pin, for a watch face (circular, corner, rectangular or inline) or the Smart Stack. Tap it to open Passing. To add it: press and hold the watch face, tap **Edit**, swipe to the complications, tap a spot and choose **Passing**.
- **Not in this version:** "+1 mi back" and voice labels on the watch.

**Installing it** (the first time from Xcode, straight onto the watch; installing from the iPhone's Watch app only works once Xcode knows the watch):
1. In Xcode, **Integrate → Pull**. If Xcode says watchOS isn't installed: **Xcode → Settings → Components**, then **Get** next to watchOS.
2. Developer Mode on both: on the iPhone and on the watch, **Settings → Privacy & Security → Developer Mode** → on, restart, then **Turn On** (the watch may ask you to tap **Trust** and enter its passcode). On the watch the switch only appears once Xcode has started pairing with it (step 3), so come back to it then.
3. Pair the watch with Xcode: open the run destination menu (next to the scheme name at the top) → **Manage Devices…** (Device Hub). With the iPhone plugged in and the watch unlocked on your wrist, the watch appears under the iPhone; if it doesn't, click **+** → **Pair Nearby Device…** → Apple Watch and follow the steps. Tap **Trust** on both the iPhone and the watch. The first time, Xcode copies files from the watch for a while; wait until it says the watch is ready.
4. Pick the **PassingWatch Watch App** scheme and your watch as the destination, and press Run. This registers the watch for signing (so the app is allowed on it) and installs it. If it fails, copy the error from Xcode (the red message, or the Report navigator, ⌘9) and send it to me.
5. After that, the copy inside the iPhone app (the Watch app's **Available Apps**) installs too.

## Milestone 9 manual test checklist

The Simulator can't send pins between a watch and an iPhone (Apple's docs say so), so this one is on your real watch and iPhone. Turn on the drive log on the iPhone first (Settings → Feedback → Drive Log).

1. Open Passing on the watch: it asks for your location. Choose **Allow While Using App**. Outside or by a window, the status line changes from **Finding GPS…** to **GPS ready**.
2. Tap each of the four buttons: a tap on the wrist and a green tick on that button each time. The status line counts them ("4 to send") until the iPhone has them.
3. Tap right on the pin in the middle: it saves for whichever button is under your finger (the pin itself isn't a button).
4. Tap the same button twice quickly: only one pin.
5. With Passing open on the iPhone: within a minute or so the pins appear in Pins and in **Needs Review**. Each says **Saved from: Apple Watch** with the right side and distance, and the watch's count drops to zero. If nothing comes, close Passing on the iPhone and open it again, and note how long it took.
6. Leave the iPhone behind (or turn its Bluetooth and Wi-Fi off) and make 2 pins on the watch: the watch shows "2 to send". Back with the iPhone, wait a few minutes **without opening Passing on it**, then open Passing: note whether the pins were already there (iOS woke Passing in the background) or only arrived when it opened.
7. Indoors with no GPS, tap a button and lower your wrist at once: the pin still reaches the iPhone, with no location.
8. On the watch, **Settings → Privacy & Security → Location Services → Passing → Never**: the status line says **Location off**, and a tap still saves a pin (no location). Set it back to **While Using the App**.
9. Drive Log on the iPhone: the summary has a line "Apple Watch pins reached the iPhone: median …, slowest …".

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
10. **+1 mi back:** tap a zone, tap **+1 mi back** twice (each within 5 seconds), then say "diner". You get one pin, "2 mi back", labeled "diner".
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
8. **+1 mi back:** a rounded button at the bottom left, with a yellow arrow, dimmed until you drop a pin. After a pin, a tap, then quick extra taps, give 1, 2, 3 miles back.
9. **Landscape:** rotate the Simulator (⌘→). Everything fits, and the Simple pin shrinks to make room. Rotate back.
10. **Widgets:** the **Pin** widget shows the yellow pin. If it still shows the old symbol, remove it and add it again. Check both widgets in the CarPlay window too.
11. **Light mode:** with Settings → Appearance → Light, the capture screen and its title bar stay dark.
12. **Pins by day:** each day has its own card under a bold heading (**Today** or **Yesterday** with the date beside it, then dates) with a pin count. To see it without waiting a day: make a few pins, then Settings → Testing → **Clock: +1 day**. Those pins move under **Yesterday**. New pins still use the real time, so they join them; the test clock only moves "now", not when pins were made. Set it back to 0.
13. **Notes:** on the capture screen tap **Add a note**. Passing asks "What's your note?". Say "call about the farm for sale": in Pins, a note with that text appears under Today, with a note icon and no map. Tap **Add a note** again and say nothing: no empty note appears. In Pins tap the wide **New Note** button at the bottom, type (or dictate with the keyboard's microphone) and tap **Save**. Open a note: you can edit the text, star it, group it and delete it. With speech permission never granted, **Add a note** says how to turn it on and saves nothing.
14. **Move a pin:** open a pin in Pins → tap **Move** on its map (or touch and hold it in the list → **Move Pin…**). The map opens on satellite with an orange crosshair. Drag it onto the right building and tap **Save**. The pin's map shows the car (blue) and the new spot (orange); **Open in Apple Maps** goes to the new spot, the town is looked up again, and the list says "Moved by you". A "No location" pin offers **Place on Map** instead. **Where my car was** jumps back to the car.
15. **Needs Review:** tap the Pin widget twice and save one pin from the capture screen. In Pins, a **Needs Review** row at the top shows 2 (the capture-screen pin isn't counted). In the list below, the two widget pins have a faint amber background and a tray icon; the other pin doesn't. Tap the row: just the widget pins. Swipe one right all the way: it's marked Reviewed and leaves the list. When the last one goes, it says **All caught up**. The folder menu also has **Needs Review**, and Export from there exports just those. Tap the widget again, then touch and hold the new pin → **Group** → pick a group: it's marked Reviewed and leaves Needs Review. Tap the widget once more, open that pin and type a label (or pick a place in **What's here?**): it's marked Reviewed and leaves Needs Review too.
16. **Widget feedback and the medium widget:** tap the Pin widget: it turns green with a tick and **Saved** straight away, and the button comes back after about a second and a half (amber **No location** stays with no GPS). Add **Pin Left or Right** (medium) to the Home Screen or a medium Smart Stack: tap the left arrow, then in Pins the pin says "Left". Tap right on the **Passing** label, a little left of its middle: that's a "Left" pin too, and no tap anywhere on the widget opens the app.
16a. **Review reminders:** Settings → Needs Review → **Review Reminders** → turn on **Remind me** and allow notifications. Set the time to two minutes from now. Tap the Pin widget, then go to the Home Screen: at that time a notification says "1 pin to review from your drive". Tap it: Passing opens on Needs Review. Mark the pin Reviewed. Tap the widget again, then mark that pin Reviewed before the time: no notification comes.
17. **Arrival reminder:** in Review Reminders → **Set Work…** → **Use My Current Location** (with the Simulator's location set to a city, like Apple). Turn off **At a time**. Change the Simulator's location somewhere else, tap the Pin widget, then set the location back to the Work spot: within a few minutes a notification appears. **Tell me whether it does**: it's armed by the widget, and I couldn't confirm from Apple's docs that iOS lets a widget arm an arrival reminder. If it doesn't, opening Passing arms it instead.
18. **What's here?:** set the Simulator's location to a city (Features → Location → Apple), make a pin, open it in Pins → **Find Places Near This Pin**. Up to seven nearby places appear, closest first, with type and distance (up to 15 after **Look Farther**). Tap one: the pin's label becomes its name, the map moves to it, and the list says "Matched to a place". **Open in Apple Maps** opens that place's card, where **Add to Guide** works. Tap **Move** on the map and save: the place link goes away and it's a plain moved pin again. For a pin labeled "coffee", **Search “coffee” Here in Apple Maps** shows coffee shops around it.
19. **On your iPhone 16 Pro, parked:** check the screen is easy to read in the mount, in daylight and at night, and that the title button isn't easy to hit by accident. The Action Button's **Quick Pin** works as before.

## Set up the App Group (needed for your own iPhone)

The project is set up for Dan's account: bundle IDs `com.danhall.passing` (+ `.widget`, `.tests`) and App Group `group.com.danhall.passing`. Anyone else building it changes these to their own. To run on your phone, the bundle IDs and App Group have to be yours. There are two targets to change, the app and the widget:

1. In Xcode, click the blue **Passing** project at the top of the file list, then the **Passing** target, then **Signing & Capabilities**.
2. **Team:** choose your team.
3. **Bundle Identifier:** change `com.example.passing` to something unique, e.g. `com.yourname.passing`.
4. In **App Groups**, click **+** and add `group.com.yourname.passing`. Untick or remove `group.com.example.passing`.
5. Open `Support/Info.plist` and set **PassingAppGroup** to exactly the same `group.…` value.
6. Now click the **PassingWidgetExtension** target and repeat: same **Team**, Bundle Identifier `com.yourname.passing.widget` (it must start with the app's ID), and tick the same App Group.
7. Open `Support/PassingWidget-Info.plist` and set **PassingAppGroup** to the same value.

If the App Group doesn't match, the app still works, but Settings shows an orange **Storage** warning, and the widgets show **Not set up** instead of their buttons, because their pins would never reach the app.

If the App Group is set up but its database won't open (rare; it could happen mid-update), Passing doesn't quietly save somewhere else, where pins would be stranded. Instead it saves nothing until it's reopened, and says so: the capture screen's pill says **Can't save pins** (red), taps give an error buzz instead of the tone (and "Pin not saved" if spoken confirmation is on), Siri says it couldn't save, widget buttons turn red with **Not saved**, and Settings has a red **Storage** notice. Swipe Passing away in the app switcher and open it again.

## Decisions so far

- **Fix freshness:** a reading up to 10 s old and within 200 m accuracy can be used. The numbers are in `WatchShared/FixPolicy.swift`, which the watch uses too.
- **The tone follows the Silent switch** (your call): on silent, a tap is haptic only. Spoken confirmation and listen after tap, which you turn on yourself, still speak on silent, like directions in Maps. The tone mixes with music rather than pausing it.
- **Capture colors come from the app icon** (navy, verge green, deep blue, asphalt, pin yellow). Near and far differ in brightness as well as color, so they're easy to tell apart at a glance and for color-blind drivers, and nothing is glaring at night.
- **Gradient capture buttons, not Liquid Glass.** Each zone is brightest near the top and darkens toward the bottom while staying green or blue (colors sampled from your mockup), with a subtle smoky variation, slightly darker side edges and a faint border. Each zone has its own fixed smoke pattern, so nothing moves or uses battery. The labels sit in the middle, where white text stands out.
- **Still runs on iOS 26.** It's tuned for iOS 27 and the iPhone 16 Pro, but the minimum stays iOS 26, so iPhones that haven't updated can still install it. Nothing in the app needs iOS 27 yet.
- **The title switch lasts for the drive.** It resets when Passing is reopened or comes back after more than 30 minutes away, so Settings stays the layout Passing opens with.
- **Location permission is requested on the first capture** (privacy rule), so that one tap gets a system prompt. Do your first capture while parked.
- **Expired pins are stamped with when they moved, not when they hit 7 days.** Every pin gets its full 30 days in Recently Deleted, even after weeks away from the app, or after turning off "Keep records indefinitely" with old pins.
- **Recovering a pin that's more than 7 days old also keeps (stars) it.** Otherwise it would expire again on the next clean-up.
- **Exports include active pins only**, not Recently Deleted.
- **The trail only records while the capture screen is open** (no background location). Opening the Pins list mid-drive pauses it. A gap that could hide a turn (two readings more than about 300 m apart with none between, as after a tunnel or a few seconds off the capture screen at speed), a gap of more than 2 minutes, or an impossible jump (faster than ~155 mph, like a GPS glitch) starts a fresh trail, rather than drawing a straight line that cuts the corner. Passing can't know which road joined the two ends.
- **"+1 mi back" moves the pin you just dropped** (your call, after the second drive log, where a zone tap and a "+1" a second later made two pins). It only works for about 10 seconds after a pin, and about 5 seconds after each "+1", so it never makes a pin of its own. Siri's "2 miles back" still saves a new pin, since there's no pin to move.
- **"+1" taps aren't debounced**, because quick taps are how you say "3 miles". Every tap measures back from where you dropped the pin, not from where the car is by then.
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
- **The watch app is a companion of the iPhone app**, not a watch-only app (the Xcode wizard's default, which can't share pins with the iPhone app). It travels inside the iPhone app, and its ID is `com.danhall.passing.watchkitapp`.
- **The watch asks for location the first time Passing opens on it**, not on the first tap like the iPhone. A question on screen right after the first tap would cost that pin its location.
- **The watch keeps every pin until the iPhone says it's saved.** A pin that reached the iPhone but was never confirmed (say, the iPhone couldn't save it) is sent again an hour later, the next time Passing starts on the watch. The iPhone recognizes a pin it already has, so this never makes duplicates.
- **`SFSpeechRecognizer` rather than iOS 26's new `SpeechAnalyzer`.** It's simpler, still supported, and on-device on iPhone. If the iPhone can't recognize its language on the device, the setting stays off rather than sending audio to a server.

## Project layout

| Piece | Where |
| --- | --- |
| Code used by both the app and the widget | `Shared/` |
| Code the Apple Watch app uses too (freshness rules, side and distance, colors, the pin, the watch's pins and outbox) | `WatchShared/` |
| Apple Watch app | `PassingWatch Watch App/` (buttons in `WatchCaptureView.swift`, save path in `WatchCapture.swift`); the iPhone side is `Passing/Services/WatchLink.swift` and `CaptureService.saveWatchPin` |
| Capture screen | `Passing/Views/CaptureView.swift`, colors and pin in `WatchShared/PassingColors.swift` and `PinGlyph.swift` |
| Layout switch and GPS pill | `Passing/Model/CaptureModeChoice.swift`, `Passing/Model/GPSStatus.swift`, title button in `Passing/App/PassingApp.swift` |
| Single save entry point | `Shared/Services/CaptureService.swift`, wired up per target in `Passing/Services/CaptureService+App.swift` and `PassingWidget/CaptureService+Widget.swift` |
| Siri, Shortcuts, Action Button | `Passing/Intents/CaptureIntents.swift`, `Shared/Services/IntentCapture.swift` |
| Widgets and Control Center | `PassingWidget/`, `Shared/Intents/WidgetIntents.swift` |
| GPS and freshness rules | `Shared/Services/LocationProvider.swift`, `WatchShared/FixPolicy.swift` |
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
