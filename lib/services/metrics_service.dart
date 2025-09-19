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

    dailyMetrics.durationWatchedSec += metrics.durationWatchedSec;
    dailyMetrics.promptsShown += metrics.promptsShown;
    dailyMetrics.autoCleared += metrics.autoCleared;
    dailyMetrics.manualOverrides += metrics.manualOverrides;

    await _metricsBox.put(key, dailyMetrics);
  }

  List<DailyMetrics> getMetricsForLastYear() {
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return _metricsBox.values.where((m) => m.date.isAfter(oneYearAgo)).toList();
  }

  List<DailyMetrics> getMetricsForLastMonth() {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    return _metricsBox.values.where((m) => m.date.isAfter(oneMonthAgo)).toList();
  }

  List<DailyMetrics> getMetricsForLastWeek() {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _metricsBox.values.where((m) => m.date.isAfter(oneWeekAgo)).toList();
  }
}
