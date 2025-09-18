import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:snackflix/widgets/pre_flight_tips.dart';
import 'package:snackflix/widgets/exit_confirm_dialog.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/widgets/verify_overlay.dart';

class ChildPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final double biteInterval;

  ChildPlayerScreen({this.videoUrl, required this.biteInterval});

  @override
  _ChildPlayerScreenState createState() => _ChildPlayerScreenState();
}

class _ChildPlayerScreenState extends State<ChildPlayerScreen> {
  late YoutubePlayerController _controller;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(
      widget.videoUrl ?? 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );

    _controller = YoutubePlayerController(
      initialVideoId: videoId!,
      params: YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        autoPlay: true,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _showPreFlightTips());
    _startVerificationTimer(Duration(seconds: widget.biteInterval.toInt()));
  }

  void _showPreFlightTips() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PreFlightTips(),
    );
  }

  void _startVerificationTimer(Duration interval) {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(interval, (timer) {
      _controller.pause();
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
            _controller.play();
          },
          onManualContinue: () {
            Navigator.of(context).pop();
            _controller.play();
            // TODO: Log manual continue
          },
        ),
      ),
    );
  }

  Future<void> _showExitConfirmDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => ExitConfirmDialog(),
    );
    if (shouldExit == true) {
      Navigator.pushReplacementNamed(context, AppRouter.sessionSummary);
    }
  }


  @override
  void dispose() {
    _controller.close();
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: YoutubePlayerIFrame(
              controller: _controller,
              aspectRatio: 16 / 9,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onLongPress: _showExitConfirmDialog,
              child: Container(
                width: 100,
                height: 100,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
