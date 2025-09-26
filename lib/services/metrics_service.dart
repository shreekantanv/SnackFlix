import 'package:hive/hive.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/services/session_tracker.dart';

class MetricsService {
  late Box<DailyMetrics> _metricsBox;

  Future<void> init() async {
    _metricsBox = await Hive.openBox<DailyMetrics>('daily_metrics');
  }

  Future<void> saveMetrics(SessionMetrics metrics) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Use a key for today's date to easily find it.
    final key = todayDate.toIso8601String();
    final dailyMetrics = _metricsBox.get(key) ?? DailyMetrics(date: todayDate);

    // Add the new session to the list
    dailyMetrics.sessions.add(metrics);

    // Save the updated daily metrics
    await _metricsBox.put(key, dailyMetrics);
  }

  // Method to get all metrics for the history screen
  List<DailyMetrics> getAllMetrics() {
    return _metricsBox.values.toList();
  }
}