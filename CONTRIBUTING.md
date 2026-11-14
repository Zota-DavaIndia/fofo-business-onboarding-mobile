# Contributing

This is the field onboarding app for Dava India. Work happens in branches and lands on `main` through pull requests.

## Setup

1. Install Flutter (stable, 3.44 or newer) and Xcode for the iOS simulator.
2. `flutter pub get`
3. Copy `env/example.json` to `env/local.json`. It points at the staging CRM API; change `API_BASE_URL` only to use another backend. Release builds take the production address from the `API_BASE_URL` repository variable.

## Run

```bash
flutter run --dart-define-from-file=env/staging.json
```

`env/staging.json` points at the staging CRM. Ask the backend team for a staging test account. Use `env/local.json` to point at your own backend.

Android builds are made only by the release workflow on GitHub. Check changes locally in the iOS simulator and with the tests.

## Before opening a pull request

```bash
dart format lib test scripts
flutter analyze
flutter test
```

CI runs the same checks plus an Android debug build.

## Conventions

- Colors, spacing and type come from `lib/core/theme/`. No literal hex values or one-off sizes in screens.
- Icons are SVGs in `assets/icons/`. After adding or editing one, run `dart run scripts/gen_icons.dart`; a test fails if the generated file is stale.
- Screens check permissions (`lib/core/auth/permissions.dart`), never role names.
- New top-level areas go into `lib/app/modules.dart` with the permission they need.
- Commit messages are short and in the imperative: `Add visit check-in`, `Fix lead filter`.

## Releasing

Bump `version` in `pubspec.yaml` (for example `1.1.0+2`) and merge to `main`. The release workflow builds and signs the APK, tags `v1.1.0` and publishes it. Installed apps pick it up through the in-app updater.

## Reporting bugs

Open an issue with the steps to reproduce, what you expected, what happened, the app version (Profile screen) and the phone model.
