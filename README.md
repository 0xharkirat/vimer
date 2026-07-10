# Vimer

A menu-bar timer you drive entirely from the keyboard.

Press a global hotkey, type a timer in plain English (`25m deep work`, `@3pm`, `stopwatch #focus`), and hit Enter.
It runs in the menu bar with a live countdown per timer: no Dock icon, no window to babysit.
Select and control timers with vim keys, and drop into a `:` command line or the `?` cheatsheet when you need them.

## Features

- Natural-language input.
  Type `25m deep work` for a labelled countdown, `@3pm` for a clock alarm, or `stopwatch` (short form `sw`) for a count-up, and add `#tags` anywhere in the line.
  Bare numbers mean minutes, and forms like `1h30m`, `90s`, `25:00`, and `1.5h` all parse.
- Vim-style modal keyboard control.
  `j` and `k` move the selection, `gg` and `G` jump to the first or last timer, and `i` returns to the input.
  `x` or `dd` deletes the selected timer.
  A `:` command line runs `:settings`, `:clear`, `:help`, and `:q`, and `?` opens the cheatsheet.
- Seven-segment LCD readout.
  Each timer renders as a hand-drawn seven-segment display, with faint ghost segments and a soft glow on the lit ones.
- One colour per timer.
  Every timer is assigned its own colour, carried through to its card and its menu-bar item.
- A menu-bar item per timer.
  Any timer that has not finished shows a live countdown in the menu bar, tinted its own colour.
- Global summon.
  `Control + Option + Z` opens the panel from any app.
- Global silence.
  While an alarm is ringing, `Escape` stops it from any app.
  The hotkey is only bound while something is actually ringing, so `Escape` behaves normally the rest of the time.
- Custom alarm sounds.
  Load your own `wav`, `mp3`, `aiff`, `m4a`, or `caf` file, and set how long it plays and how loud.

## Natural-language input

Type into the command field and press Enter.
The parser is forgiving about spacing and word order, and a label can come before or after the duration.

| You type | You get |
| --- | --- |
| `25` | 25 minutes (a bare number is minutes) |
| `5m` | 5 minutes |
| `90s` | 90 seconds |
| `1h30m` | 1 hour 30 minutes |
| `1.5h` | 90 minutes (decimals parse) |
| `25:00` | 25 minutes (`mm:ss`) |
| `1:30:00` | 90 minutes (`hh:mm:ss`) |
| `25m deep work` | 25-minute countdown labelled "deep work" |
| `@3pm` | alarm at 3:00 PM |
| `@3:30pm standup` | alarm at 3:30 PM labelled "standup" |
| `@14:00`, `@noon`, `@midnight` | 24-hour and named times |
| `stopwatch`, `sw` | count-up stopwatch |
| `25m #focus` | countdown tagged `#focus` |

Alarms roll to the next occurrence, so `@9am` typed in the afternoon fires at 9 AM tomorrow.

## Keyboard cheatsheet

This is the same reference the app shows when you press `?` or run `:help`.

Type, in the command field:

| Key | Action |
| --- | --- |
| type | a timer: `25m`, `@3pm`, `sw`, `#tag` |
| `Enter` | start it |
| `Down` | go to the list |
| `Esc` | clear, or hide |

Select, in the timer list:

| Key | Action |
| --- | --- |
| `j` / `k` | move down / up |
| `gg` / `G` | first / last |
| `i` | back to the input |

Control, on the selected timer:

| Key | Action |
| --- | --- |
| `Space` | pause / resume |
| `Enter` | restart |
| `s` | stop |
| `x` / `dd` | delete |

Command line:

| Key | Action |
| --- | --- |
| `:q` | quit |
| `:settings` | settings (`⌘,`) |
| `:clear` | remove all |
| `:help`, `?` | this cheatsheet |

Global:

| Key | Action |
| --- | --- |
| `Control + Option + Z` | summon Vimer |
| `Esc` | silence a ringing alarm |

## Install

### Homebrew

```bash
brew install --cask 0xharkirat/tap/vimer
```

This taps `0xharkirat/homebrew-tap` and installs `Vimer.app`.
Update later with `brew upgrade --cask vimer`.

Homebrew 6 and newer refuse to load casks from an untrusted third-party tap.
If you see "Refusing to load cask ... from untrusted tap", trust it once:

```bash
brew trust 0xharkirat/tap
```

The cask clears the download quarantine as it installs, so Gatekeeper should not block the first launch.
If macOS still refuses to open Vimer, clear the flag by hand:

```bash
xattr -dr com.apple.quarantine /Applications/Vimer.app
```

### Manual (DMG)

Download the DMG for your Mac from the GitHub Releases page.

- Apple Silicon: `Vimer-arm64.dmg`
- Intel: `Vimer-x86_64.dmg`

Open the DMG and drag `Vimer.app` onto the Applications shortcut.

Vimer is ad-hoc signed rather than notarized, so Gatekeeper blocks the first manual launch.
Clear the quarantine flag from a terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Vimer.app
```

Or open it once from System Settings > Privacy & Security by clicking "Open Anyway" next to the blocked-app message.
You only do this once.
Vimer then runs from the menu bar with no Dock icon.

## Build from source

Vimer is a Flutter app with only pub.dev dependencies.

```bash
flutter pub get
flutter run -d macos
```

## Tech

Flutter and Riverpod run the app.
A Pigeon-generated bridge connects it to a small Swift layer that owns the menu-bar items and the floating panel window, and registers the global hotkeys.
macOS only, for Apple Silicon and Intel.

## License

MIT.
See [LICENSE](LICENSE).

Development assisted by Claude Code.
