import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // 👈 add this
import 'package:snackflix/services/metrics_service.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/services/session_tracker.dart';

import 'package:snackflix/utils/app_themes.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/screens/app_intro_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(SessionMetricsAdapter());
  Hive.registerAdapter(DailyMetricsAdapter());
  final metricsService = MetricsService();
  await metricsService.init();
  runApp(MyApp(metricsService: metricsService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.metricsService});
  final MetricsService metricsService;

  @override
  Widget build(BuildContext context) {
    // 👇 Provide app-wide state above MaterialApp
    return Provider<MetricsService>.value(
      value: metricsService,
      child: ChangeNotifierProvider(
        create: (context) =>
            SessionTracker(context.read<MetricsService>())..start(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,

          onGenerateTitle: (ctx) =>
              AppLocalizations.of(ctx)?.appName ?? 'SnackFlix',

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
      ),
    );
  }
}
