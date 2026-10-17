import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/routes.dart';

import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import 'today_model.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

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
    Widget links(List<Widget> items) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
    return TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText(
            '今天休息',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: context.pal.text,
            ),
          ),
          text('休息日', size: 13),
          const SizedBox(height: 10),
          text('肌肉是在休息时长出来的。散步、睡够 7～9 小时、蛋白质吃够。'),
          if (m.next != null) ...[
            const SizedBox(height: 12),
            text(
              '下次训练：${weekday('${m.next!['iso']}')}（${m.next!['inDays'] == 1 ? '明天' : '${m.next!['inDays']} 天后'}）',
              size: 15,
              bold: true,
              color: context.pal.text,
            ),
            text(
              workoutTitle('${m.next!['workout']['name']}'),
              size: 15,
              color: context.pal.text,
            ),
            const SizedBox(height: 6),
            text(
              plan
                  .exercisesFor(
                    m.app.plan,
                    jsonMap(m.next!['workout']),
                    '${m.next!['iso']}',
                  )
                  .map((e) => '${e['name']}')
                  .join(' · '),
              size: 13,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: AppMessages.of(context).text('查看下次训练'),
                child: Pressable(
                  onTap: () => openDayPreview(context, '${m.next!['iso']}'),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.centerLeft,
                    child: text('查看下次训练 ›', size: 13),
                  ),
                ),
              ),
            ),
          ],
          links([
            TodayButton('今天想加练', onTap: onSwap),
            if (jsTruthy(m.slot['overridden']))
              TodayButton('恢复原计划', onTap: onRestore),
          ]),
        ],
      ),
    );
  }
}
