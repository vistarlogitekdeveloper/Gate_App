import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'vistar_assets.dart';

/// Signature "S orbit" loader: two counter-rotating rings around a breathing
/// S mark. Use on splash, route changes, and any premium loading state.
class SOrbitLoader extends StatefulWidget {
  final double size;
  final bool showRings;

  const SOrbitLoader({
    super.key,
    this.size = 120,
    this.showRings = true,
  });

  /// Compact variant for inline use (e.g. route overlays).
  const SOrbitLoader.small({super.key})
      : size = 64,
        showRings = false;

  @override
  State<SOrbitLoader> createState() => _SOrbitLoaderState();
}

class _SOrbitLoaderState extends State<SOrbitLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spinOuter;
  late final AnimationController _spinInner;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _spinOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _spinInner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinOuter.dispose();
    _spinInner.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sMarkSize = widget.size * 0.48;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showRings) ...[
            RotationTransition(
              turns: _spinOuter,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  topColor: VistarTokens.pink.withValues(alpha: 0.65),
                  rightColor: VistarTokens.orange.withValues(alpha: 0.4),
                ),
              ),
            ),
            RotationTransition(
              turns: ReverseAnimation(_spinInner),
              child: Padding(
                padding: EdgeInsets.all(widget.size * 0.12),
                child: CustomPaint(
                  size: Size.square(widget.size * 0.76),
                  painter: _RingPainter(
                    bottomColor: VistarTokens.violet.withValues(alpha: 0.65),
                    leftColor: VistarTokens.amber.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
          AnimatedBuilder(
            animation: _breathe,
            builder: (context, child) {
              final t = _breathe.value;
              final scale = 0.92 + (t * 0.12);
              final offsetY = -2.0 + (t * 4.0);
              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: ShaderMask(
              shaderCallback: (rect) =>
                  const LinearGradient(
                colors: [Colors.white, Colors.white],
              ).createShader(rect),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: VistarTokens.pink.withValues(alpha: 0.55),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset(
                  VistarAssets.sMark,
                  width: sMarkSize,
                  height: sMarkSize,
                  fit: BoxFit.contain,
                  cacheWidth: (sMarkSize * 3).ceil(),
                  cacheHeight: (sMarkSize * 3).ceil(),
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.flash_on,
                    size: sMarkSize,
                    color: VistarTokens.pink,
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

class _RingPainter extends CustomPainter {
  final Color? topColor;
  final Color? rightColor;
  final Color? bottomColor;
  final Color? leftColor;

  _RingPainter({
    this.topColor,
    this.rightColor,
    this.bottomColor,
    this.leftColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (topColor != null) {
      paint.color = topColor!;
      canvas.drawArc(rect, math.pi * 1.25, math.pi * 0.5, false, paint);
    }
    if (rightColor != null) {
      paint.color = rightColor!;
      canvas.drawArc(rect, math.pi * 1.85, math.pi * 0.4, false, paint);
    }
    if (bottomColor != null) {
      paint.color = bottomColor!;
      canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.5, false, paint);
    }
    if (leftColor != null) {
      paint.color = leftColor!;
      canvas.drawArc(rect, math.pi * 0.85, math.pi * 0.4, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.topColor != topColor ||
      old.rightColor != rightColor ||
      old.bottomColor != bottomColor ||
      old.leftColor != leftColor;
}

/// Ribbon progress bar — small "loading" indicator beneath the S orbit.
class RibbonProgressBar extends StatefulWidget {
  final double width;
  final double height;

  const RibbonProgressBar({
    super.key,
    this.width = 200,
    this.height = 4,
  });

  @override
  State<RibbonProgressBar> createState() => _RibbonProgressBarState();
}

class _RibbonProgressBarState extends State<RibbonProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            return Stack(
              children: [
                ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.07),
                ),
                Positioned(
                  left: (v * (widget.width * 1.5)) - (widget.width * 0.4),
                  child: Container(
                    width: widget.width * 0.4,
                    height: widget.height,
                    decoration: const BoxDecoration(
                      gradient: VistarTokens.ribbon,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
