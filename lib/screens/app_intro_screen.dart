import 'package:flutter/material.dart';
import 'package:snackflix/utils/router.dart';

class AppIntroScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Spacer(),
              Text(
                'SnackFlix',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(
                'Plays when eating, pauses when not',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Spacer(),
              _buildHowItWorks(context),
              Spacer(),
              _buildPrivacyAndSafety(context),
              Spacer(),
              ElevatedButton(
                child: Text('Get Started'),
                onPressed: () {
                  Navigator.pushNamed(context, AppRouter.permissionsGate);
                },
              ),
              TextButton(
                child: Text('Read Privacy'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Privacy Policy'),
                      content: SingleChildScrollView(
                        child: Text(
                          'This is a placeholder for the privacy policy. '
                          'In a real app, this would contain information about data handling, etc.'
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: Text('Close'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              TextButton(
                child: Text('Skip'),
                onPressed: () {
                  Navigator.pushNamed(context, AppRouter.parentSetup);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    return Column(
      children: [
        Text(
          'How it works',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 16),
        Text('Interval → Pause → Quick on-device check → Resume'),
      ],
    );
  }

  Widget _buildPrivacyAndSafety(BuildContext context) {
    return Column(
      children: [
        Text(
          'Privacy & Safety',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 16),
        Text('• On-device analysis only'),
        Text('• Camera active briefly during checks'),
        Text('• Manual Continue after 15s'),
        Text('• Parent hidden exit (long-press 3s, top-left)'),
      ],
    );
  }
}
