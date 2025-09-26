import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:snackflix/screens/app_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/screens/app_intro_screen.dart';
import 'package:snackflix/screens/main_screen.dart';
import 'package:snackflix/screens/permissions_gate_screen.dart';
import 'package:snackflix/screens/child_player_screen.dart';
import 'package:snackflix/screens/session_summary_screen.dart';

class AppRouter {
  static const String appIntro = '/';
  static const String permissionsGate = '/permissions';
  static const String main = '/main';
  static const String childPlayer = '/child-player';
  static const String sessionSummary = '/session-summary';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case appIntro:
        return MaterialPageRoute(builder: (_) => const AppIntroScreen());
      case permissionsGate:
        return MaterialPageRoute(builder: (_) => const PermissionsGateScreen());
      case main:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => MainScreen(initialIndex: args?['initialIndex'] ?? 0),
        );
      case childPlayer:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChildPlayerScreen(
            videoUrl: args['videoUrl'],
            biteInterval: args['biteInterval'],
          ),
        );
      case sessionSummary:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(
            metrics: args['metrics'],
            isPostSession: args['isPostSession'] ?? false,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
