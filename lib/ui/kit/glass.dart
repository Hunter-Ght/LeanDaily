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
    final live = RenderEffects.liveBlur;
    final face = Color.alphaBlend(p.glass, p.bg);
    return CustomPaint(
      // 阴影只画在外面：面是半透明时，垫在下面会把玻璃弄脏。
      painter: shadow ? _OutsideShadow(radius, p.shadow) : null,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: shape),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            enabled: live,
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: CustomPaint(
              foregroundPainter: _GlassEdge(radius, p),
              child: live
                  ? ColoredBox(color: p.glass, child: child)
                  : DecoratedBox(
                      // 没有模糊时用不透明的面：上沿略亮一点，有一点“玻璃”的层次，只是一次渐变填充。
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.alphaBlend(
                              p.glassHi.withValues(
                                alpha: p.bg.computeLuminance() < .5
                                    ? 0.06
                                    : 0.3,
                              ),
                              face,
                            ),
                            face,
                          ],
                        ),
                      ),
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutsideShadow extends CustomPainter {
  _OutsideShadow(this.radius, this.color);
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(
          Rect.fromLTWH(-80, -80, size.width + 160, size.height + 200),
        ),
        Path()..addRRect(rr),
      ),
    );
    canvas.drawRRect(
      rr.shift(const Offset(0, 8)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadow old) =>
      old.radius != radius || old.color != color;
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
