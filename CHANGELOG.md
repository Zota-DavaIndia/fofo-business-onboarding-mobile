# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [semantic versioning](https://semver.org/).

## [Unreleased]

## [1.1.9] - 2026-11-15

### Fixed

- The franchise fee screen showed "Left to pay ₹0" and hid "I have paid". Fee figures now come only from the CRM: every amount is the server's own, a fee HO hasn't set shows as not set, and figures that fail to load say so with a retry instead of showing ₹0.
- Customers now see the bank account to pay into on the franchise fee screen, once it is set in the CRM.

## [1.1.8] - 2026-11-15

### Changed

- Home's loading state is plain grey placeholder shapes in the same layout as the numbers (the Overview grid, the Today row and a list), with no labels or card colours, matching every other loading screen.
- While an update downloads, the Home banner shows the same ring with a stop button as Profile, in place of the download icon.

## [1.1.7] - 2026-11-15

### Added

- Double-tap the app version on Profile to check for an update now. A newer version starts downloading straight away; otherwise nothing happens.

## [1.1.6] - 2026-11-15

### Changed

- While an update downloads, the app version on Profile shows the percentage and a ring with a stop button; tapping it stops the download.

### Fixed

- Push notifications that arrived after Android had stopped the app in the background were dropped. Android now sets up Firebase when a push wakes the app, so they show.

## [1.1.5] - 2026-11-15

### Added

- The app sends the phone's hardware ID (Android ID / iOS vendor ID) when signing in and registering for push, so the CRM can block a phone even after the app is reinstalled.

### Changed

- When the CRM blocks the account or the phone, the app signs out and shows why.
- Home's loading state has the same layout as the loaded numbers: the Overview cards and Today tiles with placeholder numbers, then placeholder rows.

## [1.1.4] - 2026-11-15

### Fixed

- The app never found new versions: GitHub serves `version.json` as a binary download, which the check read as "no update". Versions before 1.1.4 can't update themselves; install 1.1.4 from the release page once.

### Added

- The app version on Profile shows the update's state: Update when a new version is out, a ring with the download percentage, then Install. The Home banner shows the same.

## [1.1.3] - 2026-11-15

### Fixed

- Push notifications arrived silently in Android's default channel. They now come on the app's own Alerts channel, so they pop up with sound and show a white "ff" in the status bar.

## [1.1.2] - 2026-11-15

### Added

- Push notifications on Android through Firebase: new leads, approvals, payments and reminders arrive on the phone, and tapping one opens its screen.

### Changed

- Updates download quietly in the background each time the app opens, then the update screen opens ready to install. Nothing shows when offline or if a download fails.
- The bottom bar shadow is lighter: a hairline with a faint shadow.

## [1.1.1] - 2026-11-15

### Changed

- Bottom bars (the tab bar and form buttons) have a soft shadow and a faint hairline, so content scrolling underneath stays separate.
- The splash is the logo on the page colour with three pulsing dots; the phone's launch screen uses the same colour.

### Fixed

- The keyboard covered the form's button (Sign in, Save, Add lead). The button now sits on top of the keyboard, and a focused field keeps its label in view.
- On Android 14 and older the status bar had a grey band over the app; it's now transparent with icons that match the theme.

## [1.1.0] - 2026-11-15

### Added

- Field users can add walk-in and referral leads.
- Day and time pickers in the app's own style: a month grid and an hour, minute and am/pm wheel. New times start in working hours, and times outside the allowed range are refused.

### Changed

- Opening an alert slides its lead, onboarding, ticket, claims or leave screen in over the current one, so Back returns to the alert. It opens at once and is marked read in the background. A double tap opens it once.
- Screens keep their content while live updates refresh them, instead of briefly showing the loading skeleton again. A lead or onboarding opened again within a minute shows at once.
- Messages appear in a compact toast near the bottom, above the tab bar or the form's button. No toast while the alerts inbox is open, and "Mark all read" sits under the inbox header.
- Lead and onboarding details from Home slide in over Home instead of switching tabs.
- Check-out asks for a summary, and the owner step needs a 10-digit mobile. UTRs follow the bank rule (10 to 22 letters or digits; spaces and hyphens are ignored).

### Fixed

- Check-out on a lead that had already moved on did nothing; it now closes the visit.
- The date picker showed empty boxes in place of its arrows.
- A save the server refused for a reason with no field on the form failed silently; it now shows a toast.
- Route tracking kept resending points the server had refused.

## [1.0.0] - 2026-11-14

### Added

- Sign-in with device binding and offline session restore.
- Home screen with lead counts.
- Bottom tabs built from the signed-in user's permissions, with Profile as a tab and alerts behind the bell on Home.
- Profile with contact details, app version, device ID and sign out.
- Custom icon set generated from SVG files.
- Light and dark themes.
- CI checks, and a release workflow that publishes signed APKs to GitHub Releases.
- Home counters as gradient cards with icons, aligned to the bottom when labels wrap.
- Data refreshes when the app returns to the foreground, every few minutes while open, and when a server event arrives.
- App icon for Android and iOS, generated from vector outlines, and the same logo inside the app.
- Montserrat as the app font, bundled with the app.
- Location, camera, photo, notification and install permissions declared for the coming features.
- Sign-in with email or mobile; enquirers sign in with their mobile and a code to track their application.
- Leads tab with search, status filters and a lead detail page with contact, call centre notes, details, onboarding and timeline.
- Today's visits on Home, and Home counts that open Leads on the matching list.
- Lead actions: call, log a call, notes, status changes and closing with a reason, editing, reassigning and adding leads.
- Check-in records the proposed store location (address, landmark, pincode, pin), shown on the lead.
- Visits tab with scheduling, rescheduling, cancelling, GPS check-in with photo and site assessment, and check-out.
- Lead page shows every field the CRM does (stage and time in it, campaign, RCM and territory, calls made, consent, timeline, all sources) and a map of the lead and the proposed store with directions.
- My day on Home: start and end the working day with GPS; the route is recorded in the background while the day runs and synced in batches.
- Expenses and Leave, opened from Home: claims with receipts submitted for approval, leave requests with days taken this year.
- Day plan: pick today's live stores and leads, see them numbered on a map with directions, and open each one.
- Store visits: check in at a live store with GPS, raise tickets while there, and check out with a summary and feedback.
- Tickets: raise a store's product, billing software, dispatch or accounts problem with a photo, and follow the CRM's updates.
- Calendar: a month with every visit, callback, follow-up, planned day, leave and your own scheduled activities; activities can be tied to a lead.
- Live alerts: while the app is open it checks for new alerts every 15 seconds, refreshes only what each one touched, and shows a toast that opens it. The customer screen does the same for updates on their application.
- Push notifications, built in and switched off until the Firebase settings are added: the phone registers after sign-in, a tapped push opens the right screen, and signing out stops pushes to that phone.
- In-app updates on Android: the app checks GitHub Releases at launch and every 6 hours, opens the update screen once for each new release and keeps offering it on Home and Profile. The APK downloads with progress, is checked against the release's SHA-256 and handed to the installer, asking once for permission to install.
- Google Maps in the app, with the key kept out of git and passed to release builds from a repository secret.

### Changed

- Renamed to Davaindia Field Force: package and bundle ID `com.gitcs.davaindia.ff`, an "ff" mark in the icon, splash and in-app logo, and the APK is now `davaindia-ff-android.apk`.
- In-app logo: the davaindia word with "FIELD FORCE" under it, replacing the ff mark and "GENERIC PHARMACY".
- Home rebuilt from the dashboard: overview, needs attention, today, the lead-to-billing strip and recent leads; leads and onboarding boards; alerts inbox with an unread badge; pinned page headers.
- Loading states show placeholder shapes in the layout of the content instead of text.
- Sideways rows (Today, the lead-to-billing strip, lead filters, board tabs) run to the screen edges and fade out on the side that has more to scroll.
- Profile moved into the bottom tabs; alerts open from the bell on Home.
- Requires Flutter 3.50; Material widgets come from the material_ui package.
- Coordinates come only from the phone's GPS: the store pin on check-in is where you stand, never picked by hand.
- The Day plan, Calendar, Tickets, Expenses and Leave tiles on Home are one sideways row that fades at the edge with more to scroll.
- Messages show as the app's own toast at the top of the screen (success, error or info, announced to screen readers) instead of the system snackbar.
