import 'package:flutter/material.dart';

import '../theme.dart';
import 'vistar_assets.dart';

/// Ambient page background — aurora glows + faint "S" watermark.
/// Adapts automatically to light and dark themes.
class VistarBackground extends StatelessWidget {
  final Widget child;
  final bool showWatermark;

  const VistarBackground({
    super.key,
    required this.child,
    this.showWatermark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? VistarTokens.darkBg : VistarTokens.lightBg;

    // The decorative layers (radial gradients + 640×640 watermark) are
    // expensive to recompose and don't change with content — keep them
    // in their own RepaintBoundary so they raster once and get reused
    // while the foreground updates.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _BackgroundLayers(
              isDark: isDark,
              bg: bg,
              showWatermark: showWatermark,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackgroundLayers extends StatelessWidget {
  const _BackgroundLayers({
    required this.isDark,
    required this.bg,
    required this.showWatermark,
  });

  final bool isDark;
  final Color bg;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: bg),
          // Aurora glow — top left (purple)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -1.1),
                  radius: 1.0,
                  colors: [
                    VistarTokens.purple
                        .withValues(alpha: isDark ? 0.22 : 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.60],
                ),
              ),
            ),
          ),
          // Aurora glow — top right (pink)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, -1.0),
                  radius: 1.0,
                  colors: [
                    VistarTokens.pink
                        .withValues(alpha: isDark ? 0.16 : 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          // Aurora glow — bottom right (orange)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.8, 1.2),
                  radius: 1.1,
                  colors: [
                    VistarTokens.orange
                        .withValues(alpha: isDark ? 0.12 : 0.07),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          if (showWatermark)
            Positioned(
              right: -120,
              top: 0,
              bottom: 0,
              width: 640,
              child: Center(
                child: Opacity(
                  opacity: isDark ? 0.05 : 0.035,
                  child: Transform.rotate(
                    angle: 0.07,
                    child: Image.asset(
                      VistarAssets.sMark,
                      width: 640,
                      height: 640,
                      fit: BoxFit.contain,
                      // Painted at 3.5% opacity as a background watermark —
                      // no need to decode the full 4k PNG behind every screen.
                      cacheWidth: 720,
                      cacheHeight: 720,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
