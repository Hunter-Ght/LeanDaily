import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/routes.dart';

import '../../domain/format.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import 'today_cardio_hint.dart';
import 'today_figure.dart';
import 'today_model.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

/// 休息日首屏：大标题 + 仍在恢复的肌肉 + 下次训练。
class TodayRestCard extends StatelessWidget {
  const TodayRestCard({
    super.key,
    required this.model,
    required this.onSwap,
    required this.onRestore,
  });
  final TodayModel model;
  final VoidCallback onSwap, onRestore;
  @override
  Widget build(BuildContext context) {
    final m = model, p = context.pal;
    final figure = TodayFigureData.of(m, training: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText('今天休息', style: AppText.display(p, size: 34)),
          const SizedBox(height: 10),
          LText(
            '肌肉是在休息时长出来的。散步、睡够 7～9 小时、蛋白质吃够。',
            style: TextStyle(fontSize: 16, height: 1.45, color: p.secondary),
          ),
          TodayCardioHint(model: m),
          if (!figure.isEmpty) ...[
            const SizedBox(height: 12),
            TodayFigure(data: figure),
          ],
          if (m.next != null) ...[
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: AppMessages.of(context).text('查看下次训练'),
              child: Pressable(
                onTap: () => openDayPreview(context, '${m.next!['iso']}'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              '下次训练：${weekday('${m.next!['iso']}')}（${m.next!['inDays'] == 1 ? '明天' : '${m.next!['inDays']} 天后'}）',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LText(
                              workoutTitle('${m.next!['workout']['name']}'),
                              style: AppText.title(p),
                            ),
                          ],
                        ),
                      ),
                      LText(
                        '查看下次训练',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.secondary,
                        ),
                      ),
                      AppIcon('right', size: 16, color: p.tertiary),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              TodayButton('今天想加练', soft: true, onTap: onSwap),
              if (jsTruthy(m.slot['overridden']))
                TodayButton('恢复原计划', link: true, onTap: onRestore),
            ],
          ),
        ],
      ),
    );
  }
}
