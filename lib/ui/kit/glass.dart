import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import 'render_effects.dart';

/// 毛玻璃表面：模糊 + 玻璃色 + 顶部高光描边（对应 Web 的 .dock / .nav-add span）。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 30,
    this.shadow = true,
    this.blur = 28,
  });

  final Widget child;
  final double radius;
  final bool shadow;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: p.shadow,
                  offset: const Offset(0, 8),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          enabled: RenderEffects.liveBlur,
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: _GlassEdge(radius, p),
            child: ColoredBox(
              color: RenderEffects.liveBlur
                  ? p.glass
                  : Color.alphaBlend(p.glass, p.bg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassEdge extends CustomPainter {
  _GlassEdge(this.radius, this.p);
  final double radius;
  final AppPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect.deflate(0.25),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = p.glassEdge,
    );
    final hi = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      hi,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [p.glassHi, p.glassHi.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassEdge old) => old.radius != radius || old.p != p;
}
