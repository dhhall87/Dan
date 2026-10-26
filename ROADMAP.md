# Future Roadmap: Passing Pro and Sales Workflow

**Status:** Planned, not for immediate implementation. Keep prioritizing the current milestone and the core capture experience.

**Instruction:** Keep this roadmap as future context only. Don't begin implementation or change the current milestone unless Dan explicitly asks. When this work begins, inspect the existing codebase and propose a focused implementation plan first.

## Goal

Expand Passing from a personal travel companion into a lightweight field-discovery tool for traveling salespeople and others who spot places or business prospects while driving.

## Planned Pro features

- **Notes and prospect details:** add business names, notes, and an optional follow-up status when reviewing captured pins. Keep the driving capture process fast and distraction-free.
- **Better organization:** named collections, tags, filtering, and bulk management for organizing prospects or places.
- **Export:** CSV export for spreadsheets and CRM workflows, with JSON and KML as possible additional formats.
- **Follow-up reminders:** optional local notifications such as "Remind me tomorrow", "Follow up in 3 days", or a custom date.
- **Automated reports:** support Apple Shortcuts and App Intents to retrieve pins from the last 12 or 24 hours, generate a CSV report, and pass it to Files, Mail, or other Shortcut actions. Ideally, users could create a scheduled morning automation that emails them a report of unreviewed pins.
- **Avoid duplicate reports:** explore a "since last report" option as an alternative to a rolling time window.
- **Multi-stop route from selected pins (Dan, October 2026; possible Pro feature):** in Select mode, tap pins in the order to visit them; choose a start and end (the first and last selected pin by default, or Current Location, the saved Home/Work places, or a typed address); see the route on a map in Passing; then open it in Apple Maps or Google Maps.

## Multi-stop route (built in Milestone 8, October 2026; not gated yet)

- **Ordered selection:** Select mode keeps a `Set` today; the route needs the tap order (an array), shown as 1, 2, 3 on the rows and map. Notes and pins without a location are left out. A miles-back pin with no estimate uses where the car was.
- **Map in Passing:** two levels. Straight lines between the pins in order: instant, free and offline. A road route: MapKit `MKDirections`, one request per leg (A→B, B→C, …), drawn with `MapPolyline`, with total distance and time. Apple throttles directions requests per device, so cap the number of stops. MapKit doesn't reorder stops for the shortest trip; keep the tap order (a simple "nearest next" ordering could be added on the phone).
- **Apple Maps export:** the unified Maps URL supports it officially (iOS 18.4+, so fine for the iOS 26 target): `https://maps.apple.com/directions?source=…&waypoint=…&waypoint=…&destination=…&mode=driving`, with `waypoint` repeated per stop, coordinates or addresses as values, `waypoint-place-id` for places chosen in "What's here?", and `mode` driving, walking, transit or cycling. Apple's page gives no stop limit, but the Maps app has one: test it and cap to match.
- **Google Maps export:** `https://www.google.com/maps/dir/?api=1&origin=…&destination=…&waypoints=…|…` (pipe-separated, encoded `%7C`). The number of stops in between is limited (a third-party source says 9, and 3 in a mobile browser; confirm against Google's Maps URLs docs when building). Longer routes: split into parts, or use the existing KML export for Google My Maps.
- **Start and end:** Home/Work and the address search already exist for review reminders and can be reused.
- **Privacy:** like today's map links, stop coordinates go to Apple or Google only when the route is opened there; the in-app road route sends them to Apple (MapKit directions) only when asked for.
- **Paid:** fits Passing Pro (one-time StoreKit 2 purchase), which needs the paid Developer Program and App Store or TestFlight distribution. Straight-line preview could stay free, with road routes and export as Pro.

## Technical and privacy constraints

- Prefer a local-first implementation using the existing SwiftData and App Group architecture.
- Don't introduce a backend or recurring infrastructure costs unless later research shows it's necessary.
- Investigate App Intents execution when the app isn't foregrounded, including file generation, and whether scheduled email delivery can work reliably without user interaction.
- Clearly distinguish local notifications from email automation. A Shortcut can orchestrate report generation and delivery, but iOS execution constraints must be tested before promising fully automatic delivery.
- Keep the capture experience simple and safe. Notes, organization, and follow-up actions happen mainly after capture.
- Use the planned one-time Passing Pro purchase for premium features, while keeping core capture and access to users' own data free.

## Suggested implementation order

1. Finish the current capture, widget, and CarPlay-widget work.
2. Add notes and improved pin review.
3. Add collections and CSV export.
4. Add local follow-up reminders.
5. Prototype the Shortcuts reporting workflow and validate background execution.
6. Decide whether automated email delivery is viable without a backend.
7. Implement and test Pro purchase gating through StoreKit 2.

## Notes against the current app (for planning later)

- **Already built or planned:** pins already have a `label`; notes and business name would be new fields. Groups (Milestone 6) are the natural base for named collections. JSON and CSV export have existed since Milestone 2, and KML export is planned for Milestone 6.
- **Decide before gating:** export is free today, and "access to users' own data stays free" suggests basic export stays free, with Pro covering the extras (reports, reminders, tags, bulk tools).
- **Retention:** pins expire after 7 days unless kept. A pin with a follow-up status or reminder probably needs to be kept automatically.
- **Publishing:** StoreKit purchases need the paid Apple Developer Program and App Store or TestFlight distribution, so Pro is the same "publish or not" decision as the native CarPlay app.
