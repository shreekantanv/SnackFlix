import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';
  static const String _batterySaverKey = 'batterySaver';
  static const String _pinKey = 'pin';

  late Box _box;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _batterySaverEnabled = true;
  bool get batterySaverEnabled => _batterySaverEnabled;

  String? _pin;
  String? get pin => _pin;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadSettings();
  }

  void _loadSettings() {
    // Load theme
    final themeName = _box.get(_themeKey, defaultValue: 'dark');
    _themeMode = themeName == 'light' ? ThemeMode.light : ThemeMode.dark;

    // Load battery saver
    _batterySaverEnabled = _box.get(_batterySaverKey, defaultValue: true);

    // Load pin
    _pin = _box.get(_pinKey);

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _box.put(_themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setBatterySaver(bool enabled) async {
    _batterySaverEnabled = enabled;
    await _box.put(_batterySaverKey, enabled);
    notifyListeners();
  }

  Future<void> setPin(String? pin) async {
    _pin = pin;
    if (pin == null) {
      await _box.delete(_pinKey);
    } else {
      await _box.put(_pinKey, pin);
    }
    notifyListeners();
  }
}