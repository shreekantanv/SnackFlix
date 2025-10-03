import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// App intervention modes (persisted as strings in Hive).
enum InterventionMode { observe, nudges, coach, lock }

extension _InterventionModeCodec on InterventionMode {
  String get key {
    switch (this) {
      case InterventionMode.observe:
        return 'observe';
      case InterventionMode.nudges:
        return 'nudges';
      case InterventionMode.coach:
        return 'coach';
      case InterventionMode.lock:
        return 'lock';
    }
  }

  static InterventionMode fromKey(String? k) {
    switch (k) {
      case 'observe':
        return InterventionMode.observe;
      case 'nudges':
        return InterventionMode.nudges;
      case 'coach':
        return InterventionMode.coach;
      case 'lock':
        return InterventionMode.lock;
      default:
        return InterventionMode.nudges; // default
    }
  }
}

class SettingsService extends ChangeNotifier {
  static const String _boxName = 'settings';

  // Keys
  static const String _themeKey = 'themeMode';
  static const String _batterySaverKey = 'batterySaver';
  static const String _pinKey = 'pin';

  // Backward-compat: keep old key for interval.
  static const String _biteIntervalKey = 'biteInterval'; // used also for mindful interval

  // Mindful-mode keys
  static const String _modeKey = 'interventionMode';
  static const String _mindfulEnabledKey = 'mindfulEnabled';
  static const String _shortRestSecondsKey = 'shortRestSeconds';
  static const String _snoozeMinutesKey = 'snoozeMinutes';

  late Box _box;

  // THEME
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // BATTERY
  bool _batterySaverEnabled = true;
  bool get batterySaverEnabled => _batterySaverEnabled;

  // PIN
  String? _pin;
  String? get pin => _pin;

  // INTERVAL (seconds)
  double _biteInterval = 90; // reused for mindful breaks
  double get biteInterval => _biteInterval;

  // MINDFUL
  bool _mindfulEnabled = true;
  bool get mindfulEnabled => _mindfulEnabled;

  // MODE
  InterventionMode _mode = InterventionMode.nudges;
  InterventionMode get mode => _mode;

  // EXTRAS
  int _shortRestSeconds = 20;
  int get shortRestSeconds => _shortRestSeconds;

  int _snoozeMinutes = 1;
  int get snoozeMinutes => _snoozeMinutes;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadSettings();
  }

  void _loadSettings() {
    // Theme
    final themeName = _box.get(_themeKey, defaultValue: 'dark');
    _themeMode = themeName == 'light' ? ThemeMode.light : ThemeMode.dark;

    // Battery saver
    _batterySaverEnabled = _box.get(_batterySaverKey, defaultValue: true);

    // PIN
    _pin = _box.get(_pinKey);

    // Interval (back-compat)
    _biteInterval = (_box.get(_biteIntervalKey, defaultValue: 90.0) as num).toDouble();

    // Mindful config
    _mode = _InterventionModeCodec.fromKey(_box.get(_modeKey, defaultValue: 'nudges') as String?);
    _mindfulEnabled = _box.get(_mindfulEnabledKey, defaultValue: true) as bool;
    _shortRestSeconds = _box.get(_shortRestSecondsKey, defaultValue: 20) as int;
    _snoozeMinutes = _box.get(_snoozeMinutesKey, defaultValue: 1) as int;

    notifyListeners();
  }

  // ==== THEME ====
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _box.put(_themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  // ==== BATTERY ====
  Future<void> setBatterySaver(bool enabled) async {
    _batterySaverEnabled = enabled;
    await _box.put(_batterySaverKey, enabled);
    notifyListeners();
  }

  // ==== PIN ====
  Future<void> setPin(String? pin) async {
    _pin = pin;
    if (pin == null) {
      await _box.delete(_pinKey);
    } else {
      await _box.put(_pinKey, pin);
    }
    notifyListeners();
  }

  // ==== INTERVALS ====
  /// Primary setter used everywhere (seconds).
  Future<void> setBiteInterval(double intervalSeconds) async {
    _biteInterval = intervalSeconds;
    await _box.put(_biteIntervalKey, intervalSeconds);
    notifyListeners();
  }

  // ==== MINDFUL CONTROLS ====
  Future<void> setMindfulEnabled(bool enabled) async {
    _mindfulEnabled = enabled;
    await _box.put(_mindfulEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setMode(InterventionMode m) async {
    _mode = m;
    await _box.put(_modeKey, m.key);
    notifyListeners();
  }

  Future<void> setShortRestSeconds(int seconds) async {
    _shortRestSeconds = seconds.clamp(5, 120);
    await _box.put(_shortRestSecondsKey, _shortRestSeconds);
    notifyListeners();
  }

  Future<void> setSnoozeMinutes(int minutes) async {
    _snoozeMinutes = minutes.clamp(1, 10);
    await _box.put(_snoozeMinutesKey, _snoozeMinutes);
    notifyListeners();
  }

  // ============================================================
  // Back-compat shims (to satisfy existing call sites)
  // ============================================================

  /// Old getter name used in some screens. Maps to [_biteInterval].
  double? get mindfulBreakInterval => _biteInterval;

  /// Old setter name → forwards to [setBiteInterval].
  @Deprecated('Use setBiteInterval instead.')
  Future<void> setMindfulBreakInterval(double seconds) => setBiteInterval(seconds);

  /// Old flag name for “smart verification”; now maps to mindfulEnabled (non-coercive).
  bool get smartVerification => _mindfulEnabled;

  @Deprecated('Use setMindfulEnabled instead.')
  Future<void> setSmartVerification(bool enabled) => setMindfulEnabled(enabled);

  /// Old “sessionMode” getter expected by some screens.
  InterventionMode get sessionMode => _mode;

  /// Sometimes callers want a string key.
  String get sessionModeKey => _mode.key;

  /// Old setter that may pass enum, string ('observe'|'nudges'|'coach'|'lock'), or int (0..3).
  @Deprecated('Use setMode instead.')
  Future<void> setSessionMode(dynamic value) async {
    if (value is InterventionMode) {
      await setMode(value);
      return;
    }
    if (value is String) {
      await setMode(_InterventionModeCodec.fromKey(value));
      return;
    }
    if (value is int) {
      final all = InterventionMode.values;
      final idx = value.clamp(0, all.length - 1);
      await setMode(all[idx]);
      return;
    }
    // Unknown type: no-op
  }
}
