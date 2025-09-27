import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/services/chewing_detection_service.dart';
import 'package:snackflix/services/settings_service.dart';
import 'package:snackflix/widgets/overlay_painter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/session_tracker.dart';
import '../utils/router.dart';
import '../widgets/pre_flight_tips.dart';

class ChildPlayerScreen extends StatelessWidget {
  final String? videoUrl;
  final double biteInterval;

  const ChildPlayerScreen({super.key, this.videoUrl, required this.biteInterval});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsService>();
    return ChangeNotifierProvider(
      create: (_) => ChewingDetectionService(
        batterySaverEnabled: settings.batterySaverEnabled,
      ),
      child: _ChildPlayerScreenContent(
        videoUrl: videoUrl,
        biteInterval: biteInterval,
      ),
    );
  }
}

class _ChildPlayerScreenContent extends StatefulWidget {
  final String? videoUrl;
  final double biteInterval;

  const _ChildPlayerScreenContent({this.videoUrl, required this.biteInterval});

  @override
  State<_ChildPlayerScreenContent> createState() => _ChildPlayerScreenContentState();
}

class _ChildPlayerScreenContentState extends State<_ChildPlayerScreenContent> with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  late final ChewingDetectionService _chewingService;
  Timer? _pauseDwell;
  bool _playerLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chewingService = context.read<ChewingDetectionService>();
    _chewingService.addListener(_onChewingStateChanged);

    final videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl ?? '');
    if (videoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidYoutubeUrl)));
        Navigator.of(context).pop();
      });
      return;
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chewingService.initialize().then((_) {
        if (mounted) setState(() {});
      });
      context.read<SessionTracker>().start(url: widget.videoUrl);
      _showPreFlightTips();
    });
  }

  void _onChewingStateChanged() {
    final eating = _chewingService.state == EatState.chewing || _chewingService.state == EatState.grace;
    _applyDecision(eating);
    setState(() {}); // To rebuild UI with new status, confidence, etc.
  }

  void _applyDecision(bool eating) {
    if (eating) {
      // Eating: cancel any pending lock timer, unlock if needed, and (re)play.
      _pauseDwell?.cancel();
      _pauseDwell = null;

      if (_playerLocked) {
        setState(() => _playerLocked = false);
      }

      // Only play if not locked (defensive) and not already playing.
      if (!_playerLocked && _controller.value.playerState != PlayerState.playing) {
        _controller.playVideo();
        context.read<SessionTracker>().onVideoPlay();
      }
      return;
    }

    // Not eating: arm a dwell timer if one isn't already running.
    _armDwellTimer();
  }

  void _armDwellTimer() {
    if (_pauseDwell != null) return; // already armed

    final wait = Duration(seconds: widget.biteInterval.ceil());
    _pauseDwell = Timer(wait, () {
      // Allow future timers to arm again.
      _pauseDwell = null;

      // If eating resumed during the wait, do nothing.
      final stillNotEating = !(_chewingService.state == EatState.chewing ||
          _chewingService.state == EatState.grace);
      if (!mounted || !stillNotEating) return;

      // Pause & lock regardless of reported player state (it can be stale).
      _controller.pauseVideo();
      context.read<SessionTracker>().onVideoPause();

      if (!_playerLocked) {
        setState(() => _playerLocked = true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.pauseVideo();
      context.read<SessionTracker>().onVideoPause();
      _chewingService.pause();
    } else if (state == AppLifecycleState.resumed) {
      _chewingService.resume().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _showPreFlightTips() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const PreFlightTips());
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    final t = AppLocalizations.of(context)!;
    final settings = context.read<SettingsService>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.enterPinTitle),
        content: TextField(
          controller: pinController,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(
            hintText: t.pinHint,
            counterText: '',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == settings.pin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.incorrectPin)));
              }
            },
            child: Text(t.submit),
          ),
        ],
      ),
    );

    if (ok == true) {
      // NEW: record manual override
      context.read<SessionTracker>().onManualOverride();
      setState(() => _playerLocked = false);
      _controller.playVideo();
      context.read<SessionTracker>().onVideoPlay();
    }
  }

  Future<void> _endSession() async {
    _pauseDwell?.cancel();
    _controller.pauseVideo();
    context.read<SessionTracker>().onVideoPause();
    context.read<SessionTracker>().end();

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRouter.sessionSummary,
      arguments: {
        'metrics': context.read<SessionTracker>().metrics,
        'isPostSession': true,
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chewingService.removeListener(_onChewingStateChanged);
    _chewingService.dispose();
    _pauseDwell?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final chewingService = context.watch<ChewingDetectionService>();
    final eating = chewingService.status.startsWith('Eating');

    return WillPopScope(
      onWillPop: () async => false, // block back
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(t.playbackTitle), // "Now Playing"
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (eating ? Colors.green : Colors.red).withOpacity(.15),
                border: Border.all(color: eating ? Colors.green : Colors.red),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                chewingService.status,
                style: TextStyle(
                  color: eating ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_playerLocked)
              TextButton.icon(
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(t.parentOverride),
                onPressed: _showPinDialog,
              )
            else
              TextButton(
                onPressed: _endSession,
                child: Text(t.endSessionCta), // "End session"
              ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
                  if (_playerLocked)
                    Positioned.fill(
                      child: AbsorbPointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                          child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 80),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Camera tile
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: eating ? Colors.green : Colors.red, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 180,
                    height: 240,
                    child: Stack(
                      children: [
                        if (chewingService.isCameraReady &&
                            chewingService.cameraController != null)
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: chewingService
                                    .cameraController!.value.previewSize!.height,
                                height: chewingService
                                    .cameraController!.value.previewSize!.width,
                                child: CameraPreview(
                                    chewingService.cameraController!),
                              ),
                            ),
                          )
                        else
                          const ColoredBox(color: Colors.black12),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: OverlayPainter(
                                mouthBox: chewingService.mouthBoxLast,
                                dets: chewingService.visBoxes,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Confidence + cues
            Positioned(
              top: 268,
              right: 16,
              width: 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: (eating ? Colors.green : Colors.red).withOpacity(.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conf: ${(chewingService.confidence * 100).toStringAsFixed(0)}%'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: chewingService.confidence,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 8),
                      Text('Approach: ${(chewingService.approachScore * 100).toStringAsFixed(0)}%'),
                      Text('Teeth: ${(chewingService.teethScore * 100).toStringAsFixed(0)}%'),
                      Text('State: ${chewingService.state.name}'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}