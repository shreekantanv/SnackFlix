import 'package:flutter/material.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/screens/history_screen.dart';
import 'package:snackflix/screens/parent_setup_screen.dart';
import 'package:snackflix/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  static final List<Widget> _widgetOptions = <Widget>[
    const ParentSetupScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  String _getTitle(BuildContext context, int index) {
    final t = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return t.parentSetupTitle;
      case 1:
        return t.historyTab;
      case 2:
        return t.settingsTab;
      default:
        return t.appName;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: t.homeTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: t.historyTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: t.settingsTab,
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}