import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        SwitchListTile(
          title: Text(t.settingsThemeToggle),
          subtitle: Text(settings.themeMode == ThemeMode.dark
              ? t.settingsThemeDark
              : t.settingsThemeLight),
          value: settings.themeMode == ThemeMode.dark,
          onChanged: (value) {
            settings.toggleTheme();
          },
          secondary: const Icon(Icons.brightness_6_outlined),
        ),
        const Divider(),
        SwitchListTile(
          title: Text(t.settingsBatterySaverToggle),
          subtitle: Text(settings.batterySaverEnabled
              ? t.settingsBatterySaverEnabled
              : t.settingsBatterySaverDisabled),
          value: settings.batterySaverEnabled,
          onChanged: (value) {
            settings.setBatterySaver(value);
          },
          secondary: const Icon(Icons.battery_saving_outlined),
        ),
      ],
    );
  }
}