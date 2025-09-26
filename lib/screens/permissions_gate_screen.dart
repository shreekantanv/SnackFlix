import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:snackflix/utils/router.dart';
import 'package:snackflix/l10n/app_localizations.dart';

import '../widgets/primary_cta_button.dart';

class PermissionsGateScreen extends StatefulWidget {
  const PermissionsGateScreen({
    super.key,
    this.autoAdvanceIfGranted = true, // set true in onboarding if you want to skip
  });

  final bool autoAdvanceIfGranted;

  @override
  State<PermissionsGateScreen> createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen> {
  bool _requesting = false;
  bool _alreadyGranted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermission();
  }

  Future<void> _checkExistingPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    _alreadyGranted = status.isGranted;

    if (widget.autoAdvanceIfGranted && _alreadyGranted) {
      Navigator.pushReplacementNamed(context, AppRouter.main);
      return;
    }
    setState(() {});
  }

  Future<void> _requestCameraPermission() async {
    setState(() => _requesting = true);
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _alreadyGranted = status.isGranted;
    });

    final t = AppLocalizations.of(context)!;

    if (status.isGranted) {
      HapticFeedback.lightImpact();
      Navigator.pushReplacementNamed(context, AppRouter.main);
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog(t);
    } else {
      _showSnack(t.perm_deniedSnack);
    }
  }

  void _openSettings() => openAppSettings();

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSettingsDialog(AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.perm_settingsTitle),
        content: Text(t.perm_settingsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.perm_settingsCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openSettings();
            },
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            child: Text(t.perm_settingsOpen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t.perm_cameraTitle),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Soft gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surfaceVariant.withOpacity(0.10),
                    cs.primary.withOpacity(0.10),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            top: -40,
            child: _Blob(color: cs.primary.withOpacity(0.25), size: 220),
          ),
          Positioned(
            right: -60,
            bottom: -40,
            child: _Blob(color: cs.tertiary.withOpacity(0.18), size: 200),
          ),

          // Content card
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            final brighten = _brighten(cs.primary, .22);
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [brighten, cs.secondary],
                            ).createShader(bounds);
                          },
                          child: const Icon(
                            Icons.photo_camera_front_rounded,
                            size: 96,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.perm_allowCameraTitle,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.perm_explain,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(0.85),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _Bullet(text: t.perm_pointTemporary, color: cs.primary),
                        const SizedBox(height: 6),
                        _Bullet(text: t.perm_pointNoPreview, color: cs.primary),
                        const SizedBox(height: 22),

                        // Buttons (state-aware)
                        if (_alreadyGranted) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_rounded,
                                  size: 18, color: cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                // You can add a dedicated i18n string if you like
                                'Camera permission already granted',
                                style: textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PrimaryCtaButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                                context, AppRouter.main),
                            label: t.common_continue,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openSettings,
                            child: Text(t.perm_secondaryButton),
                          ),
                        ] else ...[
                          PrimaryCtaButton(
                            onPressed:
                            _requesting ? null : _requestCameraPermission,
                            label: t.perm_primaryButton,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openSettings,
                            child: Text(t.perm_secondaryButton),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small helper to brighten a color in dark themes.
  Color _brighten(Color c, [double amount = .14]) {
    final hsl = HSLColor.fromColor(c);
    final light = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(light).toColor();
  }
}



class _Bullet extends StatelessWidget {
  final String text;
  final Color color;
  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.check_circle_rounded, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: t.bodyMedium?.copyWith(height: 1.3)),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
        ),
      ),
    );
  }
}