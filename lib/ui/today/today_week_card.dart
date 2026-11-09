import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import 'today_model.dart';
import 'week_adherence.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

class _Ring extends CustomPainter {
  _Ring(this.value, this.track, this.color);
  final double value;
  final Color track, color;
  @override
  void paint(Canvas canvas, Size size) {
    const w = 8.0;
    final rect = (Offset(w / 2, w / 2) & Size(size.width - w, size.height - w));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0, 1),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.value != value || old.track != track || old.color != color;
}

/// 本周：圆环 + 本周天数 + 每天一格的计划预览。
class TodayWeekCard extends StatelessWidget {
  const TodayWeekCard({super.key, required this.model});
  final TodayModel model;

  @override
  Widget build(BuildContext context) {
    final m = model, p = context.pal;
    final adherence = weekAdherence(
      today: m.iso,
      history: m.history,
      savedDays: jsNumber(m.app.goals['weekDays']),
      planDays: jsonMap(m.app.plan['schedule']).length,
    );
    final ratio = adherence.target > 0
        ? (adherence.count / adherence.target).toDouble()
        : 0.0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: Duration(milliseconds: reduce ? 0 : 400),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => CustomPaint(
                    painter: _Ring(v, p.fill, p.tint),
                    child: child,
                  ),
                  child: Center(
                    child: Text(
                      '${adherence.count}',
                      style: AppText.num(p, 28),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      '本周 ${adherence.count}/${fmt(adherence.target)} 天',
                      style: AppText.title(p),
                    ),
                    if (adherence.streak > 0) ...[
                      const SizedBox(height: 4),
                      LText(
                        '连续 ${adherence.streak} 周',
                        style: TextStyle(fontSize: 13, color: p.secondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in plan.weekPlan(
                m.app.plan,
                m.iso,
                m.app.dayStates,
                m.history,
              ))
                Expanded(
                  child: Semantics(
                    button: true,
                    label: AppMessages.of(
                      context,
                    ).text('预览 ${d['label']} ${workoutTitle('${d['name']}')}'),
                    child: Pressable(
                      onTap: () => openDayPreview(context, '${d['iso']}'),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: jsTruthy(d['today']) ? p.fill2 : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            LText(
                              '${d['label']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: jsTruthy(d['today'])
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: jsTruthy(d['today'])
                                    ? p.text
                                    : p.secondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DayMark(
                              done: jsTruthy(d['done']),
                              train: d['kind'] == 'train',
                              missed: jsTruthy(d['past']),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一天的状态：已练 = 发力橙实心圆 + 勾；计划训练 = 橙色空心圆（已过去没练的变灰）；休息 = 中性小点。
/// 部位名称留给点开的那天预览。
class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.done,
    required this.train,
    required this.missed,
  });
  final bool done, train, missed;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: done
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: p.tint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon('check', size: 14, color: p.onTint),
                ),
              )
            : train
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: missed ? p.tertiary : p.tint,
                    width: 2,
                  ),
                ),
              )
            : Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: p.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
