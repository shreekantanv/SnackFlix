import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snackflix/utils/router.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentSetupScreen extends StatefulWidget {
  @override
  _ParentSetupScreenState createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _urlController = TextEditingController();
  double _biteInterval = 90;
  bool _smartVerification = true;

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null) {
      _urlController.text = clipboardData.text ?? '';
    }
  }

  void _openYouTubeKids() async {
    final url = Uri.parse('https://www.youtubekids.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open YouTube Kids.')),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How SnackFlix Works'),
        content: SingleChildScrollView(
          child: Text(
            '1. Paste a video URL from YouTube or another website.\n'
            '2. Set the "Bite Interval" to decide how often the app should check if your child is eating.\n'
            '3. "Smart Verification" uses the camera to look for a face and listen for chewing sounds.\n'
            '4. The session will start, and the video will pause at each interval for verification.',
          ),
        ),
        actions: [
          TextButton(
            child: Text('Got it!'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parent Setup'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVideoSource(),
            SizedBox(height: 24),
            _buildBiteIntervalSlider(),
            SizedBox(height: 24),
            _buildSmartVerificationToggle(),
            Spacer(),
            ElevatedButton(
              child: Text('Start Session'),
              onPressed: () {
                if (_urlController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a video URL.')),
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  AppRouter.childPlayer,
                  arguments: {
                    'videoUrl': _urlController.text,
                    'biteInterval': _biteInterval,
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSource() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video Source', style: Theme.of(context).textTheme.headline6),
        SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: 'Paste URL (YouTube/YouTube Kids/web URL)',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              child: Text('Open YouTube Kids'),
              onPressed: _openYouTubeKids,
            ),
            TextButton(
              child: Text('Paste from clipboard'),
              onPressed: _pasteFromClipboard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiteIntervalSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bite Interval: ${_biteInterval.toInt()}s',
            style: Theme.of(context).textTheme.headline6),
        Slider(
          value: _biteInterval,
          min: 45,
          max: 180,
          label: '${_biteInterval.toInt()}s',
          onChanged: (value) {
            setState(() {
              // Round to nearest 5 to make it a bit less granular
              _biteInterval = (value / 5).round() * 5.0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSmartVerificationToggle() {
    return SwitchListTile(
      title: Text('Smart verification'),
      subtitle: Text('Chewing + snack nearby'),
      value: _smartVerification,
      onChanged: (value) {
        setState(() {
          _smartVerification = value;
        });
      },
    );
  }
}
