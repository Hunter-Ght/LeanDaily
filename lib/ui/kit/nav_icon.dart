import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

/// 底部标签栏的四个图标：同一个 24 格子、同样 20×20 的视觉范围、同样线宽，
/// 每个都有线条和实心两种；选中程度 [t]（0~1）在两者之间淡入淡出。
/// iOS 原生标签栏也用 [paintNavIcon] 出图，两端图标完全一致。
class NavIcon extends StatelessWidget {
  const NavIcon(
    this.name, {
    super.key,
    required this.from,
    required this.to,
    required this.t,
    this.size = 24,
  });
  final String name;
  final Color from, to;
  final double t, size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _NavIconPainter(name, from, to, t)),
  );
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter(this.name, this.from, this.to, this.t);
  final String name;
  final Color from, to;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final color = Color.lerp(from, to, t)!;
    if (t <= 0.001) {
      paintNavIcon(canvas, size.width, name, color, solid: false);
    } else if (t >= 0.999) {
      paintNavIcon(canvas, size.width, name, color, solid: true);
    } else {
      // 两层各带透明度叠起来：不用 saveLayer。
      paintNavIcon(
        canvas,
        size.width,
        name,
        color.withValues(alpha: color.a * (1 - t)),
        solid: false,
      );
      paintNavIcon(
        canvas,
        size.width,
        name,
        color.withValues(alpha: color.a * t),
        solid: true,
      );
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.name != name || old.from != from || old.to != to || old.t != t;
}

const double _stroke = 1.75;
final Path _flame =
    parseSvgPathData(
      'M12 3c1 3 4 4 4 8a4 4 0 1 1-8 0c0-1.5.6-2.6 1.4-3.6.2 1.6 1.6 2 2.1.6.2-1.2 0-2.6.5-5',
    ).transform(
      (Matrix4.identity()
            ..translateByDouble(12, 12, 0, 1)
            ..scaleByDouble(1.5, 1.5, 1, 1)
            ..translateByDouble(-12, -9.2, 0, 1))
          .storage,
    );

RRect _r(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

void paintNavIcon(
  Canvas canvas,
  double size,
  String name,
  Color color, {
  required bool solid,
}) {
  canvas.save();
  canvas.scale(size / 24);
  final fill = Paint()..color = color;
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  switch (name) {
    case 'flame':
      if (solid) {
        canvas.drawPath(_flame, fill);
        canvas.drawPath(_flame, line..strokeWidth = 1.2);
      } else {
        canvas.drawPath(_flame, line);
      }
    case 'train':
      if (solid) {
        canvas.drawRRect(_r(2.6, 7.4, 2.6, 9.2, .8), fill);
        canvas.drawRRect(_r(5.6, 9, 1.9, 6, .5), fill);
        canvas.drawRRect(_r(7.5, 10.9, 9, 2.2, .5), fill);
        canvas.drawRRect(_r(16.5, 9, 1.9, 6, .5), fill);
        canvas.drawRRect(_r(18.8, 7.4, 2.6, 9.2, .8), fill);
      } else {
        for (final d in [
          'M3.9 8.6v6.8',
          'M6.9 6.6v10.8',
          'M17.1 6.6v10.8',
          'M20.1 8.6v6.8',
          'M6.9 12h10.2',
        ]) {
          canvas.drawPath(parseSvgPathData(d), line);
        }
      }
    case 'rings':
      line.strokeWidth = solid ? 2.4 : _stroke;
      canvas.drawCircle(const Offset(12, 12), 8.4, line);
      canvas.drawCircle(const Offset(12, 12), 4.9, line);
      canvas.drawCircle(const Offset(12, 12), solid ? 2.2 : 1.7, fill);
    default: // me
      canvas.drawCircle(const Offset(12, 7.6), 3.7, solid ? fill : line);
      final body = Path()
        ..moveTo(4.2, 20.6)
        ..lineTo(4.2, 19)
        ..cubicTo(4.2, 12.4, 19.8, 12.4, 19.8, 19)
        ..lineTo(19.8, 20.6);
      if (solid) body.close();
      canvas.drawPath(body, solid ? fill : line);
  }
  canvas.restore();
}
