# Dynamic Island for Vimer — technical investigation

Goal: make Vimer behave like a real macOS "Dynamic Island" — a small pill that lives at the MacBook notch, drawn over the menu bar, that expands into the full timer panel on hover / hotkey with a spring morph.

This is a real app category on macOS (NotchNook, TheBoringNotch, DynamicNotchKit, Atoll).
None of them are Flutter; they are all AppKit/SwiftUI.
The techniques transfer, but the work is native.

## 1. What we're actually building

"Dynamic Island" is an iOS feature.
On the Mac it is the "notch app" pattern: a floating, always-on-top window that hugs the physical camera notch (top-centre of the built-in display), draws *over* the menu bar, and morphs between a compact pill and an expanded panel.

On Macs without a notch (and on external displays) these apps synthesise a pill at top-centre of the screen instead.

Reference implementations worth reading:

- [TheBoringNotch](https://github.com/TheBoringTeam/TheBoringNotch) — open-source Swift/SwiftUI. Notch detection from `NSScreen` geometry, Core Animation morph, MediaRemote for now-playing.
- [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) — a small Swift library. Public API is basically `DynamicNotch(content:)`, `await notch.expand()`, `DynamicNotchInfo`, and it auto-falls back to a `.floating` pill on notchless Macs. It encapsulates the window drawing + safe areas.
- [DynamicNotch](https://github.com/jackson-storm/DynamicNotch), NotchNook (commercial).

## 2. The core technical requirements

### 2.1 A window that draws OVER the menu bar / notch

This is the crux, and it is the one thing our current stack cannot do out of the box.

- The window should be an `NSPanel` with `.nonactivatingPanel` (so the pill never steals focus), or an `NSWindow` with an elevated level.
- The window **level must be above the menu bar**. The menu bar sits at level ~24 (`.mainMenu`). A normal always-on-top window (what `window_manager`'s `setAlwaysOnTop` gives you) is `.floating` = level 3, which is *below* the menu bar, so it cannot overlap the notch. You need `.statusBar` level or higher — notch apps typically use `CGShieldingWindowLevel()` (the screen-saver/shield level) or `.statusBar + 1`.
- Borderless, transparent, `hasShadow = false` — already done in `MainFlutterWindow`.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so it stays put across Spaces and can appear over full-screen apps.
- `hidesOnDeactivate = false`.

Concrete Swift for the level (the part `window_manager` can't do):

```swift
panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
panel.isFloatingPanel = true
panel.hidesOnDeactivate = false
```

### 2.2 Notch geometry (macOS 12+)

```swift
if let screen = NSScreen.main {
  let notchHeight = screen.safeAreaInsets.top            // 0 on notchless Macs
  let left  = screen.auxiliaryTopLeftArea?.width  ?? 0
  let right = screen.auxiliaryTopRightArea?.width ?? 0
  let notchWidth = screen.frame.width - left - right     // width of the notch itself
  let hasNotch = notchHeight > 0
}
```

- `safeAreaInsets.top` gives the notch height (0 when there is no notch).
- `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` are the usable rectangles beside the notch; the notch width is the screen minus those.
- Recompute on `NSApplication.didChangeScreenParametersNotification` (display change, resolution change, clamshell).

### 2.3 Hover-to-expand

Detect the cursor entering the notch rectangle.

- **Preferred: `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)`** — global *mouse* monitors do NOT need Accessibility permission (only global *keyboard* monitors do). Permission-free.
- Simpler still: a lightweight timer polling `NSEvent.mouseLocation` against the notch rect.
- TheBoringNotch uses `CGEvent.tapCreate`, which is the most robust but **requires the Accessibility permission** (a scary prompt). Avoid unless we need it.

### 2.4 The morph animation

Two visual states: compact pill (hugs the notch) and expanded panel (drops below).

The smoothest approach is to keep **one large transparent overlay window** sized to the expanded bounds, always on screen, and draw/animate the *content* — pill in compact state, full panel in expanded state — entirely in Flutter.
This avoids resizing the native window every frame (which is janky to sync with Flutter's raster thread).

The alternative — resizing the native `NSWindow` per state with Core Animation — gives a more "native" morph of the window shape itself, but is hard to keep in lockstep with Flutter's rendering. Start with the transparent-overlay approach.

## 3. Which mechanism: FFI, Pigeon, platform views, or a plugin?

**Verdict: native Swift + Pigeon. Not FFI, not platform views, no off-the-shelf plugin for the core.**

### Pigeon — recommended

The app already has a Pigeon bridge (`pigeons/vimer_api.dart` → `VimerHostApi`/`VimerFlutterApi`) and a custom `MainFlutterWindow`.
Window level, `NSScreen` geometry, and the hover monitor are all AppKit; write them in Swift and expose a small typed API.
Type-safe, matches the existing architecture, no new failure modes.

### FFI (`dart:ffi` + `package:objective_c`) — no

FFI is for calling standalone C/ObjC libraries from Dart.
Here we are manipulating the app's *own* `NSWindow`, which already lives in the native layer.
Driving AppKit from Dart via the ObjC runtime is more verbose and more fragile than just writing Swift, and buys us nothing. Skip.

### Platform views (the doc linked) — wrong tool for the core

`AppKitView` embeds a native `NSView` *inside* the Flutter widget tree.
A notch app needs control over the *window* (level, position, collection behavior), which platform views do not touch.
They are also explicitly experimental on macOS — the Flutter docs say gesture support isn't available yet and it's "not fully functional," with hybrid-composition performance caveats — so not production-ready.
The only place a platform view could help is embedding a native `NSVisualEffectView` for a frosted/vibrancy background, and even that is better done at the window level. Skip for the core; optional for blur.

### Existing plugins

- **`window_manager`** (already a dependency): position/size/frameless/alwaysOnTop. But `alwaysOnTop` = `.floating` level, which is *below* the menu bar. Cannot overlap the notch. Insufficient alone — we manage the window natively for the elevated level.
- **`macos_window_utils`**: sets the `NSWindow` material and adds `NSVisualEffectView` subviews (real blur/vibrancy) plus alpha. Great for the frosted look behind the island. Does not do window level or notch positioning. Complementary, optional (Phase 4).
- No Flutter plugin does "notch window." DynamicNotchKit is Swift-only — borrow the technique, own the implementation.

## 4. Recommended architecture

Native Swift `NotchController` in the Runner:

- Creates/owns the overlay panel at notch level, with the collection behavior and non-activating style above.
- Computes notch metrics for the active screen and repositions on screen-parameter changes.
- Runs the global `.mouseMoved` monitor and emits hover-enter/exit for the notch rect.

Pigeon additions:

- Dart → Native: `enableNotch()`, `disableNotch()`, `setExpanded(bool)`, `notchMetrics() -> { hasNotch, screenWidth, notchWidth, notchHeight, scale }`.
- Native → Dart: `onNotchHover(bool entered)`, `onNotchMetricsChanged(metrics)`.

Flutter:

- An `IslandShell` widget: a compact pill (soonest-firing timer, or an idle dot) that morphs into the existing full panel.
- Drive the morph with a spring `AnimationController` anchored top-centre; reuse the current panel UI as the expanded state.
- Interaction: hover → peek/expand; hotkey (⌃⌥Z) → expand and focus the input; click-away / Esc → collapse.

## 5. The real product change to decide first

Today Vimer is summon-only: the hotkey shows a full panel that is otherwise hidden.

A Dynamic Island is the opposite: a pill is **always on screen** at the notch, showing live state (the active timer), and expands on hover.

That is a genuine UX shift, not just a reskin.
Recommendation: adopt the always-on pill (that is the whole point of the Island) showing the soonest-firing timer, expand on hover, and keep the hotkey as the "expand + focus the input to type a new timer" path.

## 6. Gotchas and risks

- **`window_manager` vs. a custom level**: `window_manager` may fight a custom window level/position. Cleanest is to manage the island window natively (lean on `MainFlutterWindow` + Pigeon) and reduce `window_manager`'s role — or run a dedicated second panel just for the island. Converting the single existing window is the simplest first step.
- **Full-screen apps**: appearing over full-screen needs `.fullScreenAuxiliary` + a high level; some full-screen contexts still suppress overlays.
- **Multi-monitor / notchless / clamshell**: synthesise a top-centre pill when `hasNotch` is false; recompute on screen change.
- **Battery**: an always-on transparent Flutter overlay repaints continuously. Keep the compact pill cheap — no per-frame animation while idle; only animate on hover and on the 1s timer tick.
- **Focus**: the pill must never take key focus (non-activating); only the expanded input takes focus, on demand. Be careful with `makeKeyAndOrderFront`.
- **Permissions / notarisation**: none required with the `NSEvent` monitor approach — no Accessibility, no extra entitlements. Notarisation is unaffected.

## 7. Phased plan

- **Phase 0 — de-risk (native only)**: raise the existing window above the menu bar (`CGShieldingWindowLevel`), position it hugging the notch, and confirm it draws over the menu bar and across Spaces. One Pigeon flag + a few lines of Swift. This proves the single hardest unknown before investing in UI.
- **Phase 1**: notch metrics over Pigeon; position at the notch (or top-centre fallback); a static compact pill widget.
- **Phase 2**: global hover monitor → expand/collapse with the spring morph.
- **Phase 3**: live pill content (soonest timer), hotkey focus-expand, click-away/Esc collapse.
- **Phase 4 — polish**: vibrancy background (`macos_window_utils` or window material), notchless pill, multi-display, full-screen behavior.

Start with Phase 0 — it is small, and it either works (and everything else is "just" UI) or it exposes a blocker early.

## 8. Should this be a reusable package?

Prior art on pub.dev: [`mac_notch_ui`](https://pub.dev/packages/mac_notch_ui).
As of this writing it is v0.0.5, 4 likes, ~22 weekly downloads, ~5 months stale, "unverified uploader", and BSL-1.0 licensed (source-available, not permissive OSS).
It does not hug the physical notch (no `safeAreaInsets`) and does not appear to draw above the menu bar — it is a top-of-screen pill with hover states.
So the hard part (true notch geometry + above-menu-bar window level) is still unsolved on pub.dev, and its restrictive license makes it a poor dependency for an MIT app.

Decision: yes, a package is worthwhile — but extract it, don't design it cold.

- Build the notch mechanics inside Vimer first, behind a clean, timer-agnostic boundary: a Swift `NotchController` plus a Dart `island/` module that know nothing about timers.
- Dogfood through Phases 0–2 until the API stops changing, then extract to a package. Extracting a proven abstraction beats publishing an unproven API and eating breaking changes.
- Do not introduce a melos monorepo yet — a monorepo for one package is its own premature abstraction. Keep the boundary clean now; stand up `packages/dynamic_notch` + `apps/vimer` (melos) at extraction time.

Scope it as a primitive, not a Boring.Notch clone: elevated notch-anchored window + notch metrics + hover events + expand/collapse + bring-your-own Flutter content.
No media/HUD/file-shelf features — a clean primitive is maintainable, a kitchen sink is not.

Differentiators over `mac_notch_ui`: real notch geometry (`safeAreaInsets` / `auxiliaryTopLeftArea`), draws above the menu bar (`CGShieldingWindowLevel`), notchless + multi-monitor fallback, Pigeon-typed API, and an MIT/BSD license.

Caveat: publishing means issues, PRs, semver, CHANGELOG, and macOS/multi-monitor edge-case bugs. Commit to that maintenance or keep it internal.

## 9. Reference dissection: textream (native, confirms the whole plan)

[f/textream](https://github.com/f/textream) is a shipping native SwiftUI notch app (a teleprompter).
Not Flutter, but its `NotchOverlayController.swift` is a complete, battle-tested version of exactly the window technique we need, and it validates every architectural call above.
Concrete, copyable patterns:

### The panel (the crux — proven constants)

```swift
let panel = NSPanel(
  contentRect: NSRect(x: screenFrame.midX - notchWidth/2,
                      y: screenFrame.maxY - targetHeight,   // anchored to the very top
                      width: notchWidth, height: targetHeight),
  styleMask: [.borderless, .nonactivatingPanel],
  backing: .buffered, defer: false)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = false
panel.level = .screenSaver                                  // ABOVE the menu bar
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
panel.sharingType = hideFromScreenShare ? .none : .readOnly // bonus: hide from screen recording
panel.orderFrontRegardless()
```

Deltas from our first draft, learned from textream:

- **Window level: use `.screenSaver`** (= `kCGScreenSaverWindowLevel`, 1000). Simpler and proven vs. `CGShieldingWindowLevel()`; it sits above the menu bar so the panel overlaps the notch.
- **Notch/menu-bar height: `screen.frame.maxY - screen.visibleFrame.maxY`**. Textream does NOT use `safeAreaInsets`; the visibleFrame delta gives the menu-bar height on any Mac, and it hardcodes the notch *width* (configurable, ~200). `safeAreaInsets`/`auxiliaryTopLeftArea` are still the precise route for hugging the *physical* notch width — pick based on how exact we want it.
- **Panel is sized to the ISLAND bounds, not the screen.** So the transparent area never eats clicks across the whole top of the screen.

### The morph — CONFIRMED: animate content, not the window

Textream creates the panel at full expanded size and animates an `expansion: CGFloat` 0→1 *inside* SwiftUI — never resizing the window per frame:

```swift
let currentHeight = notchHeight + (targetHeight - notchHeight) * expansion
let currentWidth  = notchWidth  + (fullWidth   - notchWidth)  * expansion
// two-phase: expand container (0.4s easeOut), then fade content in (+0.35s)
```

This is exactly the "big overlay, morph the content" approach we recommended — now de-risked by a shipping app.

### The visual secret: `DynamicIslandShape`

A custom `Shape` with **concave top corners (bowing downward, like the notch) and convex bottom corners**, animated via `animatableData`. That silhouette is what makes it read as "growing out of the notch." In Flutter this is a `CustomClipper<Path>` with quadratic-bezier corners — straightforward to port.

### Hover / multi-monitor — no Accessibility

`NSEvent.mouseLocation` + `NSMouseInRect` on a 0.3s timer to find the screen under the cursor and reposition; a 1/60s timer for follow-cursor mode. Confirms the permission-free approach (no Accessibility, no CGEvent tap). Esc-to-dismiss via `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` (keyCode 53).

### Vibrancy

`NSVisualEffectView` (`material = .hudWindow`, `blendingMode = .behindWindow`) wrapped in `NSViewRepresentable`, clipped to the island shape. Our Phase-4 blur.

### What differs for Vimer (Flutter, not SwiftUI)

- Textream hosts the island content in an `NSHostingView` (SwiftUI). We host a **FlutterView** instead. Simplest path: reconfigure our existing `MainFlutterWindow` (set `.level = .screenSaver`, collectionBehavior, top-centre frame) rather than spin up a second panel/engine.
- Do the morph + `DynamicIslandShape` in **Flutter** (AnimationController + CustomClipper), window stays full-size.
- **Focus tension to resolve**: textream's panel is non-activating and read-only (no text field). Vimer's expanded state has the command input, which needs key focus. So the panel must become key *on demand* (expanded-for-input) but stay non-activating as an idle pill — `.nonactivatingPanel` + `becomesKeyOnlyIfNeeded`, or toggle activation on expand. This is the one genuinely new wrinkle vs. textream.
