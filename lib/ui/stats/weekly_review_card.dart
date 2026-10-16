import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/body.dart' as body;
import '../../domain/format.dart';
import '../../domain/goals.dart';
import '../../domain/weekly_review.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';

Map<String, dynamic>? weeklyReviewFor(AppController app) {
  final days = app.repo.allDays().map((k, v) => MapEntry(k, jsonMap(v)));
  return weeklyReview(
    today: app.today,
    days: days,
    meals: app.repo.meals,
    bodyEntries: app.bodyEntries,
    stage: app.targets?['stage'] as String?,
    kcalGoal: app.kcalGoal,
    proteinGoal: app.proteinGoal,
    trainTarget: weekTargetFromHistory(
      jsNumber(app.goals['weekDays']),
      jsonMap(app.plan['schedule']).length,
      days,
    ).toInt(),
    kcalFloor: app.profile == null ? 0 : body.kcalFloor(app.profile!),
    done: app.reviewDone,
  );
}

/// The compact version shares the same data and actions in Today's tip slot.
class WeeklyReviewCard extends StatefulWidget {
  const WeeklyReviewCard({
    super.key,
    required this.review,
    this.compact = false,
  });
  final Map<String, dynamic> review;
  final bool compact;

  @override
  State<WeeklyReviewCard> createState() => _WeeklyReviewCardState();
}

class _WeeklyReviewCardState extends State<WeeklyReviewCard> {
  bool busy = false;
  Future<void> finish(bool apply) async {
    if (busy) return;
    setState(() => busy = true);
    final app = context.app;
    try {
      if (apply) {
        await app.adjustKcal(
          jsNumber(jsonMap(widget.review['action'])['delta']).toInt(),
        );
      }
      await app.finishWeeklyReview('${widget.review['week']}');
      if (apply) app.toast.show('已调整：每日 ${app.kcalGoal} 千卡');
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, r = widget.review;
    final action = jsonMap(r['action']);
    Widget metric(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: p.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
        ],
      ),
    );
    Widget button(String label, {bool apply = false}) => Semantics(
      button: true,
      label: label,
      enabled: !busy,
      child: Pressable(
        onTap: busy ? null : () => finish(apply),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: apply && !widget.compact ? p.tint : p.fill2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: apply && !widget.compact
                  ? p.onTint
                  : apply
                  ? p.tint
                  : p.secondary,
            ),
          ),
        ),
      ),
    );
    final change = r['weightChange'] as num?;
    return Container(
      padding: EdgeInsets.all(widget.compact ? 14 : 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '上周回顾',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r['label']}',
            style: TextStyle(fontSize: 13, color: p.secondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              metric('训练', '${r['trainDays']}/${r['trainTarget']} 天', p.tint),
              metric('蛋白达标', '${r['proteinDays']} 天', p.protein),
              metric('热量在范围', '${r['kcalDays']} 天', p.kcal),
            ],
          ),
          if (r['weightAvg'] != null) ...[
            const SizedBox(height: 12),
            Text(
              '体重均值 ${fmt(r['weightAvg'])} kg${change == null
                  ? ''
                  : change.abs() < 0.05
                  ? ' · 与前一周持平'
                  : ' · ${change < 0 ? '↓' : '↑'}${fmt(double.parse(change.abs().toStringAsFixed(1)))} kg'}',
              style: TextStyle(fontSize: 13, color: p.secondary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${r['message']}',
            style: TextStyle(
              fontSize: widget.compact ? 14 : 15,
              height: 1.45,
              color: p.secondary,
            ),
          ),
          const SizedBox(height: 14),
          if (action.isNotEmpty && widget.compact)
            Row(
              children: [
                Expanded(child: button('应用：${action['label']}', apply: true)),
                const SizedBox(width: 8),
                button('先不调'),
              ],
            )
          else if (action.isNotEmpty) ...[
            button('应用：${action['label']}', apply: true),
            const SizedBox(height: 6),
            button('先不调'),
          ] else
            button('知道了'),
        ],
      ),
    );
  }
}
