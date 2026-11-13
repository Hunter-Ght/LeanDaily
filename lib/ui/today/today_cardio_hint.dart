import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../../domain/cardio.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import 'today_model.dart';
import 'today_widgets.dart';

/// 休息日的有氧建议：方案带 `plan['cardio']`，而且本周记录的次数还不够时出现一行。
/// 没有这个字段、或本周已经够了，什么都不显示。
class TodayCardioHint extends StatelessWidget {
  const TodayCardioHint({super.key, required this.model});
  final TodayModel model;

  /// 这一周还差几次；不需要提示返回 null。
  static int? missing(TodayModel m) {
    final goal = cardioGoalOf(m.app.plan);
    if (goal == null) return null;
    final left =
        goal.perWeek - cardioSessionsInWeek(m.app.cardioEntries, m.iso);
    return left > 0 ? left : null;
  }

  @override
  Widget build(BuildContext context) {
    final left = missing(model);
    if (left == null) return const SizedBox.shrink();
    final p = context.pal;
    final minutes = cardioGoalOf(model.app.plan)!.minutes;
    // 今天已经记过有氧，就只说本周还差几次，不再说「今天适合走」。
    final doneToday = model.app.cardioOn(model.iso).isNotEmpty;
    return Padding(
      key: const ValueKey('cardio-hint'),
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.recoverSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: AppIcon('cardio', size: 20, color: p.recover)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LText(
              doneToday ? '本周还差 $left 次有氧' : '今天适合走 $minutes 分钟，本周还差 $left 次有氧',
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TodayButton(
            '记有氧',
            soft: true,
            onTap: () => openCardioSheet(context, date: model.iso),
          ),
        ],
      ),
    );
  }
}
