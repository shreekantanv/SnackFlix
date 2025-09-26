import 'package:hive/hive.dart';
import 'package:snackflix/services/session_tracker.dart';

part 'daily_metrics.g.dart';

@HiveType(typeId: 1)
class DailyMetrics extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  List<SessionMetrics> sessions;

  DailyMetrics({required this.date, List<SessionMetrics>? sessions})
      : sessions = sessions ?? [];
}