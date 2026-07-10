import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'vimer_api.g.dart';

/// Owns the macOS shell: the menu-bar status items, the floating panel window,
/// and global hotkeys. The panel + menu-bar calls go over a Pigeon-generated,
/// type-safe interface ([VimerHostApi] / [VimerFlutterApi]); all app
/// behaviour is injected through the callbacks so this stays free of logic.
class NativeService with TrayListener, WindowListener {
  final VimerHostApi _host = VimerHostApi();

  VoidCallback? onEscape;
  VoidCallback? onSummon;
  VoidCallback? onToggleWindow;
  VoidCallback? onOpenSettings;
  VoidCallback? onQuit;
  void Function(String id)? onSelectTimer;

  /// Return true to keep the panel visible when it loses focus
  /// (e.g. an alarm is ringing, or the Settings sheet is open).
  bool Function()? stayOpenOnBlur;

  /// Spotlight behaviour: clicking away dismisses the panel. Overridden from
  /// persisted settings at startup; [stayOpenOnBlur] still wins (ringing, sheet).
  bool autoHideOnBlur = true;

  final HotKey _escapeHotKey = HotKey(
    key: PhysicalKeyboardKey.escape,
    modifiers: const [],
    scope: HotKeyScope.system,
  );
  final HotKey _summonHotKey = HotKey(
    key: PhysicalKeyboardKey.keyZ,
    modifiers: const [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  bool _escapeRegistered = false;
  bool _summonRegistered = false;
  bool _hasEngaged = false;
  DateTime _suppressBlurUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    VimerFlutterApi.setUp(_VimerFlutterApiImpl(this));
    _suppressBlur();
    await _setupTray();
  }

  /// Push the current timers to the menu bar (one status item each).
  /// Each entry: {'id': String, 'text': String, 'color': 'RRGGBB'}.
  Future<void> setMenuBarTimers(List<Map<String, Object>> timers) async {
    try {
      await _host.setMenuBarTimers([
        for (final t in timers)
          MenuBarTimerData(
            id: t['id']! as String,
            text: t['text']! as String,
            color: t['color']! as String,
          ),
      ]);
    } catch (_) {}
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon('assets/tray/vimer_tray.png', isTemplate: true);
    await trayManager.setToolTip('Vimer');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show Vimer'),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: 'Settings…'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit Vimer'),
    ]));
  }

  void _suppressBlur() {
    // Avoid an instant hide-on-blur race right after summoning the panel.
    _suppressBlurUntil = DateTime.now().add(const Duration(milliseconds: 600));
  }

  /// Force the frameless window to be genuinely transparent. Must run after
  /// window_manager.setAsFrameless(), which resets isOpaque to true.
  Future<void> configurePanel() async {
    try {
      await _host.configurePanel();
    } catch (_) {}
  }

  /// Show the panel and make it key without activating the whole app.
  Future<void> showPanel() async {
    try {
      await _host.showPanel();
    } catch (_) {}
  }

  Future<void> reveal() async {
    _suppressBlur();
    // Positioning happens natively in showPanel (reliable on multi-monitor).
    await showPanel();
  }

  Future<void> hide() => windowManager.hide();

  Future<void> toggle() async {
    if (await windowManager.isVisible()) {
      await hide();
    } else {
      await reveal();
    }
  }

  Future<void> registerEscape() async {
    if (_escapeRegistered) return;
    _escapeRegistered = true;
    await hotKeyManager.register(_escapeHotKey,
        keyDownHandler: (_) => onEscape?.call());
  }

  Future<void> unregisterEscape() async {
    if (!_escapeRegistered) return;
    _escapeRegistered = false;
    await hotKeyManager.unregister(_escapeHotKey);
  }

  Future<void> enableSummonHotkey() async {
    if (_summonRegistered) return;
    _summonRegistered = true;
    await hotKeyManager.register(_summonHotKey,
        keyDownHandler: (_) => onSummon?.call());
  }

  Future<void> disableSummonHotkey() async {
    if (!_summonRegistered) return;
    _summonRegistered = false;
    await hotKeyManager.unregister(_summonHotKey);
  }

  // --- TrayListener ---
  @override
  void onTrayIconMouseDown() => onToggleWindow?.call();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        onSummon?.call();
      case 'settings':
        onOpenSettings?.call();
      case 'quit':
        onQuit?.call();
    }
  }

  // --- WindowListener ---
  @override
  void onWindowFocus() => _hasEngaged = true;

  @override
  void onWindowBlur() => _maybeAutoHide();

  /// Called from native when the app resigns active (user clicked another app).
  /// More reliable than window-blur for an always-on-top / all-Spaces panel.
  void onAppResignedActive() => _maybeAutoHide();

  /// Hide the panel when it loses focus, unless disabled, not yet engaged,
  /// just summoned, or pinned/ringing.
  void _maybeAutoHide() {
    if (!autoHideOnBlur) return;
    if (!_hasEngaged) return;
    if (DateTime.now().isBefore(_suppressBlurUntil)) return;
    if (stayOpenOnBlur?.call() ?? false) return;
    hide();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await hotKeyManager.unregisterAll();
  }
}

/// Receives native -> Dart calls (a menu-bar item was clicked).
class _VimerFlutterApiImpl implements VimerFlutterApi {
  _VimerFlutterApiImpl(this._service);
  final NativeService _service;

  @override
  void onTimerSelected(String id) => _service.onSelectTimer?.call(id);

  @override
  void onResignActive() => _service.onAppResignedActive();
}
