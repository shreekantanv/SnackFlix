// lib/screens/session_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/utils/router.dart';

import '../services/metrics_service.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final metrics = context.watch<SessionTracker>().metrics;

    String mins(Duration d) => '${d.inMinutes} ${t.minAbbrev}'; // "min"

    return Scaffold(
      appBar: AppBar(
        title: Text(t.sessionSummaryTitle), // "Session Summary"
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(t.sessionStatsHeader, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(title: t.statDurationWatched, value: mins(metrics.durationWatched)),
              _StatCard(title: t.statPromptsShown,  value: '${metrics.promptsShown}'),
              _StatCard(title: t.statAutoCleared,   value: '${metrics.autoCleared}'),
              _StatCard(title: t.statManualOverrides,value: '${metrics.manualOverrides}'),
            ],
          ),
          const SizedBox(height: 24),
          Text(t.feedbackHeader, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(t.feedbackQuestion), // "Did SnackFlix help today?"
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(onPressed: () {/* save "yes" */}, child: Text(t.yes)),
              OutlinedButton(onPressed: () {/* save "a little" */}, child: Text(t.aLittle)),
              OutlinedButton(onPressed: () {/* save "no" */}, child: Text(t.no)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: cs.primary),
          onPressed: () {
            // persist metrics if you want (Firestore, local DB, etc.)
            Navigator.pushNamedAndRemoveUntil(context, AppRouter.appIntro, (_) => false);
          },
          child: Text(t.endSessionCta), // **"End session"** instead of "Done"
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
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
