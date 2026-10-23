import 'package:leandaily/l10n/app_messages.dart';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../app/app_controller.dart';
import '../../../domain/movements.dart' show MUSCLES;
import '../../../theme/tokens.dart';
import '../../kit/pressable.dart';

class BodyShape {
  BodyShape(this.id, String d, {this.neutral = false})
    : path = parseSvgPathData(d);
  final String id;
  final bool neutral;
  final Path path;
}

/// 一个视图（正面或背面）：坐标框 + 按绘制顺序排列的形状（中性轮廓在下，肌肉在上）。
class BodyView {
  BodyView(Map<String, dynamic> data)
    : box = _box(data['viewBox'] as List),
      shapes = [
        for (final e in (data['other'] as Map).entries)
          for (final d in e.value as List)
            BodyShape(e.key as String, d as String, neutral: true),
        for (final id in _drawOrder)
          for (final d in (data['muscles'] as Map)[id] as List? ?? const [])
            BodyShape(id, d as String),
      ];
  final Rect box;
  final List<BodyShape> shapes;

  static Rect _box(List v) => Rect.fromLTWH(
    (v[0] as num).toDouble(),
    (v[1] as num).toDouble(),
    (v[2] as num).toDouble(),
    (v[3] as num).toDouble(),
  );

  /// 正面整块三角肌归中束，前束是叠在它上面的子区：先画中束。
  static final _drawOrder = [
    'delt_side',
    for (final m in MUSCLES)
      if (m['id'] != 'delt_side') m['id']!,
  ];
}

/// MuscleMap 人体（见 assets/muscle_map.json，MIT）。同一份数据按性别各解析一次，
/// 不在绘制或点击判断里重复解析。
class BodyGeometry {
  BodyGeometry._(Map<String, dynamic> sex)
    : front = BodyView(Map<String, dynamic>.from(sex['front'] as Map)),
      back = BodyView(Map<String, dynamic>.from(sex['back'] as Map));
  final BodyView front, back;

  static final _cache = Expando<Map<bool, BodyGeometry>>();
  factory BodyGeometry(Map<String, dynamic> data, {bool female = false}) =>
      (_cache[data] ??= {})[female] ??= BodyGeometry._(
        Map<String, dynamic>.from(data[female ? 'female' : 'male'] as Map),
      );

  /// 正背两面共用一个比例，两个人在卡片里一样高。
  Size get extent => Size(
    math.max(front.box.width, back.box.width),
    math.max(front.box.height, back.box.height),
  );
}

/// 肌肉图画男版还是女版。默认跟资料里的性别；引导流程里资料还没保存时用 [BodySexScope] 覆盖。
class BodySexScope extends InheritedWidget {
  const BodySexScope({super.key, required this.female, required super.child});
  final bool female;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BodySexScope>();
    if (scope != null) return scope.female;
    final app = context
        .dependOnInheritedWidgetOfExactType<AppScope>()
        ?.notifier;
    return app?.profile?['sex'] == 'female';
  }

  @override
  bool updateShouldNotify(BodySexScope old) => female != old.female;
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
      final e = geometry.extent;
      final height = math.min(constraints.maxWidth * e.height / e.width, 300.0);
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
        label: AppMessages.of(context).text(back ? '背面肌肉图' : '正面肌肉图'),
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
  BodyView get view => back ? geometry.back : geometry.front;
  double _scale(Size size) {
    final e = geometry.extent;
    return math.min(size.width / e.width, size.height / e.height);
  }

  Offset _origin(Size size, double scale) => Offset(
    (size.width - view.box.width * scale) / 2 - view.box.left * scale,
    (size.height - view.box.height * scale) / 2 - view.box.top * scale,
  );

  /// 点中的肌肉；小肌肉不好点，落在 10 点以内的最小那块也算。
  String? muscleAt(Offset point, Size size) {
    final scale = _scale(size), origin = _origin(size, scale);
    final p = (point - origin) / scale;
    for (final shape in view.shapes.reversed) {
      if (!shape.neutral && shape.path.contains(p)) return shape.id;
    }
    final slop = 10 / scale;
    BodyShape? best;
    var bestArea = double.infinity;
    for (final shape in view.shapes) {
      if (shape.neutral) continue;
      final r = shape.path.getBounds();
      if (!r.inflate(slop).contains(p)) continue;
      final area = r.width * r.height;
      if (area < bestArea) {
        best = shape;
        bestArea = area;
      }
    }
    return best?.id;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _scale(size), origin = _origin(size, scale);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    // 分隔线按屏幕像素算粗细，不随缩放变化。
    final seam = Paint()
      ..color = palette.card
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = .9 / scale;
    for (final shape in view.shapes) {
      canvas.drawPath(
        shape.path,
        Paint()..color = shape.neutral ? palette.fill2 : colors[shape.id]!,
      );
      if (!shape.neutral) canvas.drawPath(shape.path, seam);
    }
    if (selected.isNotEmpty) {
      final ring = Paint()
        ..color = palette.text
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.6 / scale;
      for (final shape in view.shapes) {
        if (!shape.neutral && shape.id == selected) {
          canvas.drawPath(shape.path, ring);
        }
      }
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
