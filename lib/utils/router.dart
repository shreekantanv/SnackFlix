import 'package:flutter/material.dart';
import 'package:snackflix/screens/app_intro_screen.dart';
import 'package:snackflix/screens/permissions_gate_screen.dart';
import 'package:snackflix/screens/parent_setup_screen.dart';
import 'package:snackflix/screens/child_player_screen.dart';
import 'package:snackflix/screens/session_summary_screen.dart';

class AppRouter {
  static const String appIntro = '/';
  static const String permissionsGate = '/permissions';
  static const String parentSetup = '/parent-setup';
  static const String childPlayer = '/child-player';
  static const String sessionSummary = '/session-summary';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case appIntro:
        return MaterialPageRoute(builder: (_) => AppIntroScreen());
      case permissionsGate:
        return MaterialPageRoute(builder: (_) => PermissionsGateScreen());
      case parentSetup:
        return MaterialPageRoute(builder: (_) => ParentSetupScreen());
      case childPlayer:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChildPlayerScreen(
            videoUrl: args['videoUrl'],
            biteInterval: args['biteInterval'],
          ),
        );
      case sessionSummary:
        return MaterialPageRoute(builder: (_) => SessionSummaryScreen());
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
