import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/services/metrics_service.dart';
import 'package:snackflix/services/session_tracker.dart';
import 'package:snackflix/utils/router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext
      .context) {
    final t = AppLocalizations.of(context)!;
    final metricsSvc = context.watch<MetricsService>();
    final allMetrics = metricsSvc.getAllMetrics();

    if (allMetrics.isEmpty) {
      return Center(
        child: Text(t.noHistoryMessage),
      );
    }

    return _buildHistoryView(context, t, allMetrics, metricsSvc);
  }

  Widget _buildHistoryView(BuildContext context, AppLocalizations t, List<DailyMetrics> allMetrics, MetricsService metricsSvc) {
    final sevenDaysMetrics = metricsSvc.getMetricsForLastDays(7);
    final totalDurationLast7Days = sevenDaysMetrics.fold<Duration>(
      Duration.zero,
          (prev, dm) => prev + dm.sessions.fold(Duration.zero, (p, s) => p + s.durationWatched),
    );

    // Flatten the list of sessions for the "Past Sessions" list
    final allSessions = allMetrics.expand((dm) => dm.sessions).toList();
    allSessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));


    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(t, allSessions.first),
            const SizedBox(height: 8),
            _buildTotalDuration(t, totalDurationLast7Days),
            const SizedBox(height: 24),
            _buildChart(context, sevenDaysMetrics),
            const SizedBox(height: 32),
            _buildPastSessions(context, t, allSessions),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations t, SessionMetrics latestSession) {
    final videoId = YoutubePlayerController.convertUrlToId(latestSession.url ?? '');
    // In a real app, we'd fetch the video title. For now, just show the ID.
    final title = videoId ?? 'Stitch - Design with AI';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.watchTimeHistoryTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
        ),
      ],
    );
  }

  Widget _buildTotalDuration(AppLocalizations t, Duration totalDuration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.durationWatchedTitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          t.minutes(totalDuration.inMinutes),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        Text(t.last7Days, style: const TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  Widget _buildChart(BuildContext context, List<DailyMetrics> metrics) {
    final spots = List.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      final metricsForDay = metrics.where((m) =>
      m.date.year == day.year && m.date.month == day.month && m.date.day == day.day);

      if (metricsForDay.isEmpty) {
        return FlSpot(index.toDouble(), 0);
      }

      final totalMinutes = metricsForDay.first.sessions
          .fold(Duration.zero, (p, s) => p + s.durationWatched)
          .inMinutes;
      return FlSpot(index.toDouble(), totalMinutes.toDouble());
    });

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final day = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(DateFormat.E().format(day), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green.shade400,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade200.withOpacity(0.4),
                    Colors.green.shade200.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastSessions(BuildContext context, AppLocalizations t, List<SessionMetrics> sessions) {
    String _formatRelativeDate(DateTime date) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessionDay = DateTime(date.year, date.month, date.day);
      final difference = today.difference(sessionDay).inDays;

      if (difference == 0) return t.today;
      if (difference == 1) return t.yesterday;
      return t.daysAgo(difference);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.pastSessionsTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final formattedDate = _formatRelativeDate(session.startedAt);
            final formattedTime = DateFormat.jm().format(session.startedAt);

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(
                t.minutes(session.durationWatched.inMinutes),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              trailing: Text(formattedTime, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRouter.sessionSummary,
                  arguments: {'metrics': session, 'isPostSession': false},
                );
              },
            );
          },
        ),
      ],
    );
  }
}