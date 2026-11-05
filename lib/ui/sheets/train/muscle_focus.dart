import 'package:leandaily/l10n/app_messages.dart';

import 'package:flutter/widgets.dart';

import '../../../domain/movements.dart';
import '../../../theme/theme.dart';
import '../../kit/plan_widgets.dart' show MiniBody;
import 'exercise_info.dart';

/// “练哪里”卡片：前后两个小人，主练肌肉用强调色、辅助肌肉用淡色，旁边写大白话位置和专业名。
/// 认不出肌肉的动作（有氧、自定义名）不显示。
class MuscleFocusCard extends StatelessWidget {
  const MuscleFocusCard({super.key, required this.name, this.part});
  final String name;
  final String? part;

  @override
  Widget build(BuildContext context) {
    final mv = musclesOf(name, part);
    if (mv == null || mv['matched'] == 'part') return const SizedBox.shrink();
    final p = context.pal;
    final messages = AppMessages.of(context);
    final roles = muscleRoles(name, part);
    final main = muscleList(messages, roles.main);
    final assist = muscleList(messages, roles.assist);
    Widget line(String label, String text, Color dot) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        Expanded(
          child: Text(
            '${messages.text(label)}$text',
            style: TextStyle(color: p.text, fontSize: 15, height: 1.35),
          ),
        ),
      ],
    );
    return Container(
      key: const ValueKey('muscle-focus'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MiniBody(
            height: 120,
            levels: {
              for (final id in roles.main) id: 3,
              for (final id in roles.assist) id: 1,
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line('主练：', main, p.tint),
                if (assist.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  line('辅助：', assist, p.tint.withValues(alpha: 0.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
