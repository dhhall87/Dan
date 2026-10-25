# RoadPin

Tap once while driving to mark something you're passing, then look it up later when it's safe.

- **Four zones around a car.** Tap left or right of the car: the inside columns are for things right by the road, the outside columns for things farther away. There's also a "one big button" mode where you can touch anywhere.
- **"What do you want to look up?"** After a tap on the phone, RoadPin asks out loud and listens for a few seconds ("large building", "name of that town"). The pin is saved before it asks, so you never lose the spot.
- **+1 mi back.** If you missed something, tap the bar along the bottom. Tap again within 4 seconds to make it 2 miles, 3 miles, and so on. RoadPin keeps a trail of the last 50 miles you drove, so the pin lands back on the road you were actually on, even around curves. If it hadn't recorded that far back yet, the pin says how much further back to look.
- **Apple Maps or Google Maps.** Every pin opens in either one, with the nearest street and town filled in.
- **Weekly clean-up.** Pins are deleted 7 days after you drop them, unless you star them or turn on **Keep pins forever** in Settings.
- **CarPlay.** The same zones (or one big button) plus "+1 mi back" appear as large buttons on the car's screen, with a "Recent" tab. Tapping a recent pin starts directions back to it.
- **Siri, hands-free.** No screen at all:
  - "Hey Siri, **drop a RoadPin**" → "What do you want to look up?" → "that red barn"
  - "Hey Siri, **I missed something in RoadPin**" → "How many miles back was it?" → "two" → …
  - "Hey Siri, **name my last RoadPin**" adds a note to a pin you dropped with a CarPlay tap.

  These also work from the steering-wheel voice button, AirPods, or the iPhone Action Button (Settings → Action Button → Shortcut → RoadPin).

## Running it

You need a Mac with **Xcode 16 or later**. The app runs on **iOS 17 or later**.

1. Open `RoadPin.xcodeproj`.
2. Pick an iPhone simulator and press **Run** (⌘R).
3. Give the simulator a moving location so pins have somewhere to go: **Features → Location → Freeway Drive**.

### Trying CarPlay in the simulator

With the app running in the simulator, choose **I/O → External Displays → CarPlay**. RoadPin shows up on the CarPlay home screen. The simulator build already includes the CarPlay entitlement (`Support/RoadPin-CarPlay.entitlements`), so this works without Apple's approval.

### Putting it on your own iPhone

1. Select the **RoadPin** target → **Signing & Capabilities** → choose your **Team**.
2. Change the **Bundle Identifier** from `com.example.roadpin` to something unique, like `com.yourname.roadpin`.
3. Plug in your phone and press Run.

Everything except CarPlay works on a real phone straight away, including Siri. CarPlay on a real car needs Apple's approval (see below).

## Getting CarPlay into a real car

Apple only lets apps onto CarPlay in specific categories, and each one needs an entitlement that Apple approves by hand. RoadPin is written as a **Driving Task** app (`com.apple.developer.carplay-driving-task`).

1. Request it at <https://developer.apple.com/carplay/> (you need a paid Apple Developer account).
2. Once approved, regenerate your provisioning profile. In the target's build settings, change **Code Signing Entitlements** so `Support/RoadPin-CarPlay.entitlements` is used for device builds too, not just the simulator.

**Heads-up:** Apple's guidelines say driving task apps must "actually help with the drive, not just be tasks that are done while driving," so approval isn't guaranteed. When you apply, it helps to pitch RoadPin as a safety tool: it replaces fumbling with a phone or a maps app at speed with one large tap or a voice command.

If Apple says no, Siri still works in the car today with no approval needed. Since iOS 26, CarPlay can also show widgets from any app, so a "Drop Pin" CarPlay widget is a good plan B (see Next ideas).

### What CarPlay doesn't allow (and what RoadPin does instead)

- **No custom drawing.** CarPlay apps must use Apple's templates, so the four zones are a grid of four big buttons with little road icons instead of the phone's car picture.
- **No microphone.** Apple doesn't allow driving task apps to record audio while CarPlay is connected. CarPlay taps save the pin immediately and can speak a short "Saved". For the note, use "Hey Siri, name my last RoadPin", or start with "Hey Siri, drop a RoadPin". The phone's own listen-after-tap feature switches off while CarPlay is connected.

## How it works

| Piece | File |
| --- | --- |
| Drive screen (zones, big button, +1 mi back) | `RoadPin/Views/DriveView.swift` |
| Pin list / pin details / settings | `RoadPin/Views/` |
| Saving pins, miles-back logic, notes | `RoadPin/Services/PinRecorder.swift` |
| GPS and the road trail | `RoadPin/Services/LocationTracker.swift`, `RoadPin/Model/BreadcrumbTrail.swift` |
| "What do you want to look up?" (speech) | `RoadPin/Services/VoicePrompter.swift` |
| Database and weekly clean-up | `RoadPin/Services/PinStore.swift`, `RoadPin/Model/Pin.swift` |
| Apple / Google Maps links | `RoadPin/Services/MapLinks.swift` |
| CarPlay screen | `RoadPin/CarPlay/` |
| Siri phrases | `RoadPin/Intents/PinIntents.swift` |

Pins are stored only on the phone (SwiftData). Speech is transcribed on-device when the phone supports it. Location is used while RoadPin is open or in CarPlay. iOS shows the blue location pill if the phone is locked mid-drive, and turns GPS off by itself once you've been parked for a while.

## Next ideas

- **CarPlay / Lock Screen / Control Center widget** with a single "Drop Pin" button (an interactive widget that runs `DropPinIntent`). This works in CarPlay on iOS 26 without the CarPlay entitlement.
- Kilometers option.
- iCloud sync of pins between devices.
