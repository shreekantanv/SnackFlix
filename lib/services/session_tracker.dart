// lib/services/session_tracker.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'session_tracker.g.dart';

@HiveType(typeId: 0)
class SessionMetrics extends HiveObject {
  @HiveField(0)
  final DateTime startedAt;

  @HiveField(1)
  DateTime? endedAt;

  @HiveField(2)
  int promptsShown = 0;

  @HiveField(3)
  int autoCleared = 0;

  @HiveField(4)
  int manualOverrides = 0;

  @HiveField(5)
  int durationWatchedSec = 0;

  SessionMetrics() : startedAt = DateTime.now();

  Duration get durationWatched => Duration(seconds: durationWatchedSec);

  void end() {
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

import 'package:snackflix/services/metrics_service.dart';

class SessionTracker extends ChangeNotifier {
  SessionMetrics? _m;
  SessionMetrics get metrics => _m ??= SessionMetrics();
  final Stopwatch _watch = Stopwatch();
  final MetricsService _metricsService;

  SessionTracker(this._metricsService);

  void start() {
    _m = SessionMetrics();
    _watch.reset();
    _watch.start();
    notifyListeners();
  }

  void end() {
    _watch.stop();
    metrics.durationWatchedSec = _watch.elapsed.inSeconds;
    _m?.end();
    _metricsService.saveMetrics(metrics);
    notifyListeners();
  }

  // Event helpers
  void onVideoPlay()  { if (!_watch.isRunning) _watch.start();  notifyListeners(); }
  void onVideoPause() { if (_watch.isRunning) _watch.stop(); notifyListeners(); }

  void onPromptShown()      { metrics.promptsShown++; notifyListeners(); }
  void onPromptAutoClear()  { metrics.autoCleared++;  notifyListeners(); }
  void onManualOverride()   { metrics.manualOverrides++; notifyListeners(); }
}
