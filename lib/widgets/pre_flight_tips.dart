import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:snackflix/l10n/app_localizations.dart';

class PreFlightTips extends StatelessWidget {
  const PreFlightTips({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isIOS = Platform.isIOS;

    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Text(
        t.preflightTitle, // e.g. "Pre-Flight Tips"
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick tips
            _Bullet(text: t.preflightTipLighting),     // "Good lighting"
            _Bullet(text: t.preflightTipFaceVisible),  // "Face visible in camera"
            _Bullet(text: t.preflightTipSnackReady),   // "Snack/utensil ready"
            const SizedBox(height: 16),
            Divider(color: cs.outlineVariant.withOpacity(0.4)),
            const SizedBox(height: 12),

            // Lock device guidance (platform-aware)
            Text(
              t.deviceLockTitle, // "Lock Device (Recommended)"
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (isIOS) ...[
              _Bullet(
                text: t.iosGuidedAccessHowTo,
                // "Enable Guided Access: Settings → Accessibility → Guided Access → On. Set a passcode."
              ),
              _Bullet(
                text: t.iosGuidedAccessStart,
                // "Open SnackFlix, triple-click the side button, then tap Start."
              ),
              _Bullet(
                text: t.iosGuidedAccessEnd,
                // "To end, triple-click and enter your passcode."
              ),
            ] else ...[
              _Bullet(
                text: t.androidPinningEnable,
                // "Enable Screen pinning: Settings → Security → App pinning → On."
              ),
              _Bullet(
                text: t.androidPinningStart,
                // "When prompted, tap Pin to lock SnackFlix on screen."
              ),
              _Bullet(
                text: t.androidPinningUnpin,
                // "To unpin, hold Back + Overview (or follow the on-screen hint) and enter your PIN."
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            t.continueCta, // "Continue"
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: tt.bodyMedium)),
        ],
      ),
    );
  }
}
