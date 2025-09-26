import 'package:hive/hive.dart';

part 'daily_metrics.g.dart';

@HiveType(typeId: 1)
class DailyMetrics extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  int durationWatchedSec = 0;

  @HiveField(2)
  int promptsShown = 0;

  @HiveField(3)
  int autoCleared = 0;

  @HiveField(4)
  int manualOverrides = 0;

  DailyMetrics({required this.date});
}
