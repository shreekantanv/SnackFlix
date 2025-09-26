import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/services/metrics_service.dart';
import 'package:snackflix/services/session_tracker.dart';
import 'package:snackflix/services/theme_notifier.dart';
import 'package:snackflix/utils/app_themes.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/screens/main_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(SessionMetricsAdapter());
  Hive.registerAdapter(DailyMetricsAdapter());
  // Clear the box to handle data migration issues during development
  await Hive.deleteBoxFromDisk('daily_metrics');
  final metricsService = MetricsService();
  await metricsService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<MetricsService>.value(value: metricsService),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(
          create: (context) =>
              SessionTracker(context.read<MetricsService>())..start(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (ctx) =>
              AppLocalizations.of(ctx)?.appName ?? 'SnackFlix',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeNotifier.themeMode,
          onGenerateRoute: AppRouter.generateRoute,
          home: const MainScreen(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
