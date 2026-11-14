# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

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

- Coordinates come only from the phone's GPS: the store pin on check-in is where you stand, never picked by hand.
- The Day plan, Calendar, Tickets, Expenses and Leave tiles on Home are one sideways row that fades at the edge with more to scroll.
- Messages show as the app's own toast at the top of the screen (success, error or info, announced to screen readers) instead of the system snackbar.

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

### Changed

- Renamed to Davaindia Field Force: package and bundle ID `com.gitcs.davaindia.ff`, an "ff" mark in the icon, splash and in-app logo, and the APK is now `davaindia-ff-android.apk`.
- In-app logo: the davaindia word with "FIELD FORCE" under it, replacing the ff mark and "GENERIC PHARMACY".
- Home rebuilt from the dashboard: overview, needs attention, today, the lead-to-billing strip and recent leads; leads and onboarding boards; alerts inbox with an unread badge; pinned page headers.
- Loading states show placeholder shapes in the layout of the content instead of text.
- Sideways rows (Today, the lead-to-billing strip, lead filters, board tabs) run to the screen edges and fade out on the side that has more to scroll.
- Profile moved into the bottom tabs; alerts open from the bell on Home.
- Requires Flutter 3.50; Material widgets come from the material_ui package.
