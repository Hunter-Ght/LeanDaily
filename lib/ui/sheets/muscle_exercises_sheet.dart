import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/catalog.dart';
import '../../domain/format.dart';
import '../../domain/muscles.dart';
import '../../domain/plan.dart';
import '../../theme/theme.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../kit/transitions.dart';
import '../today/workout_title.dart';

/// 从肌肉找到动作，再用领域层推荐训练日。所有修改通过 AppController 落盘。
class MuscleExercisesSheet extends StatefulWidget {
  const MuscleExercisesSheet({super.key, required this.muscleId});
  final String muscleId;
  @override
  State<MuscleExercisesSheet> createState() => _MuscleExercisesSheetState();
}

class _MuscleExercisesSheetState extends State<MuscleExercisesSheet> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String venue = 'home', slotId = '';
  bool initialized = false, optional = false, showHard = false, saving = false;
  Map<String, dynamic>? pick;
  final Map<String, ({String workoutId, String venue})> added = {};

  String dayText(String id) {
    final plan = context.app.plan;
    const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final days = jsonMap(plan['schedule']).entries
        .where((e) => e.value == id)
        .map((e) => wd[int.parse(e.key)])
        .join('、');
    return days.isEmpty
        ? workoutTitle('${jsonMap(jsonMap(plan['workouts'])[id])['name']}')
        : days;
  }

  Future<bool> close() async {
    if (saving) return false;
    if (pick != null) {
      resetScroll();
      setState(() => pick = null);
      return false;
    }
    return true;
  }

  Future<void> confirm(Map<String, dynamic> slot) async {
    if (saving || pick == null) return;
    final app = context.app, exercise = pick!;
    final name = exercise['name'] as String, id = slot['workoutId'] as String;
    setState(() => saving = true);
    try {
      await app.updatePlan(
        addToPlan(
          app.plan,
          id,
          venue,
          jsonMap(exercise['spec']),
          optional: optional,
        ),
      );
      if (!mounted) return;
      resetScroll();
      setState(() {
        added[name] = (workoutId: id, venue: venue);
        pick = null;
      });
      app.toast.show('已加入「$name」· ${dayText(id)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> undo(String name) async {
    if (saving) return;
    final a = added[name];
    if (a == null) return;
    setState(() => saving = true);
    final app = context.app;
    try {
      await app.updatePlan(
        removeFromPlan(app.plan, a.workoutId, a.venue, name),
      );
      if (!mounted) return;
      setState(() => added.remove(name));
      app.toast.show('已撤销');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!initialized) {
      final venues = jsonMap(app.plan['venues']).values;
      venue = venues.contains('gym') && !venues.contains('home')
          ? 'gym'
          : 'home';
      initialized = true;
    }
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = context.pal;
        final status = muscleStatus(
          app.repo.allDays().map((k, v) => MapEntry(k, jsonMap(v))),
          app.clock().millisecondsSinceEpoch,
        );
        final me = jsonMap(jsonMap(status['byMuscle'])[widget.muscleId]);
        final name = MUSCLE[widget.muscleId]!['name'];
        final since = me['daysSince'] as num?;
        final left = jsNumber(me['daysLeft']);
        final sub = since == null
            ? '还没有练到过这块肌肉'
            : me['recovered'] != true
            ? '最近练过，大约还要 ${left < .75 ? '不到 1' : fmt((left * 2).round() / 2)} 天恢复'
            : since >= 14
            ? '已经 ${since >= 70 ? '${(since / 30).round()} 个月' : '${fmt(since)} 天'}没练到了'
            : '${since <= 0 ? '今天' : '${fmt(since)} 天前'}练过，已恢复';
        final all = exercisesForMuscle(widget.muscleId, venue);
        final hasEasy = all.any(
          (e) => e['role'] == 'main' && e['level'] != 'hard',
        );
        final easy = all
            .where(
              (e) => e['level'] != 'hard' || !hasEasy && e['role'] == 'main',
            )
            .toList();
        final hard = all.where((e) => !easy.contains(e)).toList();
        final slots = pick == null
            ? <Map<String, dynamic>>[]
            : recommendSlots(
                app.plan,
                status,
                widget.muscleId,
                venue,
                jsonMap(pick!['spec']),
                app.today,
              );
        final slot =
            slots.where((s) => s['workoutId'] == slotId).firstOrNull ??
            slots.firstOrNull;
        final effect = slot == null
            ? null
            : weeklyEffect(
                app.plan,
                jsonMap(pick!['spec']),
                slot['workoutId'] as String,
              );
        return AppSheet(
          title: pick == null ? '练「$name」' : '加到哪一天',
          cancelLabel: pick == null ? '完成' : '返回',
          confirmClose: close,
          scrollController: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: PushSwitcher(
            direction: pick == null ? -1 : 1,
            child: Column(
              key: ValueKey(pick == null ? 'exercise-list' : 'exercise-pick'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pick == null
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                        child: Text(
                          sub,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.17,
                            color: p.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: p.seg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            for (final (value, label) in [
                              ('home', '居家'),
                              ('gym', '健身房'),
                            ])
                              Expanded(
                                child: button(
                                  label,
                                  () => setState(() => venue = value),
                                  selected: venue == value,
                                  segment: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final e in easy) exerciseRow(e),
                      if (easy.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('这个场地暂时没有合适的动作。', style: AppText.hint(p)),
                        ),
                      if (hard.isNotEmpty) ...[
                        button(
                          '${showHard ? '收起' : '更多'}较难的动作（${hard.length}）',
                          () => setState(() => showHard = !showHard),
                        ),
                        Reveal(
                          visible: showHard,
                          child: Column(
                            children: [for (final e in hard) exerciseRow(e)],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '点动作看示范；点「＋ 加入」选加到哪一天。加入后和其他动作一样，目标次数和升级建议由「今日」页管理，默认每个动作 2 组。',
                        style: AppText.hint(p),
                      ),
                    ]
                  : [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                        child: Row(
                          children: [
                            ExerciseThumb(ex: jsonMap(pick!['spec']), size: 52),
                            const SizedBox(width: 12),
                            Expanded(
                              child: exerciseText(
                                pick!,
                                showTags: false,
                                version: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('加到哪一天', style: AppText.hint(p)),
                      for (final s in slots)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Semantics(
                            button: true,
                            selected: slot == s,
                            label:
                                '${dayText(s['workoutId'] as String)} · ${workoutTitle('${s['name']}')}',
                            child: Pressable(
                              onTap: () => setState(
                                () => slotId = s['workoutId'] as String,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: p.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: slot == s ? p.tint : p.card,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${dayText(s['workoutId'] as String)} · ${workoutTitle('${s['name']}')}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: p.text,
                                            ),
                                          ),
                                        ),
                                        if (s['best'] == true) tag('推荐', true),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${s['why']}', style: AppText.hint(p)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '时长约 ${s['before']} → ${s['after']} 分钟',
                                      style: AppText.hint(p),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (slots.isEmpty)
                        Text(
                          '当前计划里没有排训练日，先在「训练计划与提醒」里安排每周训练。',
                          style: AppText.hint(p),
                        ),
                      if (effect != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                          child: Text(
                            '加入后，${effect['name']}每周直接训练 ${fmt(effect['now'])} → ${fmt(effect['next'])} 组（参考 ${effect['band']['lo']}～${effect['band']['hi']} 组）${jsNumber(effect['next']) > jsNumber(effect['band']['hi']) ? '，已经偏多了，建议换掉一个动作而不是再加。' : '。'}',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: p.secondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Semantics(
                        button: true,
                        toggled: optional,
                        label: '作为可选动作',
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: () => setState(() => optional = !optional),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '作为可选动作',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: p.text,
                                      ),
                                    ),
                                    Text(
                                      '时间不够时可以跳过，不算进今天的目标组数',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 44,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: Duration(
                                      milliseconds:
                                          MediaQuery.disableAnimationsOf(
                                            context,
                                          )
                                          ? 0
                                          : 180,
                                    ),
                                    width: 51,
                                    height: 31,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: optional ? p.ok : p.fill,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      alignment: optional
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 27,
                                        height: 27,
                                        decoration: BoxDecoration(
                                          color: p.onTint,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      button(
                        '加入${slot != null ? '「${workoutTitle('${slot['name']}')}」' : ''}',
                        slot == null || saving ? null : () => confirm(slot),
                        filled: true,
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }

  Widget exerciseRow(Map<String, dynamic> e) {
    final p = context.pal, name = e['name'] as String;
    final inPlan = whereInPlan(
      context.app.plan,
      name,
    ).where((w) => w['venue'] == venue).toList();
    final a = added[name];
    return Opacity(
      opacity: e['level'] == 'hard' ? .8 : 1,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(a),
        tween: Tween(begin: 0, end: a == null ? 0 : 1),
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 900,
        ),
        builder: (context, pulse, child) => Container(
          key: ValueKey('exercise-row-$name'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: BoxDecoration(
            color: Color.lerp(
              p.card,
              p.tintSoft,
              pulse <= 0 || pulse >= 1 ? 0 : math.sin(math.pi * pulse),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '查看$name示范',
                  child: Pressable(
                    onTap: () => openGuide(context, name),
                    child: Row(
                      children: [
                        ExerciseThumb(ex: jsonMap(e['spec']), size: 52),
                        const SizedBox(width: 12),
                        Expanded(child: exerciseText(e)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (a != null)
                SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '已加入 · ${dayText(a.workoutId)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.ok,
                        ),
                      ),
                      button('撤销', saving ? null : () => undo(name)),
                    ],
                  ),
                )
              else if (inPlan.isNotEmpty)
                SizedBox(
                  width: 90,
                  child: Text(
                    '已在计划：${inPlan.map((w) => dayText(w['workoutId'] as String)).toSet().join('、')}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.secondary,
                    ),
                  ),
                )
              else
                Semantics(
                  label: '把$name加入计划',
                  button: true,
                  excludeSemantics: true,
                  child: button(
                    '＋ 加入',
                    () {
                      resetScroll();
                      setState(() {
                        pick = e;
                        slotId = '';
                        optional = false;
                      });
                    },
                    filled: true,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget exerciseText(
    Map<String, dynamic> e, {
    bool showTags = true,
    bool version = false,
  }) {
    final p = context.pal, spec = jsonMap(e['spec']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${e['name']}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -.16,
            color: p.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${prescription({...spec, 'target': spec['sets']})}${jsNumber(spec['weight']) != 0 ? ' · ${fmt(spec['weight'])} kg' : ''}${version ? '　·　${venue == 'gym' ? '健身房版' : '居家版'}' : ''}',
          style: AppText.hint(p),
        ),
        if (showTags)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                tag(
                  e['role'] == 'main'
                      ? '主练'
                      : '辅助 ${(jsNumber(e['weight']) * 100).round()}%',
                  e['role'] == 'main',
                ),
                if (e['level'] == 'easy') tag('好上手', false),
                if (e['level'] == 'hard') tag('较难', false),
              ],
            ),
          ),
      ],
    );
  }

  Widget tag(String label, bool active) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: p.fill2,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.secondary,
        ),
      ),
    );
  }

  Widget button(
    String label,
    VoidCallback? action, {
    bool filled = false,
    bool compact = false,
    bool selected = false,
    bool segment = false,
  }) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: label,
      selected: segment ? selected : null,
      enabled: action != null,
      child: Pressable(
        onTap: action,
        child: Opacity(
          opacity: action == null ? .45 : 1,
          child: Container(
            constraints: BoxConstraints(
              minHeight: filled && !compact ? 52 : 44,
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
            decoration: BoxDecoration(
              color: filled
                  ? compact
                        ? p.fill2
                        : p.tint
                  : segment && selected
                  ? p.segOn
                  : null,
              borderRadius: BorderRadius.circular(
                compact
                    ? 99
                    : segment
                    ? 9
                    : 16,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: filled && !compact ? 17 : 15,
                fontWeight: FontWeight.w600,
                color: filled
                    ? compact
                          ? p.text
                          : p.onTint
                    : segment
                    ? p.text
                    : p.tint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
