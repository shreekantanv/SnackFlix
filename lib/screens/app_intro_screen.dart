import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:snackflix/utils/router.dart';
import '../l10n/app_localizations.dart';
import '../widgets/primary_cta_button.dart';

class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen> {
  late final PageController _pageCtrl;
  int _page = 0;

  final _items = const [
    _FeatureItem(
      image: 'assets/intro/paste_url.png',
      titleKey: 'featurePasteTitle',
      descKey: 'featurePasteDesc',
    ),
    _FeatureItem(
      image: 'assets/intro/set_interval.png',
      titleKey: 'featureIntervalTitle',
      descKey: 'featureIntervalDesc',
    ),
    _FeatureItem(
      image: 'assets/intro/privacy_card.png',
      titleKey: 'featurePrivacyTitle',
      descKey: 'featurePrivacyDesc',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.90);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                cs.surface.withOpacity(0.0),
                cs.surface.withOpacity(0.05),
                cs.surfaceContainerHighest.withOpacity(0.12),
              ]
                  : [
                cs.surface.withOpacity(0.0),
                cs.surfaceVariant.withOpacity(0.35),
                cs.surfaceContainerHighest.withOpacity(0.40),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              children: [
                // Top bar
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Text(
                        t.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    _FrostIconButton(
                      tooltip: t.privacyTitle,
                      icon: Icons.help_outline_rounded,
                      onTap: () => _showPrivacy(context, t),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Hero with glow
                _HeroBadge(),

                const SizedBox(height: 18),

                // Headline + subhead
                Text(
                  t.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    t.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      height: 1.35,
                      color: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.color
                          ?.withOpacity(0.85),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Feature cards with subtle motion
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _items.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageCtrl,
                        builder: (context, child) {
                          double delta = 0;
                          if (_pageCtrl.position.haveDimensions) {
                            delta = (_pageCtrl.page ?? _page.toDouble()) - index;
                          }
                          final scale = (1 - (delta.abs() * 0.08)).clamp(0.9, 1.0);
                          final translateY = 12 * delta.abs();

                          return Transform.translate(
                            offset: Offset(0, translateY),
                            child: Transform.scale(
                              scale: scale,
                              child: _GlassFeatureCard(item: _items[index]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_items.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                      height: 8,
                      width: active ? 20 : 8,
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primary
                            : cs.primary.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
                ),

                // CTA
                PrimaryCtaButton(
                  label: t.getStarted,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.permissionsGate),
                ),

                // Secondary: only privacy link
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => _showPrivacy(context, t),
                    child: Text(t.readPrivacy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacy(BuildContext context, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.privacyTitle),
        content: SingleChildScrollView(child: Text(t.privacyBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }
}

/// ————— Premium widgets —————

class _FrostIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  const _FrostIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: cs.surface.withOpacity(0.35),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: cs.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.35),
                blurRadius: 60,
                spreadRadius: 6,
              ),
            ],
          ),
        ),
        Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [cs.primary.withOpacity(0.20), cs.surface],
            ),
            border: Border.all(
              color: cs.primary.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Image.asset(
            'assets/intro/hero.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _GlassFeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _GlassFeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    String tr(String k) {
      switch (k) {
        case 'featurePasteTitle':
          return t.featurePasteTitle;
        case 'featurePasteDesc':
          return t.featurePasteDesc;
        case 'featureIntervalTitle':
          return t.featureIntervalTitle;
        case 'featureIntervalDesc':
          return t.featureIntervalDesc;
        case 'featurePrivacyTitle':
          return t.featurePrivacyTitle;
        case 'featurePrivacyDesc':
          return t.featurePrivacyDesc;
        default:
          return k;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: cs.surface.withOpacity(0.55),
            border: Border.all(color: cs.primary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // —— Centered square icon tile (prevents stretching/bands)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size =
                        math.min(constraints.maxWidth, constraints.maxHeight) *
                            0.78;
                    return Center(
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: cs.surfaceVariant.withOpacity(0.25),
                          border:
                          Border.all(color: cs.primary.withOpacity(0.10)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          item.image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(item.titleKey),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(item.descKey),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String image;
  final String titleKey;
  final String descKey;
  const _FeatureItem({
    required this.image,
    required this.titleKey,
    required this.descKey,
  });
}
