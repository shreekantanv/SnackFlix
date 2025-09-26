import 'package:flutter/material.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/models/daily_metrics.dart';
import 'package:snackflix/utils/router.dart';

class SessionSummaryScreen extends StatelessWidget {
  final SessionMetrics metrics;
  final bool isPostSession;

  const SessionSummaryScreen({
    super.key,
    required this.metrics,
    this.isPostSession = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    String mins(Duration d) => '${d.inMinutes} ${t.minAbbrev}';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.sessionSummaryTitle),
        automaticallyImplyLeading: !isPostSession,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Text(t.sessionStatsHeader,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(
                          title: t.statDurationWatched,
                          value: mins(metrics.durationWatched)),
                      _StatCard(
                          title: t.statPromptsShown,
                          value: '${metrics.promptsShown}'),
                      _StatCard(
                          title: t.statAutoCleared,
                          value: '${metrics.autoCleared}'),
                      _StatCard(
                          title: t.statManualOverrides,
                          value: '${metrics.manualOverrides}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(t.feedbackHeader,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(t.feedbackQuestion),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(onPressed: () {}, child: Text(t.yes)),
                      OutlinedButton(
                          onPressed: () {}, child: Text(t.aLittle)),
                      OutlinedButton(onPressed: () {}, child: Text(t.no)),
                    ],
                  ),
                ],
              ),
            ),
            if (isPostSession)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: cs.primary),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppRouter.main, (_) => false);
                  },
                  child: Text(t.done),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}