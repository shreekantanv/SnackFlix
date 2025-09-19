// lib/services/session_tracker.dart
import 'package:flutter/foundation.dart';

class SessionMetrics {
  final DateTime startedAt;
  DateTime? endedAt;

  int promptsShown = 0;
  int autoCleared = 0;
  int manualOverrides = 0;

  /// Stopwatch counts “active watch time” (we start/stop it when video plays/pauses).
  final Stopwatch _watch = Stopwatch();

  SessionMetrics() : startedAt = DateTime.now();

  Duration get durationWatched => _watch.elapsed;

  void markPlay()  { if (!_watch.isRunning) _watch.start(); }
  void markPause() { if (_watch.isRunning) _watch.stop();  }

  void end() {
    markPause();
    endedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'promptsShown': promptsShown,
    'autoCleared': autoCleared,
    'manualOverrides': manualOverrides,
    'durationWatchedSec': durationWatched.inSeconds,
  };
}

class SessionTracker extends ChangeNotifier {
  SessionMetrics? _m;
  SessionMetrics get metrics => _m ??= SessionMetrics();

  void start() {
    _m = SessionMetrics();
    notifyListeners();
  }

  void end() {
    _m?.end();
    notifyListeners();
  }

  // Event helpers
  void onVideoPlay()  { metrics.markPlay();  notifyListeners(); }
  void onVideoPause() { metrics.markPause(); notifyListeners(); }

  void onPromptShown()      { metrics.promptsShown++; notifyListeners(); }
  void onPromptAutoClear()  { metrics.autoCleared++;  notifyListeners(); }
  void onManualOverride()   { metrics.manualOverrides++; notifyListeners(); }
}
