import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/movements.dart' show MUSCLES;
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../stats/muscle/body_map.dart';

/// 肌肉在人体图上的状态。首页（今天练）、记录（那天练了）、进度（几周累计）、器械（主练/辅助）共用。
enum MuscleTone {
  /// 中性，没涉及。
  none,

  /// 发力 / 今天练 / 主练：发力橙。
  effort,

  /// 辅助发力：淡橙。
  assist,

  /// 恢复中：恢复青。
  recover,
}

/// 前后两面的人体图。[tones] 给每块肌肉一个状态；[heat] 给 0~1 的累计强度（进度页热力图），
/// 两者都给时 [tones] 优先。[breathe] 让发力部位轻微“呼吸”，减少动态效果时停用。
class BodyFigure extends StatefulWidget {
  const BodyFigure({
    super.key,
    this.tones = const {},
    this.heat = const {},
    this.height = 240,
    this.breathe = false,
    this.semanticLabel,
  });

  final Map<String, MuscleTone> tones;
  final Map<String, double> heat;
  final double height;
  final bool breathe;
  final String? semanticLabel;

  /// 呼吸动画总开关。测试里关掉：无限循环的动画会让 pumpAndSettle 等不到稳定。
  static bool animateBreath = true;

  static Future<Map<String, dynamic>>? _data;
  static Map<String, dynamic>? _loaded;
  static bool get isLoaded => _loaded != null;
  static Future<Map<String, dynamic>> load() => _data ??= rootBundle
      .loadString('assets/muscle_map.json')
      .then((s) => _loaded = jsonDecode(s) as Map<String, dynamic>);

  @override
  State<BodyFigure> createState() => _BodyFigureState();
}

class _BodyFigureState extends State<BodyFigure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(BodyFigure old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on =
        widget.breathe &&
        BodyFigure.animateBreath &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// 热力色阶：几乎没练（< 0.08）保持中性，往上按 1.4 次方变浓，让“练得少”和“练得多”拉开差距。
  static double _heat(double? v) {
    final t = (v ?? 0).clamp(0, 1).toDouble();
    return t < .08 ? 0 : math.pow(t, 1.4).toDouble();
  }

  Map<String, Color> _colors(AppPalette p, double breath) {
    final neutral = p.fill;
    final effort = Color.lerp(p.tint.withValues(alpha: .78), p.tint, breath)!;
    return {
      for (final m in MUSCLES)
        m['id']!: switch (widget.tones[m['id']]) {
          MuscleTone.effort => effort,
          MuscleTone.assist => Color.lerp(neutral, p.tint, .45)!,
          MuscleTone.recover => Color.lerp(neutral, p.recover, .75)!,
          _ => Color.lerp(neutral, p.tint, _heat(widget.heat[m['id']]))!,
        },
    };
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.semanticLabel,
    child: SizedBox(
      height: widget.height,
      child: FutureBuilder<Map<String, dynamic>>(
        future: BodyFigure.load(),
        initialData: BodyFigure._loaded,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final geometry = BodyGeometry(
            snapshot.data!,
            female: BodySexScope.of(context),
          );
          return AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final p = context.pal;
              final colors = _colors(p, widget.breathe ? _pulse.value : 1);
              return Row(
                children: [
                  for (final back in [false, true])
                    Expanded(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: BodyPainter(
                          geometry: geometry,
                          back: back,
                          colors: colors,
                          palette: p,
                          selected: '',
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
