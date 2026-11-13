import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/units.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';

/// 训练模式内的组间休息视图：大倒计时圆环（发力橙）、+30 秒 / 跳过、下一组与下一个动作预告。
/// 只在训练页内占主区域，不使用 kit 里的 RestBar。
class TrainingRestView extends StatefulWidget {
  const TrainingRestView({
    super.key,
    required this.app,
    required this.exercise,
    required this.nextSet,
    required this.nextSetDetail,
    this.record,
    this.onExtraSet,
    this.nextExercise,
    this.nextExerciseDetail = const TextSpan(),
  });
  final AppController app;
  final Map<String, dynamic> exercise;

  /// 下一组的序号；本动作已做满时为 null。
  final int? nextSet;

  /// 下一组的重量 × 次数（中文模板，由 LText.rich 逐段本地化）。
  final InlineSpan nextSetDetail;
  final Map<String, dynamic>? nextExercise;
  final InlineSpan nextExerciseDetail;

  /// 刚破的纪录「动作名 · 数值」；非 null 时在计时环上方显示一行克制的提示。
  final String? record;

  /// 做满计划组数后的次要入口「再来一组」；null 则不显示。
  final VoidCallback? onExtraSet;

  @override
  State<TrainingRestView> createState() => _TrainingRestViewState();
}

class _TrainingRestViewState extends State<TrainingRestView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && widget.app.rest.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _soft(BuildContext context, String label, VoidCallback tap) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.fill2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: LText(
            label,
            style: TextStyle(
              color: p.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _extra(BuildContext context, VoidCallback tap) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('再来一组'),
      excludeSemantics: true,
      child: Pressable(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          child: LText(
            '再来一组',
            style: TextStyle(
              color: p.secondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordLine(BuildContext context, String label) {
    final p = context.pal;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Padding(
      key: const ValueKey('training-record'),
      padding: const EdgeInsets.only(bottom: 12),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(label),
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: Duration(milliseconds: reduce ? 0 : 260),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.tintSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          // 一行说完；动作名太长时整体缩小，不把「5 kg」拆到两行。
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: LText(
              '新纪录 · $label',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: p.tint,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _preview(
    BuildContext context,
    Map<String, dynamic> ex,
    String title,
    InlineSpan detail,
  ) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          ExerciseThumb(ex: ex, size: 56, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText.rich(
                  TextSpan(text: title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                LText.rich(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rest = widget.app.rest;
    final msLeft = math.max(
      0,
      rest.untilMs - DateTime.now().millisecondsSinceEpoch,
    );
    final left = (msLeft / 1000).ceil();
    final total = math.max(1, rest.total);
    final progress = (msLeft / (total * 1000)).clamp(0.0, 1.0);
    final nextSet = widget.nextSet;
    final next = widget.nextExercise;
    return LayoutBuilder(
      builder: (context, box) {
        final ring = math.min(
          math.min(box.maxWidth * .74, 300.0),
          math.max(
            widget.record == null ? 190.0 : 172.0,
            box.maxHeight * .42 - (widget.record == null ? 0 : 56),
          ),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.record != null) _recordLine(context, widget.record!),
              Center(
                child: SizedBox.square(
                  dimension: ring,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: progress,
                      track: p.fill2,
                      color: p.tint,
                      stroke: math.max(8, ring * .045),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: AppMessages.of(context).text(
                              '休息 ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                                style: AppText.num(p, ring * .27),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          LText(
                            '休息中 · 共 $total 秒',
                            style: TextStyle(color: p.secondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _soft(context, '+30 秒', () {
                      widget.app.haptics.selection();
                      rest.add(30);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _soft(context, '跳过休息', () {
                      widget.app.haptics.selection();
                      rest.clear();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (nextSet != null)
                _preview(
                  context,
                  widget.exercise,
                  '下一组：第 $nextSet 组',
                  widget.nextSetDetail,
                ),
              if (next != null) ...[
                const SizedBox(height: 10),
                _preview(
                  context,
                  next,
                  '接下来：${next['name']}',
                  widget.nextExerciseDetail,
                ),
              ],
              if (widget.onExtraSet != null) ...[
                const SizedBox(height: 6),
                _extra(context, widget.onExtraSet!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.stroke,
  });
  final double progress, stroke;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      base
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// 工具：把重量 × 次数格式化为预览文案（中文模板，交给 LText 本地化）。
String trainingSetDetail({
  required bool loaded,
  required num weight,
  required num reps,
  required bool seconds,
  Units units = Units.metric,
}) {
  final unit = seconds ? '秒' : '次';
  return loaded
      ? '${units.loadText(weight)} × ${fmt(reps)} $unit'
      : '${fmt(reps)} $unit';
}
