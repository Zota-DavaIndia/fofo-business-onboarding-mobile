# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- Home counters as gradient cards with icons, aligned to the bottom when labels wrap.
- Data refreshes when the app returns to the foreground, every few minutes while open, and when a server event arrives.
- App icon for Android and iOS, generated from vector outlines, and the same logo inside the app.
- Montserrat as the app font, bundled with the app.
- Location, camera, photo, notification and install permissions declared for the coming features.

### Changed

- Profile moved into the bottom tabs; alerts open from the bell on Home.
- Requires Flutter 3.50; Material widgets come from the material_ui package.

## [0.1.0]

### Added

- Sign-in with device binding and offline session restore.
- Home screen with lead counts.
- Bottom tabs built from the signed-in user's permissions, with Profile as a tab and alerts behind the bell on Home.
- Profile with contact details, app version, device ID and sign out.
- Custom icon set generated from SVG files.
- Light and dark themes.
- Demo mode with sample data for trying the app without a backend.
- CI checks, and a release workflow that publishes signed APKs to GitHub Releases.
