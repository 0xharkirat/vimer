# Vimer - agent instructions

Vimer is a keyboard-first macOS menu-bar timer.
It is a Flutter + Riverpod app with a Pigeon bridge to a small Swift/AppKit layer.
macOS only, built for both Apple Silicon and Intel.

## Build and run

```bash
flutter pub get
flutter run -d macos     # debug run
flutter analyze          # must be clean before any release
flutter test             # unit + widget tests
```

The macOS shell (floating panel, per-timer `NSStatusItem`s, global event monitors, summon hotkey) lives in `macos/Runner/MainFlutterWindow.swift`.
The Dart-to-Swift contract is Pigeon-generated.
Never hand-edit the generated files (`lib/src/services/vimer_api.g.dart`, `macos/Runner/VimerApi.g.swift`).
Edit `pigeons/vimer_api.dart` and regenerate:

```bash
dart run pigeon --input pigeons/vimer_api.dart
```

## Release workflow

Vimer ships as an ad-hoc signed DMG plus a Homebrew cask.
It is a distributed app, not a pub.dev package, so there is no `pub publish` step.

1. Do feature work on a `feature/...` branch.
2. Merge the finished feature to `main`.
3. Cut every release from a fresh chore branch off `main`, never straight from `main`:
   ```bash
   git switch main
   git switch -c chore/release-prep
   ```
4. On the chore branch: bump `version:` in `pubspec.yaml`, update `README.md`, run `flutter analyze` and `flutter test`, and fix any audit findings.
5. Build the disk images:
   ```bash
   tool/release_macos.sh      # writes dist/Vimer-arm64.dmg and dist/Vimer-x86_64.dmg
   ```
6. Merge the chore branch back to `main`, tag `vX.Y.Z`, and attach both DMGs to the GitHub release.
7. Update the Homebrew cask (`Casks/vimer.rb` in the `homebrew-tap` repo) with the new version and each DMG's `sha256`.

## Conventions

Commit with the repository's local git identity.
Never use a personal or session email, and never add an AI co-author line.
Do not use em dashes in prose anywhere in this repo; use a plain hyphen.
Keep `flutter analyze` clean and the tests green; a red tree does not ship.
