import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // 👈 add this
import 'package:snackflix/services/metrics_service.dart';

import 'package:snackflix/utils/app_themes.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/screens/app_intro_screen.dart';

import 'l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 👇 Provide app-wide state above MaterialApp
    return ChangeNotifierProvider(
      create: (_) => SessionTracker()..start(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appName ?? 'SnackFlix',

        theme: AppThemes.lightTheme,
        darkTheme: AppThemes.darkTheme,
        themeMode: ThemeMode.system,

        onGenerateRoute: AppRouter.generateRoute,
        home: const AppIntroScreen(),

        // 🔤 Localization
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
