import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/services/metrics_service.dart';
import 'package:snackflix/utils/router.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final metricsSvc = context.watch<MetricsService>();
    final allMetrics = metricsSvc.getAllMetrics();

    if (allMetrics.isEmpty) {
      return Center(
        child: Text(t.noHistoryMessage),
      );
    }

    // Since Hive boxes are ordered, we can rely on the default order.
    // If we wanted to be extra safe, we'd sort by date.
    return ListView.builder(
      itemCount: allMetrics.length,
      itemBuilder: (context, index) {
        final dailyMetrics = allMetrics[index];
        final sessionDate = DateTime.fromMillisecondsSinceEpoch(
            dailyMetrics.date.millisecondsSinceEpoch);
        final formattedDate = DateFormat.yMMMd().format(sessionDate);

        // Aggregate metrics for the day to show in the list tile.
        final totalDuration = dailyMetrics.sessions.fold(
            Duration.zero, (prev, s) => prev + s.durationWatched);
        final totalPrompts = dailyMetrics.sessions
            .fold(0, (prev, s) => prev + s.promptsShown);

        return ListTile(
          title: Text(formattedDate),
          subtitle: Text(
            t.historyListItemSubtitle(
              totalDuration.inMinutes,
              totalPrompts,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // For now, let's just navigate to the summary of the first session of that day.
            // A more advanced implementation might show a daily summary or let the user pick a session.
            if (dailyMetrics.sessions.isNotEmpty) {
              Navigator.pushNamed(
                context,
                AppRouter.sessionSummary,
                arguments: {
                  'metrics': dailyMetrics.sessions.first,
                  'isPostSession': false,
                },
              );
            }
          },
        );
      },
    );
  }
}