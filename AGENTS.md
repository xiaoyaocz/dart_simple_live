# Repository guidelines

## Scope and structure

This file applies to the whole repository. The repository contains four Dart projects rather than a single workspace:

- `simple_live_core`: shared live-site APIs, models, parsers, and danmaku clients.
- `simple_live_app`: Flutter client for Android, iOS, macOS, Windows, and Linux.
- `simple_live_tv_app`: Flutter client focused on Android TV.
- `simple_live_console`: command-line client built on `simple_live_core`.

The two clients and the console use `simple_live_core` through a relative path dependency. When changing a public core API, parser, model, or protocol implementation, check every consumer that is affected.

## Toolchain

- Flutter is pinned to `3.47.1` with FVM in both Flutter projects.
- Run Flutter commands from the relevant app directory with `fvm flutter ...`; use `fvm dart ...` when a Flutter project's Dart SDK is required.
- Run `fvm install` in each Flutter project if the pinned SDK is not available locally.
- Run Dart commands for `simple_live_core` and `simple_live_console` from their own directories.
- Each project owns its `pubspec.lock`. Keep intentional lockfile changes, but do not regenerate unrelated dependencies.
- Do not commit generated or local state from `.dart_tool/`, `.fvm/`, `build/`, IDE settings, CocoaPods, or platform ephemeral directories.

## Development conventions

- Follow the existing Dart style and the lints in each project's `analysis_options.yaml`.
- Format changed Dart files with `dart format`; avoid repository-wide formatting for a scoped change.
- Keep platform-independent live-site behavior in `simple_live_core`. Keep presentation, routing, persistence, and platform integration in the corresponding Flutter app.
- The Flutter clients use GetX for routing and dependency lookup, Hive for local persistence, and `media_kit` for playback. Extend the existing patterns unless the task explicitly calls for an architectural change.
- Preserve existing public names and stored Hive data compatibility unless a migration is included.
- Never commit credentials, signing files, account cookies, tokens, or private API responses.

## Validation

Fetch dependencies before validation when `pubspec.yaml` or the SDK version changes.

```sh
cd simple_live_core && dart pub get && dart analyze && dart test
cd simple_live_console && dart pub get && dart analyze && dart test
cd simple_live_app && fvm flutter pub get && fvm flutter analyze && fvm flutter test
cd simple_live_tv_app && fvm flutter pub get && fvm flutter analyze && fvm flutter test
```

Start with the project directly changed. If `simple_live_core` changes, also validate the clients or console that use the changed API. For native platform changes, build or test the affected platform when the required host toolchain is available.
