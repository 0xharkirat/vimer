# Vimer

A keyboard-first timer that lives in your macOS menu bar.

Summon it, type a duration, press Enter.
When a timer finishes it rings, and one press of `Escape` from any app silences it.
No Dock icon, no window chrome, no mouse required.

Vimer is built with Flutter and a thin layer of native macOS glue, tuned for Apple Silicon.

---

## Highlights

- Menu-bar native. The app runs as a macOS accessory (`LSUIElement`), so it never shows in the Dock or the app switcher. The status item shows the nearest timer counting down live.
- Type-to-start. A Spotlight-style command field parses free-form input like `25m`, `1h30m`, `90s`, `25:00`, or a named timer such as `5m tea`.
- Global stop. While an alarm is ringing, `Escape` is captured system-wide and stops the sound instantly, no matter which app has focus.
- Many timers at once. Run as many as you like. Each has its own animated ring, and each can be paused, resumed, restarted, or dismissed.
- Fluid by default. Spring-based entrances, a depleting progress ring rendered at display rate, colour that warms as time runs low, and a breathing "ringing" state.
- Configurable alarm. Choose how long the alarm plays (2s, 5s, 10s, or a custom length), set the volume, and load your own sound file.
- Optional global summon. Turn on `Control + Option + Z` to open the panel from anywhere, or just launch it from Spotlight or Raycast.

---

## The command language

Type any of these into the command field and press Enter.

| You type        | You get                                  |
| --------------- | ---------------------------------------- |
| `25`            | 25 minutes (a bare number means minutes) |
| `5m`            | 5 minutes                                |
| `45s`           | 45 seconds                               |
| `2h`            | 2 hours                                  |
| `1h30m`         | 1 hour 30 minutes                        |
| `5h5m30s`       | 5 hours, 5 minutes, 30 seconds           |
| `1.5h`          | 90 minutes (decimals allowed)            |
| `25:00`         | 25 minutes (`mm:ss`)                     |
| `1:30:00`       | 90 minutes (`hh:mm:ss`)                  |
| `25m deep work` | 25 minutes, labelled "deep work"         |
| `pomodoro 25m`  | 25 minutes, labelled "pomodoro"          |

The parser is forgiving about spacing and word order.
A label can come before or after the duration, and long unit words like `2 hours` or `30 min` also work.

Beyond plain countdowns, the same field understands alarms, stopwatches, and tags.

| You type              | You get                                        |
| --------------------- | ---------------------------------------------- |
| `@3pm`                | An alarm that fires at 3:00 PM                  |
| `@3:30pm standup`     | An alarm at 3:30 PM, labelled "standup"         |
| `@14:00` / `@noon`    | 24-hour and named times work too                |
| `stopwatch` / `sw`    | A stopwatch that counts up                       |
| `sw deep work`        | A stopwatch labelled "deep work"                |
| `25m #focus`          | A 25-minute timer tagged `#focus`               |
| `@9am gym #health`    | An alarm at 9 AM, labelled "gym", tagged `#health` |

Times roll to the next occurrence, so `@9am` typed in the afternoon means 9 AM tomorrow.
Tags can go anywhere in the command, and each timer shows its tags on its card and its own colour in the menu bar.
Stopwatches count up with no alarm; pause, resume, and restart them like any other timer.

---

## Keyboard model

Vimer is keyboard-first. Everything is reachable without the mouse.

The panel has two zones. The command field owns typing; the timer list owns control. `Down` moves you from one to the other, `Up` past the top (or `Escape`) brings you back.

**Anywhere**

| Key | Action |
| --- | --- |
| `Control + Option + Z` | Summon the panel from any app |
| `Escape` | Stop a ringing alarm, from any app (only bound while ringing) |
| `Command + ,` | Open or close Settings |

**In the command field**

| Key | Action |
| --- | --- |
| `Enter` | Start the timer you typed |
| `Down` | Drop into the timer list |
| `Escape` | Clear the field, or hide the panel if it is already empty |

**On the selected timer**

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move the selection |
| `Space` | Pause or resume |
| `P` / `R` | Pause / resume |
| `Enter` | Restart |
| `S` | Stop: silence a ringing alarm, otherwise cancel the timer |
| `Delete` / `Backspace` | Delete the timer |
| `Escape` | Back to the command field |

**In Settings**

| Key | Action |
| --- | --- |
| `Tab` / `Shift + Tab` | Move between controls |
| `Left` / `Right` | Adjust the focused segmented control or slider |
| `Space` | Toggle the focused switch or press the focused button |
| `Escape` | Close Settings |

Clicking a timer selects it too, so the mouse and the keyboard stay in sync.

---

## Install

Grab the build for your Mac from the [latest release](../../releases/latest):

- Apple Silicon (M1/M2/M3/M4): `Vimer-arm64.dmg`
- Intel: `Vimer-x86_64.dmg`

Open the `.dmg` and drag `Vimer.app` onto the Applications shortcut.

Vimer is signed for local use but not notarized by Apple, so the first launch is blocked by Gatekeeper. To allow it, once:

1. Double-click `Vimer.app`. macOS says it "could not verify" the developer. Click **Done** (or **OK**).
2. Open **System Settings > Privacy & Security**.
3. Scroll to the bottom. You will see a line saying **"Vimer" was blocked**, with an **Open Anyway** button. Click it.
4. Confirm with **Open Anyway** and authenticate if asked.

It opens and stays allowed from then on. Vimer lives in the menu bar, with no Dock icon.

On older macOS you can instead right-click `Vimer.app`, choose **Open**, then **Open** in the dialog.

---

## Requirements

The following is only needed to build from source.

- macOS 11 or newer (built and tested on Apple Silicon).
- Flutter 3.44 or newer with the macOS desktop toolchain enabled.
- Xcode 16 or newer with the command line tools, plus CocoaPods.

Check your setup with:

```bash
flutter doctor
```

Enable macOS desktop support if you have not already:

```bash
flutter config --enable-macos-desktop
```

---

## Build and install

### 1. Get the code and dependencies

```bash
cd vimer
flutter pub get
```

### 2. Run it in development

This launches the app with hot reload attached.

```bash
flutter run -d macos
```

The panel appears near the top of your screen and a clock icon appears in the menu bar.
Type a duration and press Enter to try it.

### 3. Build a release app

```bash
flutter build macos --release
```

The app bundle is written to:

```
build/macos/Build/Products/Release/Vimer.app
```

### 4. Install it like a real Mac app

Copy the app into your Applications folder so Spotlight and Raycast can find it:

```bash
cp -R build/macos/Build/Products/Release/Vimer.app /Applications/
```

The build is signed for local use only.
The first time you open it, macOS Gatekeeper may block an unidentified developer.
To allow it, right-click `Vimer.app` in Finder, choose Open, then confirm Open in the dialog.
You only need to do this once.

### 5. Launch from Spotlight or Raycast

Once `Vimer.app` is in Applications:

- Spotlight: press `Command + Space`, type `Vimer`, press Enter.
- Raycast: search `Vimer` and run it, or bind it to a hotkey inside Raycast.

Because Vimer is a single-instance menu-bar app, launching it again simply reveals the existing panel instead of starting a second copy.

### 6. Start Vimer at login (optional)

Open System Settings, go to General, then Login Items, and add `Vimer.app` under "Open at Login".

---

## Permissions and sandboxing

Vimer runs inside the macOS App Sandbox.

The global `Escape` and summon shortcuts use Carbon hot keys, which do not require Accessibility permission.
So there is nothing to approve in System Settings for the keyboard features to work.

The only extra entitlement is read access to files you pick yourself, which is used when you choose a custom alarm sound.
When you pick a sound, Vimer copies it into its own container so it keeps working across launches.

---

## Settings

Open Settings from the gear in the panel footer, or from the menu-bar icon.

- Alarm length. How long the sound plays when a timer finishes. Presets are 2, 5, and 10 seconds, or pick a custom value up to 30 seconds.
- Sound. Use the built-in Vimer chime, or load a `wav`, `mp3`, `aiff`, `m4a`, or `caf` file. The preview button plays the current sound.
- Volume. Sets playback level for the alarm.
- Summon shortcut. Toggles the global `Control + Option + Z` hotkey.
- Hide when it loses focus. On by default, so clicking away dismisses the panel the way Spotlight does. Turn it off to keep the panel up until you press `Escape`. Either way it stays put while an alarm is ringing or Settings is open.

Settings persist across launches.

---

## How it works

### Native layer

A small amount of Swift and a set of well-supported plugins provide the macOS shell.

- `Info.plist` sets `LSUIElement` so the app is a menu-bar accessory with no Dock presence.
- `AppDelegate.swift` keeps the process alive when the panel is hidden and reveals the panel when the app is relaunched from Spotlight, Raycast, or Finder.
- `MainFlutterWindow.swift` allows the frameless, transparent window to become key so the text field can receive keystrokes.
- `window_manager` makes the window a frameless, always-on-top, all-Spaces panel, and hides it when it loses focus.
- `tray_manager` owns the status item, its live countdown title, and its right-click menu.
- `hotkey_manager` registers the global `Escape` only while an alarm rings, and the optional summon hotkey.

### Flutter layer

State is managed with Riverpod.

A single engine holds every timer, ticks them down, drives the menu-bar title, and coordinates the alarm.
Each card watches its own timer by id, so a status change repaints one card rather than the whole list.
The progress ring is a `CustomPainter` driven by a per-card ticker for smooth motion, while the list uses an `AnimatedList` for enter and exit transitions.

### Project layout

```
lib/
  main.dart                      app entry: window + native bootstrap
  src/
    app.dart                     MaterialApp + theme
    theme.dart                   palette, colours, shared constants
    models/
      app_settings.dart          persisted settings model
      timer_model.dart           a single countdown
    services/
      duration_parser.dart       free-form command parsing
      alarm_service.dart         audio playback wrapper
      native_service.dart        window, tray, and hotkey glue
      prefs.dart                 shared_preferences facade
    state/
      providers.dart             shared Riverpod providers
      settings_provider.dart     settings notifier
      timer_engine.dart          the timer + alarm engine
    util/
      format.dart                duration and clock formatting
    ui/
      home_shell.dart            the glass panel and layout
      command_bar.dart           the Spotlight-style input
      timer_list.dart            animated list of timers
      timer_card.dart            a single timer card
      ring_painter.dart          the progress ring
      settings_sheet.dart        the settings sheet
      widgets.dart               small shared widgets
macos/                           native Runner project
assets/
  sounds/vimer_chime.wav        the default alarm
  tray/                          the menu-bar icon
test/
  duration_parser_test.dart      parser unit tests
  widget_test.dart               boot smoke test
```

---

## Development

Run the tests:

```bash
flutter test
```

Run the analyzer:

```bash
flutter analyze
```

The default alarm sound is generated procedurally rather than shipped from an unknown source.
It is a soft three-note chime with a short tail so it loops cleanly.

---

## Troubleshooting

The panel disappeared when I clicked another app.
That is by design. Vimer hides on blur like Spotlight. Bring it back with the menu-bar icon or the summon hotkey.

`Escape` does not affect other apps.
The global `Escape` capture is only active while an alarm is actually ringing. Outside of that window, `Escape` behaves normally everywhere else.

The summon hotkey does nothing.
Enable it in Settings, and make sure `Control + Option + Z` is not already claimed by another app.

I do not see a Dock icon.
There is not meant to be one. Vimer lives only in the menu bar.

---

## License

MIT - see [LICENSE](LICENSE).

---

Built with Flutter; development assisted by Claude Code.
