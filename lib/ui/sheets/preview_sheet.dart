import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/movements.dart' show muscleRoles;
import '../../domain/muscles.dart';
import '../../domain/plan.dart' as plan;
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/body_figure.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../today/workout_title.dart';
import '../kit/units_scope.dart';

/// 某一天的预览：首页 hero 的缩小版。训练日是大标题 + 三个大数字 + 人体图 + 动作列表，
/// 休息日是大标题 + 一句建议 + 恢复人体图 + 下次训练预告。
class PreviewSheet extends StatelessWidget {
  const PreviewSheet({super.key, required this.iso});
  final String iso;
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final slot = plan.workoutFor(app.plan, iso, jsonMap(app.dayStates[iso]));
    final workout = jsonMap(slot['workout']);
    final all = plan.exercisesFor(app.plan, workout, iso);
    final core = plan
        .exercisesFor(app.plan, workout, iso, true)
        .map((e) => e['id'])
        .toSet();
    final need = all.where((e) => !jsTruthy(e['optional'])).toList();
    final train = slot['kind'] == 'train';
    final nx = train ? null : plan.nextTraining(app.plan, iso, app.dayStates);
    return AppSheet(
      title: '${weekday(iso)}${iso == app.today ? ' · 今天' : ''}',
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Title(
              day: weekday(iso),
              verb: train ? '练' : null,
              what: train ? workoutTitle('${workout['name']}') : '休息',
            ),
          ),
          if (train)
            ..._trainBody(context, workout, all, need, core)
          else
            ..._restBody(context, nx),
        ],
      ),
    );
  }

  List<Widget> _trainBody(
    BuildContext context,
    Map<String, dynamic> workout,
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> need,
    Set<Object?> core,
  ) {
    final app = context.app, p = context.pal;
    final minutes = plan.estimateMinutes(
      app.plan,
      all,
      jsNumber(jsonMap(workout['warmup'])['minutes']),
    );
    final sets = need.fold<num>(0, (n, e) => n + jsNumber(e['target']));
    final tones = <String, MuscleTone>{};
    for (final e in need) {
      final roles = muscleRoles(e['name'], '${e['part']}');
      for (final id in roles.main) {
        tones[id] = MuscleTone.effort;
      }
      for (final id in roles.assist) {
        tones.putIfAbsent(id, () => MuscleTone.assist);
      }
    }
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
    final home = workout['venue'] != 'gym';
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            stat(need.length, '个动作'),
            stat(minutes, '分钟'),
            stat(fmt(sets), '组'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(999),
              ),
              child: LText(
                home ? '居家' : '健身房',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
      if (tones.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _Figure(
            tones: tones,
            semanticLabel: AppMessages.of(context).text('今天练的肌肉和恢复情况'),
          ),
        ),
      if (jsTruthy(workout['note']))
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: LText(
            '${workout['note']}',
            style: TextStyle(fontSize: 15, height: 1.5, color: p.secondary),
          ),
        ),
      const SizedBox(height: 14),
      for (final (i, e) in all.indexed) ...[
        if (i > 0) Container(height: 1, color: p.sep),
        _ExerciseLine(
          exercise: e,
          onOpen: () => openGuide(context, '${e['name']}', iso: iso),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: LText(
          '精简版只做：${all.where((e) => core.contains(e['id'])).map((e) => e['name']).join('、')}。点任意动作看示范。',
          style: TextStyle(fontSize: 13, height: 1.45, color: p.secondary),
        ),
      ),
    ];
  }

  List<Widget> _restBody(BuildContext context, Map<String, dynamic>? nx) {
    final app = context.app, p = context.pal;
    // 这一天还在恢复的肌肉（按那天中午的状态算），没有就是一个干净的中性人体。
    final noon = isoDate(iso).add(const Duration(hours: 12));
    final now = app.clock();
    final at = (noon.isAfter(now) ? noon : now).millisecondsSinceEpoch;
    final status = muscleStatus(
      app.repo.allDays().map((k, v) => MapEntry(k, jsonMap(v))),
      at,
    );
    final tones = <String, MuscleTone>{};
    if (jsNumber(status['setCount']) > 0) {
      for (final entry in jsonMap(status['byMuscle']).entries) {
        if (!jsTruthy(jsonMap(entry.value)['recovered'])) {
          tones[entry.key] = MuscleTone.recover;
        }
      }
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: LText(
          '散步、睡够 7～9 小时，蛋白质照样吃够。',
          style: TextStyle(fontSize: 17, height: 1.5, color: p.text),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _Figure(
          tones: tones,
          semanticLabel: AppMessages.of(context).text('今天练的肌肉和恢复情况'),
        ),
      ),
      if (tones.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: p.recover,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              LText(
                '这天还在恢复',
                style: TextStyle(fontSize: 13, color: p.secondary),
              ),
            ],
          ),
        ),
      if (nx != null)
        Container(
          margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LText('下次训练', style: TextStyle(fontSize: 14, color: p.secondary)),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LText(
                      weekday('${nx['iso']}'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    Text(
                      ' · ',
                      style: TextStyle(fontSize: 17, color: p.secondary),
                    ),
                    LText(
                      workoutTitle('${nx['workout']['name']}'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// 第一行「周六 练」正文色，第二行部位发力橙；休息日是「周六 / 休息」。
class _Title extends StatelessWidget {
  const _Title({required this.day, required this.verb, required this.what});
  final String day, what;
  final String? verb;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = AppText.display(p, size: 32);
    // 和首页「今天练 / 胸 · 背 · 腹」同样分两行：部位多时也不会在奇怪的地方折行。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            LText(day, style: style),
            if (verb != null) ...[
              const SizedBox(width: 10),
              LText(verb!, style: style),
            ],
          ],
        ),
        LText(
          what,
          style: verb != null
              ? AppText.display(p, size: 32, color: p.tint)
              : style,
        ),
      ],
    );
  }
}

/// 动作行：缩略图 + 名称 + 右侧大号「组×次」；点开看动作要点。
class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.exercise, required this.onOpen});
  final Map<String, dynamic> exercise;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = exercise;
    final sets = fmt(e['target'] ?? e['sets']);
    final lo = jsString(e['min']), hi = jsString(e['max']);
    final range = lo == hi ? lo : '$lo–$hi';
    final sec = e['unit'] == 'sec';
    final weight = jsNumber(e['weight']);
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('${e['name']}，看示范'),
      child: Pressable(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              ExerciseThumb(ex: e),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      '${e['name']}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    if (weight > 0)
                      Text(
                        context.units.suggestedText(weight),
                        style: TextStyle(fontSize: 13, color: p.secondary),
                      ),
                    if (jsTruthy(e['optional']))
                      LText(
                        '可选',
                        style: TextStyle(fontSize: 12, color: p.tertiary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$sets×$range', style: AppText.num(p, 22)),
                  if (sec) ...[
                    const SizedBox(width: 2),
                    LText(
                      '秒',
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              AppIcon('right', size: 16, color: p.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 人体图：宽屏上不拉得太开，居中最宽 320。
class _Figure extends StatelessWidget {
  const _Figure({required this.tones, required this.semanticLabel});
  final Map<String, MuscleTone> tones;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: BodyFigure(
        tones: tones,
        height: 190,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}
