// imports...
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';

import '../services/metrics_service.dart';
import '../services/session_tracker.dart';
import '../utils/router.dart';
import '../widgets/pre_flight_tips.dart';
import '../widgets/verify_overlay.dart';

import 'dart:async'; // <-- for Timer
import 'package:youtube_player_iframe/youtube_player_iframe.dart'; // <-- add this

class ChildPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final double biteInterval;
  const ChildPlayerScreen({super.key, this.videoUrl, required this.biteInterval});

  @override
  State<ChildPlayerScreen> createState() => _ChildPlayerScreenState();
}

class _ChildPlayerScreenState extends State<ChildPlayerScreen> with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl ?? '');
    if (videoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidYoutubeUrl)));
        Navigator.of(context).pop();
      });
      return;
    }

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(showControls: false, showFullscreenButton: false),
    );

    // Start counting as soon as playback begins
    context.read<SessionTracker>().onVideoPlay();

    WidgetsBinding.instance.addPostFrameCallback((_) => _showPreFlightTips());
    _startVerificationTimer(Duration(seconds: widget.biteInterval.toInt()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracker = context.read<SessionTracker>();
    if (state == AppLifecycleState.paused) {
      _controller.pauseVideo();
      tracker.onVideoPause();
    } else if (state == AppLifecycleState.resumed) {
      // Do not auto-play; wait for verification overlay to clear.
    }
  }

  void _showPreFlightTips() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const PreFlightTips());
  }

  void _startVerificationTimer(Duration interval) {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(interval, (_) {
      final tracker = context.read<SessionTracker>();
      _controller.pauseVideo();
      tracker.onVideoPause();
      tracker.onPromptShown();
      _showVerificationOverlay();
    });
  }

  void _showVerificationOverlay() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => VerifyOverlay(
          onVerificationSuccess: () {
            Navigator.of(context).pop();
            context.read<SessionTracker>().onVideoPlay();
            _controller.playVideo();
            // If your overlay auto-dismisses because kid is eating, call onPromptAutoClear there.
          },
          onManualContinue: () {
            Navigator.of(context).pop();
            final tracker = context.read<SessionTracker>();
            tracker.onManualOverride();
            tracker.onVideoPlay();
            _controller.playVideo();
          },
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    // stop timers + video
    _verificationTimer?.cancel();
    _controller.pauseVideo();
    context.read<SessionTracker>().onVideoPause();
    context.read<SessionTracker>().end();

    // go to summary
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.sessionSummary);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationTimer?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return WillPopScope(
      onWillPop: () async => false, // block back
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(t.playbackTitle), // "Now Playing"
          actions: [
            TextButton(
              onPressed: _endSession,
              child: Text(t.endSessionCta), // "End session"
            ),
          ],
        ),
        body: Stack(
          children: [
            Center(child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9)),
            // Keep your hidden long-press exit if you like.
          ],
        ),
      ),
    );
  }
}
