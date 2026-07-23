# Vimer

[![Latest release](https://img.shields.io/github/v/release/0xharkirat/vimer)](https://github.com/0xharkirat/vimer/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/0xharkirat/vimer/total)](https://github.com/0xharkirat/vimer/releases)
[![License: MIT](https://img.shields.io/github/license/0xharkirat/vimer)](LICENSE)
![Platform: macOS](https://img.shields.io/badge/platform-macOS%2010.15%2B-lightgrey)

A keyboard-first timer for macOS: natural-language timers, vim motion keys. Built with Flutter.

Press a global hotkey, type a timer in plain English, and press Enter.
Vimer runs in the menu bar with a live countdown for each timer, so there is no Dock icon and no window to manage.
Select and control timers with vim keys, and drop into a `:` command line or the `?` cheatsheet when you need them.

## Table of contents

- [Install](#install)
- [Usage](#usage)
- [Build from source](#build-from-source)
- [How it works](#how-it-works)
- [Contributing](#contributing)
- [License](#license)

## Install

Vimer requires macOS 10.15 or later and runs natively on Apple silicon and Intel.

### Homebrew

```bash
brew install --cask 0xharkirat/tap/vimer
```

This command taps [0xharkirat/homebrew-tap](https://github.com/0xharkirat/homebrew-tap) and installs `Vimer.app`.
To update later, run `brew upgrade --cask vimer`.

### Manual download

Download the disk image for your Mac from the [latest release](https://github.com/0xharkirat/vimer/releases/latest):

- Apple silicon: `Vimer-arm64.dmg`
- Intel: `Vimer-x86_64.dmg`

Open the disk image and drag `Vimer.app` onto the Applications shortcut.

### Troubleshooting

Vimer is ad-hoc signed rather than notarized, so macOS applies extra checks on first launch.
The Homebrew cask clears the download quarantine for you, so these steps apply mainly to a manual install.

If macOS refuses to open Vimer, clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Vimer.app
```

You can also open it once from System Settings > Privacy & Security by selecting **Open Anyway** next to the blocked-app message.
You do this once.

If Homebrew reports `Refusing to load cask ... from untrusted tap`, trust the tap:

```bash
brew trust 0xharkirat/tap
```

### Uninstall

```bash
brew uninstall --cask vimer
```

To remove preferences and custom sounds as well, run `brew zap --cask vimer`.

## Usage

Press `Control + Option + Z` from any app to summon Vimer.
Type a timer, then press Enter.
Press `Escape` to hide the panel; timers keep running in the menu bar.

### Write a timer

The parser is forgiving about spacing and word order, and a label can come before or after the duration.

| You type | You get |
| --- | --- |
| `25` | 25 minutes (a bare number means minutes) |
| `5m` | 5 minutes |
| `90s` | 90 seconds |
| `1h30m` | 1 hour 30 minutes |
| `1.5h` | 90 minutes (decimals parse) |
| `25:00` | 25 minutes (`mm:ss`) |
| `1:30:00` | 90 minutes (`hh:mm:ss`) |
| `25m deep work` | a 25-minute countdown labeled "deep work" |
| `@3pm` | an alarm at 3:00 PM |
| `@3:30pm standup` | an alarm at 3:30 PM labeled "standup" |
| `@14:00`, `@noon`, `@midnight` | 24-hour and named times |
| `stopwatch`, `sw` | a count-up stopwatch |
| `25m #focus` | a countdown tagged `#focus` |

Alarms roll to the next occurrence, so `@9am` typed in the afternoon fires at 9 AM tomorrow.

### Keys

Press `?` or run `:help` in the app for this same reference.

| Context | Key | Action |
| --- | --- | --- |
| Command field | `Enter` | Start the timer |
| Command field | `Down` | Move to the timer list |
| Command field | `Escape` | Clear the field, or hide the panel |
| Timer list | `j` / `k` | Move down / up |
| Timer list | `gg` / `G` | Jump to first / last |
| Timer list | `i` | Return to the command field |
| Selected timer | `Space` | Pause or resume |
| Selected timer | `Enter` | Restart |
| Selected timer | `s` | Stop |
| Selected timer | `x` or `dd` | Delete |
| Command line | `:settings` | Open settings (`Command + ,`) |
| Command line | `:clear` | Remove all timers |
| Command line | `:help` or `?` | Open the cheatsheet |
| Command line | `:q` | Quit Vimer |
| Global | `Control + Option + Z` | Summon Vimer |
| Global | `Escape` | Silence a ringing alarm |

Vimer binds the global `Escape` hotkey only while an alarm rings, so `Escape` behaves normally the rest of the time.

### Other features

- Each timer gets its own color, carried through to its card and its menu-bar item.
- Every unfinished timer shows a live countdown in the menu bar, tinted its own color.
- Each timer renders as a hand-drawn seven-segment display, with ghost segments behind the lit ones.
- You can load a custom alarm sound in `wav`, `mp3`, `aiff`, `m4a`, or `caf` format, and set how long it plays and how loud.

## Build from source

Vimer is a Flutter app with only pub.dev dependencies.

```bash
flutter pub get
flutter run -d macos
```

## How it works

Flutter and Riverpod run the app.
A [Pigeon](https://pub.dev/packages/pigeon)-generated bridge connects it to a small Swift layer that owns the menu-bar items and the floating panel window, and registers the global hotkeys.

Development was assisted by Claude Code.

## Contributing

Issues and pull requests are welcome at [0xharkirat/vimer](https://github.com/0xharkirat/vimer/issues).

Before you open a pull request, confirm that `flutter analyze` reports no issues and `flutter test` passes.
[AGENTS.md](AGENTS.md) documents the build commands, the native layer, and the release workflow.

## License

MIT © Harkirat Singh.
See [LICENSE](LICENSE).
