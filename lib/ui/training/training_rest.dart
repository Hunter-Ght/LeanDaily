import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
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
          math.max(190.0, box.maxHeight * .42),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
}) {
  final unit = seconds ? '秒' : '次';
  return loaded
      ? '${fmt(weight)} kg × ${fmt(reps)} $unit'
      : '${fmt(reps)} $unit';
}
