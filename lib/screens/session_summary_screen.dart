import 'package:flutter/material.dart';
import 'package:snackflix/utils/router.dart';

class SessionSummaryScreen extends StatefulWidget {
  @override
  _SessionSummaryScreenState createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  String? _feedback;

  @override
  Widget build(BuildContext context) {
    // TODO: Get real data
    const totalWatchTime = "15:32";
    const promptCount = 10;
    const autoClearRate = 80.0;

    return Scaffold(
      appBar: AppBar(
        title: Text("Session Summary"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStat("Total Watch Time", totalWatchTime),
            _buildStat("Prompt Count", promptCount.toString()),
            _buildStat("Auto-Clear Rate", "${autoClearRate.toStringAsFixed(0)}%"),
            SizedBox(height: 32),
            _buildFeedbackSurvey(),
            Spacer(),
            ElevatedButton(
              child: Text("Done"),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.parentSetup,
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildFeedbackSurvey() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Did SnackFlix help today?", style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFeedbackButton("Yes"),
            _buildFeedbackButton("A Little"),
            _buildFeedbackButton("No"),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackButton(String label) {
    final isSelected = _feedback == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _feedback = label;
          });
        }
      },
    );
  }
}
