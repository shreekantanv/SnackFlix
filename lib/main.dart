import 'package:flutter/material.dart';
import 'package:snackflix/utils/app_themes.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/screens/app_intro_screen.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnackFlix',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      onGenerateRoute: AppRouter.generateRoute,
      home: AppIntroScreen(),
    );
  }
}
