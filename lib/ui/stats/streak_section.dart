import 'package:flutter/widgets.dart';

import 'package:leandaily/l10n/app_messages.dart';

import '../../domain/format.dart';
import '../../domain/week_achievement.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/transitions.dart';
import 'progress_sections.dart';
import 'review_card.dart';
import 'stat_widgets.dart';
import 'weekly_review_card.dart';

/// 坚持：连续天数 + 本周达成 + 近 12 周格子；本周回顾（按肌肉的周组数）收在可展开部分。
class StreakSection extends StatelessWidget {
  const StreakSection({
    super.key,
    required this.summary,
    required this.hits,
    required this.trainTarget,
    this.review,
  });
  final ProgressSummary summary;
  final List<DayHit> hits;
  final num trainTarget;

  /// 上周回顾（有待处理的调整建议时才有）。
  final Map<String, dynamic>? review;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final trained = hits.where((h) => h.train).length;
    final protein = hits.where((h) => h.protein).length;
    final kcal = hits.where((h) => h.kcal).length;
    return StatBlock(
      title: '坚持',
      children: [
        Reveal(
          visible: review != null,
          child: review == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: WeeklyReviewCard(review: review!),
                ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${summary.streak}',
              style: AppText.num(
                p,
                44,
                color: summary.streak > 0 ? p.tint : p.secondary,
              ),
            ),
            const SizedBox(width: 6),
            LText('天连续', style: TextStyle(fontSize: 15, color: p.secondary)),
          ],
        ),
        const SizedBox(height: 20),
        LText('本周达成', style: AppText.hint(p)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Metric(
              label: '训练天数',
              value: '$trained',
              total: '/${fmt(trainTarget)}',
              color: p.tint,
              days: [for (final h in hits) h.train],
            ),
            const SizedBox(width: 12),
            _Metric(
              label: '蛋白达标',
              value: '$protein',
              total: '/7',
              color: p.protein,
              days: [for (final h in hits) h.protein],
            ),
            const SizedBox(width: 12),
            _Metric(
              label: '热量在范围内',
              value: '$kcal',
              total: '/7',
              color: p.kcal,
              days: [for (final h in hits) h.kcal],
            ),
          ],
        ),
        const SizedBox(height: 28),
        StreakGrid(summary: summary),
        const SizedBox(height: 14),
        const CollapsibleBlock(title: '本周回顾', child: ReviewCard()),
      ],
    );
  }
}

/// 一项达成：小标签 + 大数字 x/y + 周一到周日的 7 个点。
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.days,
  });
  final String label, value, total;
  final Color color;
  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Semantics(
        label: AppMessages.of(context).text(label),
        value: value + total,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText(label, style: AppText.hint(p), maxLines: 2),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: AppText.num(p, 28)),
                  Text(
                    total,
                    style: AppText.num(
                      p,
                      16,
                      weight: FontWeight.w600,
                      color: p.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < days.length && days[i] ? color : p.fill,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
