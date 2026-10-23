import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../domain/motion.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';

/// 矢量动作示范：扁平人形 + 发力肌肉随用力程度变橙 + 教学辅助虚线。
/// 自己持有动画时钟；[paused] 时停在当前帧，[still] 时（减少动态效果）停在发力最大的姿势。
class MotionDemo extends StatefulWidget {
  const MotionDemo({
    super.key,
    required this.spec,
    this.paused = false,
    this.still = false,
    this.showPhase = false,
  });
  final MotionSpec spec;
  final bool paused, still, showPhase;

  @override
  State<MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<MotionDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);
  final ValueNotifier<String> _phase = ValueNotifier('');

  double get _time => widget.still
      ? widget.spec.peakTime + .01
      : _clock.value * widget.spec.period;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_syncPhase);
    _sync(restart: true);
  }

  @override
  void didUpdateWidget(MotionDemo old) {
    super.didUpdateWidget(old);
    _sync(restart: !identical(old.spec, widget.spec));
  }

  void _sync({bool restart = false}) {
    _clock.duration = Duration(
      milliseconds: (widget.spec.period * 1000).round(),
    );
    if (restart) _clock.value = 0;
    if (widget.paused || widget.still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
    _syncPhase();
  }

  void _syncPhase() => _phase.value = sampleMotion(widget.spec, _time).phase;

  @override
  void dispose() {
    _clock.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _MotionPainter(
            spec: widget.spec,
            time: () => _time,
            repaint: _clock,
            colors: _MotionInk.of(p),
          ),
        ),
        if (widget.showPhase)
          Positioned(
            left: 10,
            bottom: 10,
            child: ValueListenableBuilder<String>(
              valueListenable: _phase,
              builder: (context, phase, _) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.scrim,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: LText(
                  '$phase${widget.paused ? ' · 已暂停' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.onTint,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MotionInk {
  const _MotionInk({
    required this.near,
    required this.far,
    required this.tint,
    required this.guide,
    required this.floor,
    required this.shadow,
    required this.prop,
    required this.propHi,
    required this.light,
  });

  /// 人形是不透明的：远侧肢体被近侧挡住时不会透出来。
  factory _MotionInk.of(AppPalette p) {
    final base = Color.alphaBlend(p.fill2, p.card);
    return _MotionInk(
      near: Color.lerp(base, p.text, .2)!,
      far: Color.lerp(base, p.text, .1)!,
      tint: p.tint,
      guide: p.tint.withValues(alpha: .55),
      floor: p.sep,
      shadow: p.text.withValues(alpha: .07),
      prop: Color.lerp(base, p.text, .62)!,
      propHi: Color.lerp(base, p.text, .38)!,
      light: p.onTint.withValues(alpha: .22),
    );
  }
  final Color near, far, tint, guide, floor, shadow, prop, propHi, light;
}

class _MotionPainter extends CustomPainter {
  _MotionPainter({
    required this.spec,
    required this.time,
    required this.colors,
    required Listenable repaint,
  }) : super(repaint: repaint);
  final MotionSpec spec;
  final double Function() time;
  final _MotionInk colors;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = sampleMotion(spec, time());
    final b = spec.bounds;
    final pad = math.min(size.width, size.height) * .06;
    final s = math.min(
      (size.width - 2 * pad) / (b[2] - b[0]),
      (size.height - 2 * pad) / (b[3] - b[1]),
    );
    // 水平居中；地面贴近底部。
    final ox = size.width / 2 - (b[0] + b[2]) / 2 * s;
    final oy = size.height - pad + b[1] * s;
    Offset at(P q) => Offset(ox + q.x * s, oy - q.y * s);

    // 地面与接触阴影。
    canvas.drawLine(
      Offset(0, oy),
      Offset(size.width, oy),
      Paint()
        ..color = colors.floor
        ..strokeWidth = 1,
    );
    final feet = pose.parts.where((e) => e.id.startsWith('foot')).toList();
    final hands = pose.parts.where((e) => e.id.startsWith('hand')).toList();
    final contacts = [
      ...feet,
      if (spec.view == MotionView.side && pose.joints['wristN']!.y < 12)
        ...hands,
    ];
    for (final c in contacts) {
      final mid = at(P.lerp(c.a, c.b, .5));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(mid.dx, oy),
          width: ((c.b - c.a).length + 14) * s,
          height: 4.5 * s,
        ),
        Paint()
          ..color = colors.shadow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
      );
    }

    // 教学辅助线在人形后面。
    for (final g in spec.guides) {
      final (a, c) = g.y != null
          ? (at(P(g.x0, g.y!)), at(P(g.x1, g.y!)))
          : (() {
              final j1 = pose.joints[g.j1]!, j2 = pose.joints[g.j2]!;
              final lift = (j2 - j1).unit.ccw * g.lift;
              return _extend(at(j1 + lift), at(j2 + lift), 10 * s);
            })();
      _dashed(canvas, a, c, colors.guide, s);
    }

    final marksByPart = <String, List<MotionMark>>{};
    for (final m in spec.marks) {
      (marksByPart[m.part] ??= []).add(m);
    }
    for (final part in pose.parts) {
      final path = part.poly.isNotEmpty
          ? _smooth(part.poly.map(at).toList())
          : _capsule(at(part.a), at(part.b), part.ra * s, part.rb * s);
      final body = part.layer == 0 ? colors.far : colors.near;
      canvas.drawPath(path, Paint()..color = body);
      // 自上而下的柔光：给扁平人形一点体积感。
      final box = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(box.topCenter, box.bottomCenter, [
            colors.light,
            colors.light.withValues(alpha: 0),
          ]),
      );
      final marks = marksByPart[part.id];
      if (marks == null) continue;
      canvas.save();
      canvas.clipPath(path);
      for (final m in marks) {
        final level = (m.weight * (.18 + .82 * pose.load)).clamp(0.0, 1.0);
        final dir = (part.b - part.a).unit;
        final n = dir.ccw;
        double r(double f) => part.ra + (part.rb - part.ra) * f.clamp(0, 1);
        P end(double f) => part.a + (part.b - part.a) * f + n * (m.off * r(f));
        final mark = _capsule(
          at(end(m.from)),
          at(end(m.to)),
          m.width * r(m.from) * s,
          m.width * r(m.to) * s,
        );
        final hue = Color.lerp(
          body,
          colors.tint,
          part.layer == 0 ? level * .75 : level,
        )!;
        canvas.drawPath(
          mark,
          Paint()
            ..color = hue
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, .9 * s),
        );
      }
      canvas.restore();
    }

    for (final prop in spec.props) {
      final c = at(pose.joints[prop.at]!);
      canvas.drawCircle(c, 6.8 * s, Paint()..color = colors.prop);
      canvas.drawCircle(
        c,
        6.8 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * s
          ..color = colors.propHi,
      );
      canvas.drawCircle(c, 2.2 * s, Paint()..color = colors.propHi);
    }
  }

  static (Offset, Offset) _extend(Offset a, Offset b, double by) {
    final d = b - a;
    final u = d / d.distance;
    return (a - u * by, b + u * by);
  }

  static void _dashed(Canvas canvas, Offset a, Offset b, Color c, double s) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = math.max(1, .9 * s)
      ..strokeCap = StrokeCap.round;
    final d = b - a;
    final len = d.distance;
    final u = d / len;
    final dash = 3.2 * s, gap = 3.4 * s;
    for (var x = 0.0; x < len; x += dash + gap) {
      canvas.drawLine(a + u * x, a + u * math.min(len, x + dash), paint);
    }
  }

  /// 两端半径不同的圆头胶囊（两圆的外公切线围成）。
  static Path _capsule(Offset a, Offset b, double ra, double rb) {
    final d = b - a;
    final dist = d.distance;
    if (dist < 1e-3 || dist <= (ra - rb).abs()) {
      final big = ra >= rb ? a : b;
      return Path()
        ..addOval(Rect.fromCircle(center: big, radius: math.max(ra, rb)));
    }
    final theta = math.atan2(d.dy, d.dx);
    final alpha = math.acos(((ra - rb) / dist).clamp(-1.0, 1.0));
    Offset on(Offset c, double r, double ang) =>
        c + Offset(math.cos(ang), math.sin(ang)) * r;
    return Path()
      ..moveTo(on(a, ra, theta + alpha).dx, on(a, ra, theta + alpha).dy)
      ..lineTo(on(b, rb, theta + alpha).dx, on(b, rb, theta + alpha).dy)
      ..arcTo(
        Rect.fromCircle(center: b, radius: rb),
        theta + alpha,
        -2 * alpha,
        false,
      )
      ..lineTo(on(a, ra, theta - alpha).dx, on(a, ra, theta - alpha).dy)
      ..arcTo(
        Rect.fromCircle(center: a, radius: ra),
        theta - alpha,
        -(2 * math.pi - 2 * alpha),
        false,
      )
      ..close();
  }

  /// 过各点中点的二次曲线闭合轮廓。
  static Path _smooth(List<Offset> pts) {
    final path = Path();
    Offset mid(Offset a, Offset b) => (a + b) / 2;
    final n = pts.length;
    final start = mid(pts[n - 1], pts[0]);
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < n; i++) {
      final c = pts[i], m = mid(c, pts[(i + 1) % n]);
      path.quadraticBezierTo(c.dx, c.dy, m.dx, m.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_MotionPainter old) =>
      old.spec != spec || old.colors != colors;
}

/// 测试与预览用：把某一时刻画成图片。
Future<ui.Image> renderMotionFrame(
  MotionSpec spec,
  double t,
  AppPalette palette,
  Size size, {
  double pixelRatio = 2,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  canvas.drawRect(Offset.zero & size, Paint()..color = palette.card);
  canvas.drawRect(Offset.zero & size, Paint()..color = palette.fill2);
  _MotionPainter(
    spec: spec,
    time: () => t,
    colors: _MotionInk.of(palette),
    repaint: const AlwaysStoppedAnimation(0),
  ).paint(canvas, size);
  return recorder.endRecording().toImage(
    (size.width * pixelRatio).round(),
    (size.height * pixelRatio).round(),
  );
}
