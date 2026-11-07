import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/equipment.dart' show partOfExercise;
import '../../domain/free_training.dart';
import '../../domain/guide.dart';
import '../../domain/movements.dart';
import '../../theme/theme.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';
import 'train/exercise_info.dart';

/// 器械被占时：列出练同一块主练肌肉的其他动作，点一个就返回动作名。
class AlternativesSheet extends StatelessWidget {
  const AlternativesSheet({super.key, required this.exercise});
  final String exercise;

  // 没恢复的动作显示还要几天：取权重 >= 0.5 且没恢复的肌肉里最久的。
  ExerciseInfo _tag(Map status, FreeExercise e) {
    if (e.ready) return const ExerciseInfo(ready: true, recovery: '可以练');
    final weights = musclesOf(e.name, e.part)?['muscles'] as Map<String, num>?;
    var left = 0.0;
    for (final w in (weights ?? const <String, num>{}).entries) {
      final m = (status['byMuscle'] as Map)[w.key] as Map?;
      if (w.value >= 0.5 && m != null && m['recovered'] != true) {
        left = left < (m['daysLeft'] as num)
            ? (m['daysLeft'] as num).toDouble()
            : left;
      }
    }
    return ExerciseInfo(ready: false, recovery: daysLeftText(left));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.app;
    final status = recoveryStatus(app);
    final done = ((app.repo.recentByExercise()['last'] as Map).keys)
        .cast<String>()
        .toSet();
    final list = alternativesFor(
      status,
      exercise,
      owned: app.myGym,
      done: done,
    );
    final primary = musclesOf(exercise, partOfExercise(exercise))?['primary'];
    final muscle = primary == null ? null : MUSCLE[primary]?['name'];
    return AppSheet(
      title: muscle == null ? '换一个动作' : '换一个练$muscle的动作',
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            Padding(
              key: const ValueKey('alt-empty'),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  LText(
                    '没有找到合适的替代动作',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (app.myGym.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    LText(
                      '可以到“我的健身房”多勾选几台器械。',
                      textAlign: TextAlign.center,
                      style: AppText.hint(p),
                    ),
                  ],
                ],
              ),
            ),
          for (final e in list) _row(context, e, _tag(status, e)),
        ],
      ),
    );
  }

  // 只留一项信息：名字里已含器械名就写练的位置，否则写器械。
  String _line(BuildContext context, FreeExercise e) {
    final messages = AppMessages.of(context);
    final plain = plainMusclesOf(messages, e.name, e.part);
    final base = messages.text(e.equipment ?? '徒手');
    if (e.equipment == null || e.name.contains(e.equipment!)) {
      return plain.isEmpty ? base : plain;
    }
    return base;
  }

  Widget _row(BuildContext context, FreeExercise e, ExerciseInfo info) {
    final p = context.pal;
    final guide = guideFor({'name': e.name}) != null;
    return Container(
      key: ValueKey('alt-${e.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: e.name,
              child: Pressable(
                onTap: () => SheetController.of(context).close(e.name),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ExerciseThumb(
                        ex: {'name': e.name, 'part': e.part},
                        size: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                              e.name,
                              style: TextStyle(
                                color: p.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            LText(_line(context, e), style: AppText.hint(p)),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: RecoveryTag(info),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (guide)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SheetButton(
                '看示范',
                () => openGuide(context, e.name),
                soft: true,
              ),
            ),
        ],
      ),
    );
  }
}
