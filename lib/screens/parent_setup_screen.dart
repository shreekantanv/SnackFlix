import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:snackflix/utils/router.dart';
import 'package:snackflix/l10n/app_localizations.dart';
import '../widgets/primary_cta_button.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _urlController = TextEditingController();
  double _biteInterval = 90;
  bool _smartVerification = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ----- Helpers (solid, theme-agnostic colors to guarantee contrast) -----
  Color get _cardColor =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF262338) // deep eggplant (dark)
          : const Color(0xFFF4F2FB); // soft off-white (light)

  Color get _cardOnColor =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE9E6FF)
          : const Color(0xFF1E1236);

  Color get _chipBg =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF5E46F2)
          : const Color(0xFF5E46F2);

  Color get _chipFg => Colors.white;

  OutlineInputBorder _inputBorder(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));

  // ------------------------------------------------------------------------

  Future<void> _pasteFromClipboard() async {
    final t = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.trim().isNotEmpty == true) {
      _urlController.text = data!.text!.trim();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.pastedFromClipboardSnack)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.clipboardEmptySnack)));
    }
  }

  Future<void> _openYouTubeKids() async {
    final t = AppLocalizations.of(context)!;
    final url = Uri.parse('https://www.youtubekids.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.cantOpenYtKidsSnack)));
    }
  }

  bool _isValidHttpUrl(String v) {
    final s = v.trim();
    if (!s.startsWith('http')) return false;
    final uri = Uri.tryParse(s);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
  }

  void _showHelpSheet() {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.help_outline_rounded),
              const SizedBox(width: 8),
              Text(t.parentSetupHelpTitle, style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 12),
            _HelpStep(1, t.parentSetupHelpStep1),
            _HelpStep(2, t.parentSetupHelpStep2),
            _HelpStep(3, t.parentSetupHelpStep3),
            _HelpStep(4, t.parentSetupHelpStep4),
            const SizedBox(height: 12),
            PrimaryCtaButton(label: t.gotIt, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _startSession() {
    final t = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    if (_urlController.text.isEmpty || !_isValidHttpUrl(_urlController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.invalidUrlSnack)));
      return;
    }
    Navigator.pushNamed(
      context,
      AppRouter.childPlayer,
      arguments: {
        'videoUrl': _urlController.text.trim(),
        'biteInterval': _biteInterval,
        'smartVerification': _smartVerification,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                _SectionCard(
                  color: _cardColor,
                  onColor: _cardOnColor,
                  leading: Icons.link_rounded,
                  title: t.videoSourceHeader,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Theme(
                        // make inputs readable regardless of theme
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF312A47)
                                : Colors.white,
                            border: _inputBorder(Colors.transparent),
                            enabledBorder: _inputBorder(Colors.transparent),
                            focusedBorder: _inputBorder(_chipBg),
                            hintStyle: TextStyle(color: _cardOnColor.withOpacity(0.7)),
                          ),
                        ),
                        child: TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: t.videoSourceHint,
                            prefixIcon: Icon(Icons.public_rounded, color: _cardOnColor.withOpacity(0.9)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.smart_display_outlined),
                            label: Text(t.openYouTubeKids),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _cardOnColor,
                              side: BorderSide(color: _cardOnColor.withOpacity(0.35)),
                            ),
                            onPressed: _openYouTubeKids,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.content_paste_go_rounded),
                            label: Text(t.pasteFromClipboard),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _cardOnColor,
                              side: BorderSide(color: _cardOnColor.withOpacity(0.35)),
                            ),
                            onPressed: _pasteFromClipboard,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  color: _cardColor,
                  onColor: _cardOnColor,
                  leading: Icons.timer_rounded,
                  title: t.biteIntervalHeader,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${_biteInterval.toInt()}s',
                        style: TextStyle(color: _chipFg, fontWeight: FontWeight.w700)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.biteIntervalTip,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _cardOnColor)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          thumbColor: _chipBg,
                          activeTrackColor: _chipBg.withOpacity(0.9),
                          inactiveTrackColor: _cardOnColor.withOpacity(0.25),
                        ),
                        child: Slider(
                          value: _biteInterval,
                          min: 45,
                          max: 180,
                          divisions: (180 - 45) ~/ 5,
                          label: '${_biteInterval.toInt()}s',
                          onChanged: (v) => setState(() => _biteInterval = (v / 5).round() * 5.0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  color: _cardColor,
                  onColor: _cardOnColor,
                  leading: Icons.verified_user_rounded,
                  title: t.smartVerificationHeader,
                  subtitle: t.smartVerificationSubtitle,
                  child: SwitchListTile.adaptive(
                    value: _smartVerification,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.smartVerificationHeader, style: TextStyle(color: _cardOnColor)),
                    subtitle: Text(t.smartVerificationSubtitle,
                        style: TextStyle(color: _cardOnColor.withOpacity(0.85))),
                    onChanged: (v) => setState(() => _smartVerification = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PrimaryCtaButton(
              label: AppLocalizations.of(context)!.startSessionCta,
              onPressed: _startSession,
            ),
          ),
        ],
      ),
    );
  }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.color,
    required this.onColor,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final Color color;
  final Color onColor;
  final IconData leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      color: color, // SOLID color to ensure visibility
      shadowColor: Colors.black.withOpacity(0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(leading, color: onColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: onColor, fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: onColor.withOpacity(0.9))),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep(this.n, this.text);
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 14, child: Text('$n')),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );
  }
}
