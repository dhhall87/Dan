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
