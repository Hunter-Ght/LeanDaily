import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_figure.dart';
import 'today_model.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

/// 首页主视觉：大标题 + 三个大数字 + 人体图 + 唯一的橙色主按钮。
class TodayHero extends StatelessWidget {
  const TodayHero({
    super.key,
    required this.model,
    required this.onStart,
    required this.onAdjust,
  });
  final TodayModel model;
  final VoidCallback onStart, onAdjust;
  @override
  Widget build(BuildContext context) {
    final m = model, p = context.pal;
    final minutes = plan.estimateMinutes(
      m.app.plan,
      m.items.map((i) => jsonMap(i['ex'])).toList(),
      jsNumber(jsonMap(m.workout['warmup'])['minutes']),
    );
    Widget stat(Object value, String unit) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$value', style: AppText.num(p, 26)),
        const SizedBox(width: 3),
        LText(unit, style: TextStyle(fontSize: 14, color: p.secondary)),
      ],
    );
    final total = jsNumber(m.prog['totalSets']);
    final done = jsNumber(m.prog['doneSets']);
    final figure = TodayFigureData.of(m, training: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText('今天练', style: AppText.display(p, size: 34)),
          LText(
            workoutTitle('${m.workout['name']}'),
            style: AppText.display(p, size: 34, color: p.tint),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              stat(m.items.length, '个动作'),
              stat(minutes, '分钟'),
              stat(fmt(total), '组'),
            ],
          ),
          const SizedBox(height: 8),
          TodayFigure(data: figure),
          const SizedBox(height: 16),
          FadeSwitcher(
            child: Column(
              key: ValueKey(m.complete ? 'complete' : 'active'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: m.complete
                  ? [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: p.recoverSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: AppIcon(
                                'check',
                                size: 16,
                                color: p.recover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LText(
                              '今天练完了。好好吃饭、补够蛋白质。${m.next != null ? '下次 ${weekday('${m.next!['iso']}')}：${workoutTitle('${m.next!['workout']['name']}')}。' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                  : [
                      Visibility(
                        visible: m.started,
                        maintainState: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: done.toDouble()),
                                duration: Duration(
                                  milliseconds:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? 0
                                      : 300,
                                ),
                                builder: (context, v, _) => LText.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: fmt((v * 10).round() / 10),
                                        style: AppText.num(p, 22),
                                      ),
                                      TextSpan(
                                        text: ' / ${fmt(total)} 组',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                          color: p.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TodayBar(
                                  height: 6,
                                  value: total > 0
                                      ? (done / total).toDouble()
                                      : 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TodayButton(
                        m.started ? '继续训练' : '开始训练',
                        filled: true,
                        large: true,
                        onTap: onStart,
                      ),
                      if (m.firstOpen.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: LText(
                            '下一项 · ${m.all.where((e) => e['id'] == m.firstOpen).firstOrNull?['name'] ?? ''}',
                            style: TextStyle(fontSize: 13, color: p.secondary),
                          ),
                        ),
                      ],
                    ],
            ),
          ),
          Semantics(
            button: true,
            label: AppMessages.of(context).text(adjustmentSummary(m)),
            child: Pressable(
              onTap: onAdjust,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: LText(
                  adjustmentSummary(m),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.secondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String adjustmentSummary(TodayModel m) {
  final parts = [
    if (m.ready == 'tired') '有点累',
    if (m.ready == 'bad') '不舒服',
    if (m.lite) '精简',
  ];
  return '调整今天的训练${parts.isEmpty ? '' : ' · ${parts.join(' · ')}'} ›';
}
