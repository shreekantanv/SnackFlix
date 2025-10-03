// lib/screens/child_player_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart' show CameraController;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:snackflix/l10n/app_localizations.dart';
import 'package:snackflix/services/chewing_detection_service.dart';
import 'package:snackflix/services/settings_service.dart';
import 'package:snackflix/services/session_tracker.dart';
import 'package:snackflix/utils/router.dart';

enum PlayerOverlay {
  none,
  nudge,
  coachBreak,
  legacyLock,
  pausedNotice,
  finished,
  approaching,
}

class ChildPlayerScreen extends StatelessWidget {
  final String? videoUrl;
  final double biteInterval;

  const ChildPlayerScreen({
    super.key,
    this.videoUrl,
    required this.biteInterval,
  });

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

  const _ChildPlayerScreenContent({
    required this.videoUrl,
    required this.biteInterval,
  });

  @override
  State<_ChildPlayerScreenContent> createState() =>
      _ChildPlayerScreenContentState();
}

class _ChildPlayerScreenContentState extends State<_ChildPlayerScreenContent>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late YoutubePlayerController _you;
  late final ChewingDetectionService _chew;
  late final SettingsService _settings;

  Timer? _legacyDwell;
  Timer? _nudgeTimer;
  Timer? _coachCountdown;
  Timer? _uiTick;
  Timer? _approachingTimer;

  int _coachRemaining = 0;
  int _legacyCountdown = 0;

  PlayerOverlay _overlay = PlayerOverlay.none;
  bool _kidSaidFull = false;
  bool _kidSnoozed = false;
  DateTime? _snoozeUntil;

  bool _needsUiTick = false;
  bool _showingPin = false;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _settings = context.read<SettingsService>();
    _chew = context.read<ChewingDetectionService>();
    _chew.addListener(_onChewChanged);

    final id = YoutubePlayerController.convertUrlToId(widget.videoUrl ?? '');
    if (id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.invalidYoutubeUrl)));
        Navigator.pop(context);
      });
      return;
    }

    _you = YoutubePlayerController.fromVideoId(
      videoId: id,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );

    _uiTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_needsUiTick && mounted) {
        setState(() => _needsUiTick = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chew.initialize();
      if (mounted) {
        context.read<SessionTracker>().start(url: widget.videoUrl);
        _scheduleByMode(initial: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _floatController.dispose();
    _uiTick?.cancel();
    _cancelAllTimers();
    _you.close();
    _chew.removeListener(_onChewChanged);
    _chew.dispose();
    super.dispose();
  }

  void _scheduleByMode({bool initial = false}) {
    _cancelAllTimers();

    final mode = _settings.mode;
    final mindfulEvery =
        (_settings.mindfulBreakInterval ?? _settings.biteInterval)
            .clamp(60.0, 180.0)
            .toInt();
    final legacyDwell = widget.biteInterval.clamp(45.0, 180.0).toInt();

    switch (mode) {
      case InterventionMode.observe:
        _overlay = PlayerOverlay.none;
        if (initial) _you.playVideo();
        break;

      case InterventionMode.nudges:
        _overlay = PlayerOverlay.none;
        if (initial) _you.playVideo();
        _nudgeTimer = Timer.periodic(
          Duration(seconds: mindfulEvery),
          (_) => _maybeNudge(),
        );
        break;

      case InterventionMode.coach:
        _overlay = PlayerOverlay.none;
        if (initial) _you.playVideo();
        _nudgeTimer = Timer.periodic(
          Duration(seconds: mindfulEvery),
          (_) => _startCoachBreak(),
        );
        break;

      case InterventionMode.lock:
        _overlay = PlayerOverlay.none;
        _legacyCountdown = legacyDwell;
        if (initial) _you.playVideo();
        _legacyDwell = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _legacyTick(legacyDwell),
        );
        break;
    }
    _markUi();
  }

  void _cancelAllTimers() {
    _legacyDwell?.cancel();
    _nudgeTimer?.cancel();
    _coachCountdown?.cancel();
    _approachingTimer?.cancel();
    _legacyDwell = null;
    _nudgeTimer = null;
    _coachCountdown = null;
    _approachingTimer = null;
  }

  void _onChewChanged() {
    if (_chew.state == EatState.approach && _overlay == PlayerOverlay.none) {
      if (_settings.mode != InterventionMode.observe) {
        _overlay = PlayerOverlay.approaching;
        _slideController.forward();
        _scaleController.forward();
        _approachingTimer?.cancel();
        _approachingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _overlay == PlayerOverlay.approaching) {
            _scaleController.reverse();
            _slideController.reverse().then((_) {
              if (mounted) {
                setState(() => _overlay = PlayerOverlay.none);
              }
            });
          }
        });
        _markUi();
      }
    }

    if (_settings.mode == InterventionMode.lock) {
      final eating =
          _chew.state == EatState.chewing || _chew.state == EatState.grace;
      if (eating && _overlay == PlayerOverlay.legacyLock) {
        _overlay = PlayerOverlay.none;
        _legacyCountdown = widget.biteInterval.toInt();
        _you.playVideo();
        context.read<SessionTracker>().onVideoPlay();
      }
    }
    _markUi();
  }

  bool get _eatingNow =>
      _chew.state == EatState.chewing || _chew.state == EatState.grace;

  bool get _respectDetection => _settings.smartVerification;

  bool get _inSnooze =>
      _snoozeUntil != null && DateTime.now().isBefore(_snoozeUntil!);

  void _maybeNudge() {
    if (!mounted || _kidSaidFull || _inSnooze) return;
    if (_respectDetection && _eatingNow) return;

    _overlay = PlayerOverlay.nudge;
    _slideController.forward();
    _scaleController.forward();
    _markUi();
  }

  void _startCoachBreak() {
    if (!mounted || _kidSaidFull || _inSnooze) return;
    if (_respectDetection && _eatingNow) return;

    final rest = _settings.shortRestSeconds;
    _coachRemaining = rest;
    _overlay = PlayerOverlay.coachBreak;
    _slideController.forward();
    _scaleController.forward();

    _you.pauseVideo();
    context.read<SessionTracker>().onVideoPause();

    _coachCountdown?.cancel();
    _coachCountdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _coachRemaining--;
        if (_coachRemaining <= 0) {
          t.cancel();
        }
      });
    });

    _markUi();
  }

  void _legacyTick(int dwellSeconds) {
    final eating = _eatingNow;

    if (eating) {
      _legacyCountdown = dwellSeconds;
      if (_overlay == PlayerOverlay.legacyLock) {
        _overlay = PlayerOverlay.none;
        _you.playVideo();
        context.read<SessionTracker>().onVideoPlay();
        _markUi();
      }
      return;
    }

    _legacyCountdown--;

    if (_legacyCountdown == 10 && _overlay == PlayerOverlay.none) {
      _markUi();
    }

    if (_legacyCountdown <= 0 && _overlay != PlayerOverlay.legacyLock) {
      _overlay = PlayerOverlay.legacyLock;
      _slideController.forward();
      _scaleController.forward();
      _you.pauseVideo();
      context.read<SessionTracker>().onVideoPause();
      _markUi();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      _you.pauseVideo();
      context.read<SessionTracker>().onVideoPause();
      _chew.pause();
      _overlay = PlayerOverlay.pausedNotice;
      _slideController.forward();
      _scaleController.forward();
      _markUi();
    } else if (state == AppLifecycleState.resumed) {
      _chew.resume();
      _markUi();
    }
  }

  void _dismissOverlay() {
    _scaleController.reverse();
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() => _overlay = PlayerOverlay.none);
      }
    });
  }

  void _kidTapResume() {
    _scaleController.reverse();
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() => _overlay = PlayerOverlay.none);
        _you.playVideo();
        context.read<SessionTracker>().onVideoPlay();
      }
    });
  }

  void _kidTapSnooze([int minutes = 5]) {
    final until = DateTime.now().add(Duration(minutes: minutes));
    _snoozeUntil = until;
    _kidSnoozed = true;
    _kidTapResume();
  }

  void _kidTapSkip() {
    _dismissOverlay();
  }

  void _kidTapFull() {
    _kidSaidFull = true;
    _overlay = PlayerOverlay.finished;
    _slideController.forward();
    _scaleController.forward();
    _you.pauseVideo();
    context.read<SessionTracker>().onVideoPause();
    _markUi();
  }

  Future<void> _parentOverride() async {
    if (_showingPin) return;
    _showingPin = true;
    final t = AppLocalizations.of(context)!;
    final ok = await _showPinDialog(context, title: t.enterPinTitle);
    _showingPin = false;
    if (ok == true) {
      _scaleController.reverse();
      _slideController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _overlay = PlayerOverlay.none;
            _kidSaidFull = false;
            _snoozeUntil = null;
            _legacyCountdown = widget.biteInterval.toInt();
          });
          _you.playVideo();
          context.read<SessionTracker>().onManualOverride();
          context.read<SessionTracker>().onVideoPlay();
        }
      });
    }
  }

  void _markUi() => _needsUiTick = true;

  @override
  Widget build(BuildContext context) {
    final mode = _settings.mode;
    final isLegacy = mode == InterventionMode.lock;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _you),
              ),
            ),

            // Gradient overlays for better contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Enhanced top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _ModeBadge(mode: mode),
                    const Spacer(),
                    _EnhancedStatusPill(
                      eating: _eatingNow,
                      floatController: _floatController,
                    ),
                    const SizedBox(width: 12),
                    _GlassButton(
                      icon: Icons.close_rounded,
                      onTap: () => _endSession(context),
                      tooltip: 'End Session',
                    ),
                  ],
                ),
              ),
            ),

            // Legacy countdown indicator (enhanced design)
            if (isLegacy &&
                _legacyCountdown <= 10 &&
                _legacyCountdown > 0 &&
                _overlay == PlayerOverlay.none)
              Positioned(
                bottom: 100,
                right: 24,
                child: _AnimatedCountdownPill(
                  seconds: _legacyCountdown,
                  pulseController: _pulseController,
                ),
              ),

            // Main overlay layer
            _buildOverlayLayer(context, mode),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayLayer(BuildContext context, InterventionMode mode) {
    if (_overlay == PlayerOverlay.none) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_slideController, _scaleController]),
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _slideController,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: _scaleController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: child,
          ),
        );
      },
      child: _buildOverlayContent(context, mode),
    );
  }

  Widget _buildOverlayContent(BuildContext context, InterventionMode mode) {
    switch (_overlay) {
      case PlayerOverlay.approaching:
        return _FloatingNotification(
          icon: Icons.restaurant_rounded,
          message: 'Getting ready to eat! 🍽️',
          gradient: const LinearGradient(
            colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          ),
        );

      case PlayerOverlay.nudge:
        return _EnhancedFrostedCard(
          icon: Icons.spa_rounded,
          iconGradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          title: 'Mindful Moment',
          subtitle: 'Time for a sip of water or a mindful bite! 💧',
          emoji: '🧘',
          primaryText: 'Got it!',
          onPrimary: _kidTapSkip,
          secondaryText: 'Remind me later',
          onSecondary: () => _kidTapSnooze(5),
          tertiaryText: "I'm full",
          onTertiary: _kidTapFull,
        );

      case PlayerOverlay.coachBreak:
        return _EnhancedFrostedCard(
          icon: Icons.self_improvement_rounded,
          iconGradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          ),
          title: 'Breathe & Rest',
          subtitle: _coachRemaining > 0
              ? 'Take a deep breath... ${_coachRemaining}s'
              : 'Feeling refreshed? Ready to continue!',
          emoji: '🌟',
          primaryText: _coachRemaining > 0 ? null : 'Continue',
          onPrimary: _coachRemaining > 0 ? null : _kidTapResume,
          secondaryText: 'Remind me later',
          onSecondary: () => _kidTapSnooze(5),
          tertiaryText: "I'm full",
          onTertiary: _kidTapFull,
          showProgress: _coachRemaining > 0,
          progressValue: 1 - (_coachRemaining / _settings.shortRestSeconds),
          progressGradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          ),
        );

      case PlayerOverlay.legacyLock:
        return _EnhancedFrostedCard(
          icon: Icons.fastfood_rounded,
          iconGradient: const LinearGradient(
            colors: [Color(0xFFFF9A56), Color(0xFFFF6A88)],
          ),
          title: 'Time to Chew!',
          subtitle: 'Take your time and enjoy your food 😊',
          emoji: '🍽️',
          primaryText: 'Parent Help',
          onPrimary: _parentOverride,
          secondaryText: "I'm eating",
          onSecondary: _dismissOverlay,
        );

      case PlayerOverlay.pausedNotice:
        return _EnhancedFrostedCard(
          icon: Icons.play_circle_rounded,
          iconGradient: const LinearGradient(
            colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
          ),
          title: 'Paused',
          subtitle: 'Ready when you are!',
          emoji: '⏸️',
          primaryText: 'Resume',
          onPrimary: _kidTapResume,
        );

      case PlayerOverlay.finished:
        return _EnhancedFrostedCard(
          icon: Icons.celebration_rounded,
          iconGradient: const LinearGradient(
            colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
          ),
          title: 'Amazing Job!',
          subtitle: 'You practiced mindful eating today! 🌟',
          emoji: '🎉',
          primaryText: 'Finish Session',
          onPrimary: () => _endSession(context),
        );

      case PlayerOverlay.none:
        return const SizedBox.shrink();
    }
  }

  Future<bool?> _showPinDialog(
    BuildContext context, {
    required String title,
  }) async {
    final t = AppLocalizations.of(context)!;
    final pinController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: TextField(
          controller: pinController,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(
            hintText: t.pinHint,
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text == _settings.pin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.incorrectPin),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Text(t.submit),
          ),
        ],
      ),
    );
    return ok;
  }

  Future<void> _endSession(BuildContext context) async {
    _cancelAllTimers();
    _you.pauseVideo();
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
}

// Modern glass-morphism button
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced mode badge
class _ModeBadge extends StatelessWidget {
  final InterventionMode mode;

  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final config = _getModeConfig(mode);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: config['gradient'] as LinearGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (config['color'] as Color).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(config['icon'] as IconData, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                config['label'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getModeConfig(InterventionMode mode) {
    switch (mode) {
      case InterventionMode.observe:
        return {
          'label': 'Watching',
          'icon': Icons.visibility_rounded,
          'color': const Color(0xFF4FACFE),
          'gradient': const LinearGradient(
            colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
          ),
        };
      case InterventionMode.nudges:
        return {
          'label': 'Mindful',
          'icon': Icons.bubble_chart_rounded,
          'color': const Color(0xFF667EEA),
          'gradient': const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        };
      case InterventionMode.coach:
        return {
          'label': 'Guided',
          'icon': Icons.spa_rounded,
          'color': const Color(0xFFFF6B6B),
          'gradient': const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          ),
        };
      case InterventionMode.lock:
        return {
          'label': 'Active',
          'icon': Icons.fastfood_rounded,
          'color': const Color(0xFFFF9A56),
          'gradient': const LinearGradient(
            colors: [Color(0xFFFF9A56), Color(0xFFFF6A88)],
          ),
        };
    }
  }
}

// Enhanced status pill with floating animation
class _EnhancedStatusPill extends StatelessWidget {
  final bool eating;
  final AnimationController floatController;

  const _EnhancedStatusPill({
    required this.eating,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 2 * (floatController.value - 0.5)),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: eating
                  ? const LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFF9A56), Color(0xFFFF6A88)],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: eating
                      ? const Color(0xFF11998E).withOpacity(0.4)
                      : const Color(0xFFFF9A56).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  eating ? 'Eating' : 'Watching',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated countdown pill
class _AnimatedCountdownPill extends StatelessWidget {
  final int seconds;
  final AnimationController pulseController;

  const _AnimatedCountdownPill({
    required this.seconds,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final urgency = seconds <= 5 ? 1.0 : (10 - seconds) / 5;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 1.0 + (0.1 * pulseController.value * urgency);
        return Transform.scale(scale: scale, child: child);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: seconds <= 5
                    ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                    : [const Color(0xFFFF9A56), const Color(0xFFFF6A88)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (seconds <= 5
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFFFF9A56))
                          .withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  '${seconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Floating notification banner
class _FloatingNotification extends StatelessWidget {
  final IconData icon;
  final String message;
  final LinearGradient gradient;

  const _FloatingNotification({
    required this.icon,
    required this.message,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced frosted card with modern design
class _EnhancedFrostedCard extends StatelessWidget {
  final IconData icon;
  final LinearGradient iconGradient;
  final String title;
  final String? subtitle;
  final String? emoji;
  final String? primaryText;
  final VoidCallback? onPrimary;
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final String? tertiaryText;
  final VoidCallback? onTertiary;
  final bool showProgress;
  final double progressValue;
  final LinearGradient? progressGradient;

  const _EnhancedFrostedCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.subtitle,
    this.emoji,
    this.primaryText,
    this.onPrimary,
    this.secondaryText,
    this.onSecondary,
    this.tertiaryText,
    this.onTertiary,
    this.showProgress = false,
    this.progressValue = 0,
    this.progressGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with gradient background
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: iconGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iconGradient.colors.first.withOpacity(
                                  0.5,
                                ),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 24),

                        // Title with emoji
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (emoji != null) ...[
                              Text(
                                emoji!,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (subtitle != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 17,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],

                        if (showProgress) ...[
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progressValue.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: progressGradient ?? iconGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (progressGradient?.colors.first ??
                                                    iconGradient.colors.first)
                                                .withOpacity(0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Action buttons
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (primaryText != null)
                              _GradientButton(
                                text: primaryText!,
                                gradient: iconGradient,
                                onTap: onPrimary,
                              ),
                            if (secondaryText != null)
                              _OutlineButton(
                                text: secondaryText!,
                                onTap: onSecondary,
                              ),
                            if (tertiaryText != null)
                              _TextOnlyButton(
                                text: tertiaryText!,
                                onTap: onTertiary,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Gradient button
class _GradientButton extends StatelessWidget {
  final String text;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.text,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Outline button
class _OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _OutlineButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Text-only button
class _TextOnlyButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _TextOnlyButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
