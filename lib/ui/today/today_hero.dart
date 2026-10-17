import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_model.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

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
    final m = model;
    Widget text(
      String s, {
      double size = 14,
      bool bold = false,
      Color? color,
      double height = 1.45,
    }) => LText(
      s,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        height: height,
        color: color ?? context.pal.secondary,
      ),
    );

    final p = context.pal;
    return TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text(
            '今日训练${m.workout['tag'] == null ? '' : ' · ${m.workout['tag']}'}'
                .replaceAll('刺激', '练'),
            size: 13,
          ),
          const SizedBox(height: 4),
          LText(
            workoutTitle('${m.workout['name']}'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: p.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: jsNumber(m.prog['doneSets']).toDouble(),
                        ),
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 300,
                        ),
                        builder: (context, done, _) => LText.rich(
                          TextSpan(
                            text: fmt((done * 10).round() / 10),
                            children: [
                              TextSpan(
                                text: ' / ${m.prog['totalSets']} 组',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  color: p.secondary,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.05,
                            letterSpacing: -1.6,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    AppIcon('clock', size: 16, color: p.secondary),
                    const SizedBox(width: 4),
                    text(
                      '约 ${plan.estimateMinutes(m.app.plan, m.items.map((i) => jsonMap(i['ex'])).toList(), jsNumber(jsonMap(m.workout['warmup'])['minutes']))} 分钟',
                    ),
                  ],
                ),
              ),
            ],
          ),
          TodayBar(
            value: jsNumber(m.prog['totalSets']) > 0
                ? (jsNumber(m.prog['doneSets']) / jsNumber(m.prog['totalSets']))
                      .toDouble()
                : 0,
          ),
          FadeSwitcher(
            child: Column(
              key: ValueKey(m.complete ? 'complete' : 'active'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: m.complete
                  ? [
                      const SizedBox(height: 10),
                      text(
                        '今天练完了。好好吃饭、补够蛋白质。${m.next != null ? '下次 ${weekday('${m.next!['iso']}')}：${workoutTitle('${m.next!['workout']['name']}')}。' : ''}',
                        bold: true,
                        color: p.ok,
                      ),
                    ]
                  : [
                      const SizedBox(height: 14),
                      TodayButton(
                        m.started ? '继续训练' : '开始训练',
                        filled: true,
                        large: true,
                        onTap: onStart,
                      ),
                      if (m.firstOpen.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        text(
                          '下一项 · ${m.all.where((e) => e['id'] == m.firstOpen).firstOrNull?['name'] ?? ''}',
                          size: 13,
                        ),
                      ],
                    ],
            ),
          ),
          const SizedBox(height: 2),
          Container(height: .5, color: p.sep),
          Semantics(
            button: true,
            label: AppMessages.of(context).text(adjustmentSummary(m)),
            child: Pressable(
              onTap: onAdjust,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(child: text(adjustmentSummary(m), size: 13)),
                  ],
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
