import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/sheet.dart';
import '../today/workout_title.dart';
import '../today/today_widgets.dart';

class PreviewSheet extends StatelessWidget {
  const PreviewSheet({super.key, required this.iso});
  final String iso;
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final slot = plan.workoutFor(app.plan, iso, jsonMap(app.dayStates[iso]));
    final workout = jsonMap(slot['workout']);
    final all = plan.exercisesFor(app.plan, workout, iso);
    final core = plan
        .exercisesFor(app.plan, workout, iso, true)
        .map((e) => e['id'])
        .toSet();
    final need = all.where((e) => !jsTruthy(e['optional']));
    final nx = slot['kind'] == 'rest'
        ? plan.nextTraining(app.plan, iso, app.dayStates)
        : null;
    final train = slot['kind'] == 'train';
    return AppSheet(
      title: '${weekday(iso)}${iso == app.today ? ' · 今天' : ''}',
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text.rich(
              TextSpan(
                text: train ? workoutTitle('${workout['name']}') : '休息日',
                children: [
                  if (train)
                    TextSpan(
                      text: workout['venue'] == 'gym' ? ' · 健身房' : ' · 居家',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: p.secondary,
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              train
                  ? '${need.fold<num>(0, (n, e) => n + jsNumber(e['target']))} 组 · ${need.length} 个动作 · 约 ${plan.estimateMinutes(app.plan, all, jsNumber(jsonMap(workout['warmup'])['minutes']))} 分钟'
                  : '散步、睡够 7～9 小时，蛋白质照样吃够。',
              style: TextStyle(fontSize: 14, height: 1.5, color: p.secondary),
            ),
          ),
          if (jsTruthy(workout['note']) || nx != null)
            Container(
              margin: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(minHeight: 72),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                train
                    ? '${workout['note']}'
                    : '下次训练：${weekday('${nx!['iso']}')} · ${workoutTitle('${nx['workout']['name']}')}',
                style: TextStyle(fontSize: 14, height: 1.5, color: p.secondary),
              ),
            ),
          if (train) ...[
            const SizedBox(height: 16),
            for (final e in all)
              TodayExerciseRow(
                exercise: e,
                onOpen: () => openGuide(context, '${e['name']}', iso: iso),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                '精简版只做：${all.where((e) => core.contains(e['id'])).map((e) => e['name']).join('、')}。点任意动作看示范。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: p.secondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
