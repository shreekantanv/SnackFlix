import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/services/theme_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SwitchListTile(
              title: Text(t.settingsThemeToggle),
              subtitle: Text(themeNotifier.themeMode == ThemeMode.dark
                  ? t.settingsThemeDark
                  : t.settingsThemeLight),
              value: themeNotifier.themeMode == ThemeMode.dark,
              onChanged: (value) {
                themeNotifier.toggleTheme();
              },
              secondary: const Icon(Icons.brightness_6_outlined),
            ),
          ],
        );
      },
    );
  }
}