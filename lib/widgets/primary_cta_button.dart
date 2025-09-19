import 'package:flutter/material.dart';

/// Premium primary CTA for SnackFlix.
class PrimaryCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool expand;

  /// NEW: explicit height so parents (like bottomNavigationBar) don't stretch it.
  final double height; // default 56

  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16), // keep horiz padding only
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.expand = true,
    this.height = 56, // <- important
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
              ),
            ),
          )
        else if (leading != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconTheme(
              data: IconThemeData(color: cs.onPrimary, size: 20),
              child: leading!,
            ),
          ),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );

    final gradientColors = enabled
        ? [cs.primary, cs.primary.withOpacity(0.75)]
        : [cs.primary.withOpacity(0.50), cs.primary.withOpacity(0.35)];

    final shadowColor = enabled ? cs.primary.withOpacity(0.35) : Colors.transparent;

    final buttonCore = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: enabled ? onPressed : null,
          child: Padding(
            // vertical height will come from SizedBox/ConstrainedBox below
            padding: padding,
            child: Center(child: content),
          ),
        ),
      ),
    );

    // Guarantee size + clip gradient to rounded corners
    final sized = SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: buttonCore,
      ),
    );

    return sized;
  }
}
