import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Retained: it owns the menu-bar items and the Pigeon host handler.
  private var host: VimerHost?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // A FlutterView draws opaque BLACK by default; clearing both the window and
    // the Flutter view makes the transparent margin show the desktop.
    self.backgroundColor = NSColor.clear
    flutterViewController.backgroundColor = NSColor.clear

    // Stay on-screen (so Flutter keeps rendering) but invisible until showPanel
    // reveals it after the first frame - this avoids the default-frame flash.
    self.alphaValue = 0

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    let flutterApi = VimerFlutterApi(binaryMessenger: messenger)
    let host = VimerHost(window: self) { id in
      flutterApi.onTimerSelected(id: id) { _ in }
    }
    VimerHostApiSetup.setUp(binaryMessenger: messenger, api: host)
    self.host = host

    // Dismiss-on-blur for a menu-bar app: app deactivation is the reliable
    // signal (window-blur is flaky for an always-on-top / all-Spaces panel).
    NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
    ) { _ in
      flutterApi.onResignActive { _ in }
    }

    super.awakeFromNib()
  }

  // A frameless / borderless window must still be allowed to become key,
  // otherwise the command TextField can never receive keystrokes.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}

/// Implements the Pigeon-generated host interface: window transparency,
/// show/activate, and the per-timer menu-bar items.
final class VimerHost: NSObject, VimerHostApi {
  private weak var window: NSWindow?
  private let menuBar = MenuBarTimers()

  init(window: NSWindow, onSelect: @escaping (String) -> Void) {
    self.window = window
    super.init()
    menuBar.onSelect = onSelect
  }

  func configurePanel() throws {
    // window_manager.setAsFrameless() resets isOpaque to true; undo it.
    guard let window = window else { return }
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
  }

  func showPanel() throws {
    guard let window = window else { return }
    positionOnCursorScreen(window)
    NSApp.activate(ignoringOtherApps: true)
    window.setIsVisible(true)
    window.alphaValue = 1
    window.makeKeyAndOrderFront(nil)
  }

  /// Place the panel top-centre on whichever display holds the cursor. Uses
  /// AppKit directly (NSEvent.mouseLocation + NSScreen), which stays correct on
  /// multi-monitor setups where the Dart screen_retriever coordinates drift and
  /// the panel wrongly lands on the built-in display.
  private func positionOnCursorScreen(_ window: NSWindow) {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
      ?? NSScreen.main
    guard let target = screen else { return }
    let vf = target.visibleFrame
    let size = window.frame.size
    let x = vf.midX - size.width / 2
    let y = vf.maxY - size.height // window top hugs the top of the visible area
    window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
  }

  func setMenuBarTimers(timers: [MenuBarTimerData]) throws {
    menuBar.update(timers)
  }
}

/// Manages one clickable NSStatusItem per timer, each showing that timer's
/// remaining/elapsed time in its own colour.
final class MenuBarTimers: NSObject {
  private var items: [String: NSStatusItem] = [:]
  var onSelect: ((String) -> Void)?

  func update(_ timers: [MenuBarTimerData]) {
    var seen = Set<String>()
    for t in timers {
      seen.insert(t.id)
      let item: NSStatusItem
      if let existing = items[t.id] {
        item = existing
      } else {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        items[t.id] = item
      }
      let color = NSColor.zenHex(t.color) ?? NSColor.labelColor
      item.button?.attributedTitle = NSAttributedString(
        string: t.text,
        attributes: [
          .foregroundColor: color,
          .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        ])
    }
    for (id, item) in items where !seen.contains(id) {
      NSStatusBar.system.removeStatusItem(item)
      items.removeValue(forKey: id)
    }
  }

  @objc private func clicked(_ sender: NSStatusBarButton) {
    for (id, item) in items where item.button === sender {
      onSelect?(id)
      return
    }
  }
}

extension NSColor {
  static func zenHex(_ hex: String) -> NSColor? {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return NSColor(
      calibratedRed: CGFloat((v >> 16) & 0xFF) / 255,
      green: CGFloat((v >> 8) & 0xFF) / 255,
      blue: CGFloat(v & 0xFF) / 255,
      alpha: 1)
  }
}
