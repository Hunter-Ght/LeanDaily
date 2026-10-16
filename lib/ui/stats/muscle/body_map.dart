import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../theme/tokens.dart';
import '../../kit/pressable.dart';

class BodyShape {
  BodyShape(Map<String, dynamic> data)
    : id = data['id'] as String,
      neutral = data['neutral'] == true,
      full = data['full'] == true,
      path = parseSvgPathData(data['d'] as String);
  final String id;
  final bool neutral, full;
  final Path path;
}

/// Parsed once per asset, never in the paint or hit-test loop.
class BodyGeometry {
  BodyGeometry(Map<String, dynamic> data)
    : front = (data['front'] as List)
          .map((s) => BodyShape(Map<String, dynamic>.from(s as Map)))
          .toList(),
      back = (data['back'] as List)
          .map((s) => BodyShape(Map<String, dynamic>.from(s as Map)))
          .toList(),
      cuts = parseSvgPathData(data['absLines'] as String);
  final List<BodyShape> front, back;
  final Path cuts;
}

class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.geometry,
    required this.back,
    required this.colors,
    required this.palette,
    required this.selected,
    required this.onSelect,
  });
  final BodyGeometry geometry;
  final bool back;
  final Map<String, Color> colors;
  final AppPalette palette;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(constraints.maxWidth * 280.0 / 120.0, 300.0);
      final size = Size(constraints.maxWidth, height);
      final painter = BodyPainter(
        geometry: geometry,
        back: back,
        colors: colors,
        palette: palette,
        selected: selected,
      );
      var point = Offset.zero;
      return Semantics(
        button: true,
        label: back ? '背面肌肉图' : '正面肌肉图',
        child: Listener(
          onPointerDown: (event) => point = event.localPosition,
          child: Pressable(
            onTap: () {
              final id = painter.muscleAt(point, size);
              if (id != null) onSelect(id);
            },
            child: CustomPaint(size: size, painter: painter),
          ),
        ),
      );
    },
  );
}

class BodyPainter extends CustomPainter {
  BodyPainter({
    required this.geometry,
    required this.back,
    required this.colors,
    required this.palette,
    required this.selected,
  });
  final BodyGeometry geometry;
  final bool back;
  final Map<String, Color> colors;
  final AppPalette palette;
  final String selected;
  List<BodyShape> get shapes => back ? geometry.back : geometry.front;
  double _scale(Size size) => math.min(size.width / 120.0, size.height / 280.0);
  Offset _origin(Size size, double scale) => Offset(
    (size.width - 120.0 * scale) / 2,
    (size.height - 280.0 * scale) / 2,
  );
  String? muscleAt(Offset point, Size size) {
    final scale = _scale(size), origin = _origin(size, scale);
    final p = (point - origin) / scale;
    for (final shape in shapes.reversed) {
      if (shape.neutral) continue;
      if (shape.path.contains(p) ||
          (!shape.full && shape.path.contains(Offset(120.0 - p.dx, p.dy)))) {
        return shape.id;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scale(size), origin = _origin(size, scale);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    for (final shape in shapes) {
      void draw() {
        canvas.drawPath(
          shape.path,
          Paint()..color = shape.neutral ? palette.fill2 : colors[shape.id]!,
        );
        canvas.drawPath(
          shape.path,
          Paint()
            ..color = !shape.neutral && selected == shape.id
                ? palette.text
                : palette.card
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = !shape.neutral && selected == shape.id ? 1.6 : 1.2,
        );
      }

      draw();
      if (!shape.full) {
        canvas.save();
        canvas.translate(120.0, 0);
        canvas.scale(-1, 1);
        draw();
        canvas.restore();
      }
    }
    if (!back) {
      canvas.drawPath(
        geometry.cuts,
        Paint()
          ..color = palette.card
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodyPainter old) =>
      old.geometry != geometry ||
      old.back != back ||
      old.colors != colors ||
      old.palette != palette ||
      old.selected != selected;
}
