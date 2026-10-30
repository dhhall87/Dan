# Sunrise

An iPhone app that wakes you with your lights instead of (or before) an alarm sound. Over 10–60 minutes your lights go from a very dim amber to warm gold to soft daylight, reaching full brightness at a time you pick or at the local sunrise.

It works with any dimmable light in Apple Home, including Nanoleaf Essentials bulbs.

## What you need

- An iPhone on iOS 26 or later.
- Your lights in Apple's Home app.
- **A home hub:** a HomePod, HomePod mini or Apple TV set up as a home hub. The sunrise runs on the hub, not the phone. Thread bulbs like Nanoleaf Essentials already need a HomePod mini or Apple TV 4K as their Thread border router, so you probably have one. Sunrise's Home card shows a green tick when the hub is connected.

A free Apple developer account can use HomeKit. Apps installed that way stop opening after 7 days until you run them from Xcode again.

## How it works

iOS doesn't let an app run in the background at 6:30 AM to dim lights up slowly. Apple Home does, though: its automations run on the home hub even while the iPhone is asleep and Sunrise is closed. So when you tap **Save to Home**, Sunrise writes the sunrise into Home as a series of steps:

- **Up to 16 steps** across the sunrise (every minute for 10–15 minutes, every 2–4 minutes for longer ones). Each step is one scene, which sets the brightness and color of the chosen lights, plus one automation, which runs that scene at its time on your chosen days.
- **A prep step a minute before the start** sets the first dim level without turning the lights on. HomeKit runs a scene's actions in no set order, so a scene that turns a light on and dims it could flash the bulb's last brightness first. This avoids that flash.
- **"At a set time"** uses time-of-day automations. **"At sunrise"** uses Home's own sunrise automations ("30 minutes before sunrise"), so the hub works out each day's sunrise from your home's location and the sunrise follows the seasons with nothing more to do.
- **Colors:** brightness rises slowly at first (squared), so most of the light arrives near the end. The color starts at a deep amber (about 1,500 K, warmer than any white bulb's warmest white, so color bulbs use hue and saturation for it), then hands over to white tuning once the bulb can make that white, ending on the white you choose. With **Sunrise colors** off, only the brightness changes.
- Every step turns the lights on, so a step that doesn't get through (a bulb that's slow to respond, say) doesn't cost you the whole sunrise.

In Apple's Home app you'll see these as scenes and automations named "Sunrise App Step 00" to "Sunrise App Step 16". Leave them there. Sunrise replaces them all each time you save, and **Remove from Home** takes them all out.

**Try it now** plays the whole sunrise on your lights in about 45 seconds, straight from the iPhone, so you can see the colors without waiting for morning.

## Opening it in Xcode

Sunrise is its own project, separate from Passing: open `Sunrise/Sunrise.xcodeproj`. It uses the same team as Passing, so signing should just work. Choose your iPhone and press Run. The Simulator has no real lights, so try it on the phone.

If Xcode says the bundle ID `com.danhall.sunrise` "is not available" (another developer already owns it), change it under the Sunrise target → Signing & Capabilities → Bundle Identifier, for example to `com.danhall.sunrisewake`, and tell Claude so the project file matches.

⌘U runs the tests (sunrise times, the light curve, the schedule, settings) in the Simulator.

## Milestone 1 manual test checklist

1. Build and run on your iPhone. Tell Claude about any build errors or warnings.
2. ⌘U: all tests pass.
3. Tap **Connect to Home** and allow access. Your home's name and your lights show up (room · Color).
4. Check the Home card says your home hub runs the sunrise (green tick).
5. Pick one light, then tap **Try it now**. Over about 45 seconds it should come on very dim amber, with no flash of its old brightness, warm to gold, and end white at 75%. **Lights off** turns it off.
6. Set **At a set time** to about 13 minutes from now, with a 10-minute sunrise. Tap **Save to Home**. The progress overlay counts the steps, then "Saved in Home" with the switch on. Lock the phone. About 3 minutes from now the light should come on very dim and brighten every minute, reaching 75% at the set time.
7. Open Apple's Home app: the automations and the "Sunrise App Step" scenes are there.
8. In Sunrise, turn the switch off: the automations show as off in the Home app. Turn it back on.
9. Change the brightness: **Update Home** appears. Tap it.
10. Switch to **At sunrise** and tap **Show sunrise times here**, allowing location. Check the time against the Weather app's sunrise for tomorrow (it should be within a minute or two). Save to Home, and check the Home app shows "before sunrise" automations.
11. Tap **Remove from Home**: everything named "Sunrise App Step" leaves the Home app.
12. The real test: a sunrise tomorrow morning.

Things to watch for and tell Claude:

- Whether your bulbs come on during the prep step (some bulbs turn on when their brightness is set; that's harmless at 1%).
- If you turn the light off during a sunrise, the next step turns it back on until the wake time. Turn the sunrise off in Sunrise if you're up early. Say if you'd rather it stayed off.
- **Adaptive Lighting:** setting a light's color can switch Adaptive Lighting off for that light. With **Sunrise colors** off, Sunrise only changes brightness.
- Whether a 60-minute sunrise saves in **At sunrise** mode (its prep step is 61 minutes before sunrise; Apple doesn't document a limit on the offset).

## What's next

- **Milestone 2: the alarm.** iOS 26's AlarmKit lets third-party apps set real alarms that sound through Silent mode and Focus. Sunrise would set one for the end of the sunrise (on the same days, and for "At sunrise", on each day's sunrise time worked out on the phone). A snooze button needs a small widget extension for the countdown.
- Possible later: "at sunrise, but not before 6:00", turning the lights off a while after the wake time, more than one sunrise.

### Why it doesn't listen for when you're waking up

You asked about using the microphone or your Oura ring to start the sunrise when you're naturally surfacing from sleep. It isn't in this version, and here's why:

- **Oura:** the ring only syncs through the Oura app, and its sleep stages are worked out after you wake. Neither Oura's cloud API nor Apple Health gets live sleep data overnight, so there's nothing to react to in the moment.
- **Microphone:** it's technically possible (Sleep Cycle does it), but the phone would have to sit by the bed, plugged in, with Sunrise running and the microphone on all night. Telling sleep stages apart from breathing sounds isn't something Claude can build and check reliably here; the honest version is "you moved around a lot in the last few minutes". It would also need Sunrise to change Home from the background, which Claude hasn't confirmed HomeKit allows.

If you want to try the "restless near the end of the sunrise window → wake now" version later, it would be its own experimental milestone, paired with the alarm.
