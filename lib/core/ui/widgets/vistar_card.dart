import 'package:flutter/material.dart';

import '../theme.dart';
import 'vistar_assets.dart';

/// Premium surface card with optional bottom-right S-mark corner accent
/// and ribbon-glow hover. Honors light + dark themes.
class VistarCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool cornerAccent;
  final bool glowOnHover;
  final VoidCallback? onTap;
  final double radius;

  const VistarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.cornerAccent = false,
    this.glowOnHover = false,
    this.onTap,
    this.radius = VistarTokens.radius,
  });

  @override
  State<VistarCard> createState() => _VistarCardState();
}

class _VistarCardState extends State<VistarCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final surface2 = isDark
        ? VistarTokens.darkSurface2
        : VistarTokens.lightSurface2;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(
        0,
        widget.glowOnHover && _hover ? -2 : 0,
        0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surface2.withValues(alpha: isDark ? 0.7 : 1.0),
            surface.withValues(alpha: isDark ? 0.7 : 1.0),
          ],
        ),
        border: Border.all(
          color: widget.glowOnHover && _hover
              ? VistarTokens.pink.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: widget.glowOnHover && _hover
            ? VistarTokens.glow(isDark)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          children: [
            if (widget.cornerAccent)
              Positioned(
                right: -26,
                bottom: -30,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.05,
                    child: Image.asset(
                      VistarAssets.sMark,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      cacheWidth: 360,
                      cacheHeight: 360,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Padding(padding: widget.padding, child: widget.child),
          ],
        ),
      ),
    );

    if (widget.onTap == null && !widget.glowOnHover) return card;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}
