import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart' as f;
import '../../domain/movements.dart' show musclesOf;
import '../../domain/records.dart' as records;
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart';
import '../kit/body_figure.dart';
import '../kit/exercise_thumb.dart';
import '../kit/menu.dart';
import '../kit/photo_image.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import '../sheets/train/controls.dart' show SheetButton;
import 'set_display.dart';
import '../kit/units_scope.dart';

/// 一天的记录：当天小结 + 按时间排序的时间线（训练块与饮食块混排）。
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.iso,
    this.scrollController,
    this.bottomPadding = 78,
    this.lastAdd = const [],
  });

  final String iso;
  final ScrollController? scrollController;
  final double bottomPadding;
  final List<Map<String, dynamic>> lastAdd;

  static const _mealMinutes = {'早餐': 450, '午餐': 720, '晚餐': 1110, '加餐': 900};

  static int _clock(String? hhmm, String meal) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm ?? '');
    if (m != null) return int.parse(m[1]!) * 60 + int.parse(m[2]!);
    return _mealMinutes[meal] ?? 720;
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final day = app.repo.day(iso);
    final sets = f.jsonRows(day['sets']);
    final groups = f.groupSets(sets);
    final meals = f.jsonRows(app.repo.meals(iso)['meals']);
    final p = context.pal;

    // 训练块：用组的时间戳定位，整次训练一块。
    String? trainTime;
    int trainMinute = 0;
    if (groups.isNotEmpty) {
      final stamps = [
        for (final s in sets)
          if (s['ts'] is num) (s['ts'] as num).toInt(),
      ]..sort();
      if (stamps.isEmpty) {
        trainMinute = 18 * 60;
      } else {
        final a = DateTime.fromMillisecondsSinceEpoch(stamps.first);
        final b = DateTime.fromMillisecondsSinceEpoch(stamps.last);
        trainMinute = a.hour * 60 + a.minute;
        trainTime = _hm(a);
        final span = stamps.last - stamps.first;
        if (span >= 60000 && span < 6 * 3600000) {
          trainTime = '${_hm(a)} – ${_hm(b)}';
        }
      }
    }
    final minutes = _trainMinutes(sets);

    final items =
        <({int minute, int order, Key key, _Row row})>[
          if (groups.isNotEmpty)
            (
              minute: trainMinute,
              order: 1,
              key: const ValueKey('train-block'),
              row: _Row(
                dot: p.tint,
                time: trainTime ?? '',
                child: (c) => _TrainingCard(
                  iso: iso,
                  groups: groups,
                  sets: sets,
                  minutes: minutes,
                ),
              ),
            ),
          for (final m in meals)
            (
              minute: _clock('${m['time'] ?? ''}', '${m['meal']}'),
              order: 0,
              key: ValueKey('meal-${m['record_id']}'),
              row: _Row(
                dot: p.protein,
                time: '${m['time'] ?? ''}',
                child: (c) => _MealCard(iso: iso, meal: m),
              ),
            ),
        ]..sort(
          (a, b) => a.minute != b.minute
              ? a.minute.compareTo(b.minute)
              : a.order.compareTo(b.order),
        );

    final builders = <({Key key, WidgetBuilder builder})>[
      (
        key: const ValueKey('day-summary'),
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _Summary(sets: sets, meals: meals),
        ),
      ),
      if (lastAdd.isNotEmpty)
        (
          key: const ValueKey('last-add'),
          builder: (c) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _Banner(iso: iso, lastAdd: lastAdd),
          ),
        ),
      if (f.userNote(day).isNotEmpty)
        (
          key: const ValueKey('note'),
          builder: (c) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText('备注', style: AppText.hint(c.pal)),
                const SizedBox(height: 2),
                Text(f.userNote(day), style: AppText.body(c.pal)),
              ],
            ),
          ),
        ),
      if (items.isEmpty)
        (
          key: const ValueKey('empty-day'),
          builder: (c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Empty(iso: iso),
          ),
        ),
      for (final (i, e) in items.indexed)
        (
          key: e.key,
          builder: (c) => Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: _Rail(
              first: i == 0,
              last: i == items.length - 1,
              dot: e.row.dot,
              time: e.row.time,
              child: e.row.child(c),
            ),
          ),
        ),
    ];
    return MotionLazyList(
      key: ValueKey('log-list-$iso'),
      controller: scrollController,
      padding: EdgeInsets.only(top: 4, bottom: bottomPadding),
      items: builders,
    );
  }

  /// 训练用时（分钟）：首末组时间戳之差，过短或过长（补记）不显示。
  static int _trainMinutes(List<Map<String, dynamic>> sets) {
    final stamps = [
      for (final s in sets)
        if (s['ts'] is num) (s['ts'] as num).toInt(),
    ]..sort();
    if (stamps.length < 2) return 0;
    final span = stamps.last - stamps.first;
    return span >= 60000 && span < 6 * 3600000 ? (span / 60000).round() : 0;
  }
}

class _Row {
  const _Row({required this.dot, required this.time, required this.child});
  final Color dot;
  final String time;
  final Widget Function(BuildContext) child;
}

/// 时间线左侧的竖线、圆点和时间。
class _Rail extends StatelessWidget {
  const _Rail({
    required this.first,
    required this.last,
    required this.dot,
    required this.time,
    required this.child,
  });
  final bool first, last;
  final Color dot;
  final String time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      children: [
        Positioned(
          left: 5,
          top: first ? 12 : 0,
          bottom: last ? null : 0,
          height: last ? 14 : null,
          width: 2,
          child: ColoredBox(color: p.sep),
        ),
        Positioned(
          left: 0,
          top: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: p.bg,
              shape: BoxShape.circle,
              border: Border.all(color: dot, width: 2.5),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 28, bottom: last ? 0 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 16,
                child: Text(
                  time,
                  style: AppText.num(
                    p,
                    14,
                    weight: FontWeight.w600,
                    color: p.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

Widget _card(BuildContext c, Widget child, {Key? key}) => Container(
  key: key,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    color: c.pal.card,
    borderRadius: BorderRadius.circular(22),
  ),
  child: child,
);

Widget _tap(BuildContext c, String label, VoidCallback onTap, Widget child) =>
    Semantics(
      button: true,
      excludeSemantics: true,
      label: AppMessages.of(c).text(label),
      child: Pressable(onTap: onTap, child: child),
    );

/// 数字 + 小号单位。
Widget _stat(
  BuildContext c,
  String value,
  String unit, {
  Color? color,
  double size = 17,
}) {
  final p = c.pal;
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(value, style: AppText.num(p, size, color: color)),
      const SizedBox(width: 3),
      LText(unit, style: AppText.hint(p).copyWith(height: 1)),
    ],
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.sets, required this.meals});
  final List<Map<String, dynamic>> sets, meals;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, app = context.app;
    final work = sets.where((s) => s['type'] != '热身').length;
    num sum(String k) =>
        meals.fold<num>(0, (v, m) => v + f.jsNumber(m[k]).toDouble());
    final protein = sum('protein'), kcal = sum('kcal');
    // 窄屏（320 宽）也不折行：数字和“/ 目标”在同一行按需缩小，名称单独一行。
    Widget tile(String value, String suffix, Color color, String label) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: AppText.num(p, 28, color: color),
                        ),
                        if (suffix.isNotEmpty)
                          TextSpan(
                            text: suffix,
                            style: AppText.num(
                              p,
                              15,
                              weight: FontWeight.w600,
                              color: p.secondary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 6),
                LText(label, maxLines: 1, style: AppText.hint(p)),
              ],
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        key: const ValueKey('day-summary-row'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile('$work', '', p.tint, '组 · 训练'),
          const SizedBox(width: 8),
          tile(
            f.fmt(protein.round()),
            ' / ${f.fmt(app.proteinGoal)} g',
            p.protein,
            '蛋白',
          ),
          const SizedBox(width: 8),
          tile(f.fmt(kcal.round()), ' / ${f.fmt(app.kcalGoal)}', p.kcal, '千卡'),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.iso});
  final String iso;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, app = context.app;
    final today = iso == app.today, future = iso.compareTo(app.today) > 0;
    // 未来的日子还没有可记的：只说明一句，不引导补记。
    final message = today
        ? '今天练了吗？记一组或记一餐'
        : future
        ? '这天还没到'
        : '这天没有记录，可以补记';
    // 矮屏（320×640 一类）缩小人体图，让两个入口不必滚动就能看到。
    final short = MediaQuery.sizeOf(context).height < 700;
    final figureHeight = short ? 76.0 : 110.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, short ? 8 : 24, 8, 28),
      child: Column(
        children: [
          // 全中性的人体：还没有任何发力部位。
          SizedBox(
            width: figureHeight * 1.2,
            height: figureHeight,
            child: BodyFigure(height: figureHeight),
          ),
          SizedBox(height: short ? 8 : 14),
          LText(
            message,
            textAlign: TextAlign.center,
            style: AppText.body(p).copyWith(fontSize: 16, height: 1.4),
          ),
          if (!future) ...[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SheetButton(
                        '记一组',
                        () => openTrainSheet(context),
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SheetButton(
                        '记饮食',
                        () => openQuickFood(context, date: iso),
                        soft: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.iso, required this.lastAdd});
  final String iso;
  final List<Map<String, dynamic>> lastAdd;

  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
    decoration: BoxDecoration(
      color: c.pal.tintSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        AppIcon('check', size: 18, color: c.pal.tint),
        const SizedBox(width: 8),
        Expanded(
          child: LText(
            '已保存 ${lastAdd.first['ex']} ${lastAdd.length} 组',
            style: AppText.hint(c.pal).copyWith(fontSize: 15),
          ),
        ),
        _tap(
          c,
          '撤销',
          () async {
            final app = c.app;
            if (!await showConfirm(
              c,
              title: '撤销刚保存的 ${lastAdd.first['ex']} ${lastAdd.length} 组？',
              confirm: '撤销',
              danger: true,
            )) {
              return;
            }
            try {
              await app.repo.deleteSets(iso, [
                for (final s in lastAdd) '${s['id']}',
              ]);
              app.toast.show('已撤销');
            } on Object catch (e) {
              app.toast.show(AppController.message(e));
            }
          },
          SizedBox(
            height: 44,
            child: Center(
              child: LText(
                '撤销',
                style: AppText.body(c.pal).copyWith(color: c.pal.tint),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ 训练块

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({
    required this.iso,
    required this.groups,
    required this.sets,
    required this.minutes,
  });
  final String iso;
  final List<List<dynamic>> groups;
  final List<Map<String, dynamic>> sets;
  final int minutes;

  /// 当天练到的肌肉：主练 effort、辅助 assist。热身组不算。
  Map<String, MuscleTone> tones() {
    final out = <String, MuscleTone>{};
    for (final s in sets) {
      if (s['type'] == '热身') continue;
      final m = musclesOf(s['ex'], '${s['part'] ?? ''}');
      final map = m?['muscles'] as Map?;
      if (map == null) continue;
      for (final e in map.entries) {
        final tone = (e.value as num) >= .6
            ? MuscleTone.effort
            : MuscleTone.assist;
        final id = '${e.key}';
        if (out[id] != MuscleTone.effort) out[id] = tone;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final parts = <String>[];
    for (final g in groups) {
      final part = '${f.jsonRows(g[1]).first['part']}';
      if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
    }
    final work = sets.where((s) => s['type'] != '热身').length;
    return _card(
      context,
      key: const ValueKey('training-card'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 人体图放大到看得清练了哪里：两面各占约 0.6 倍高度的宽度，比例不被压扁。
            LayoutBuilder(
              builder: (context, box) {
                final figureHeight = box.maxWidth >= 300 ? 112.0 : 92.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final (i, part) in parts.indexed) ...[
                                if (i > 0) Text('·', style: AppText.title(p)),
                                LText(part, style: AppText.title(p)),
                              ],
                              LText('训练', style: AppText.title(p)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _stat(
                                context,
                                '${groups.length}',
                                '个动作',
                                size: 16,
                              ),
                              _stat(context, '$work', '组', size: 16),
                              if (minutes > 0)
                                _stat(context, '$minutes', '分钟', size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 垫一块页面底色的圆角底：白卡上中性的肌肉才看得出轮廓，发力部位更突出。
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox(
                        width: figureHeight * 1.2,
                        height: figureHeight,
                        child: BodyFigure(height: figureHeight, tones: tones()),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            MotionList(
              children: [
                for (final g in groups)
                  KeyedSubtree(
                    key: ValueKey('exercise-${g[0]}'),
                    child: _ExerciseRow(
                      iso: iso,
                      exercise: '${g[0]}',
                      sets: f.jsonRows(g[1]),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.iso,
    required this.exercise,
    required this.sets,
  });
  final String iso, exercise;
  final List<Map<String, dynamic>> sets;

  Future<void> _more(BuildContext c, Map<String, dynamic> s) async {
    final feedback = setFeedbackLabel(s);
    final picked = await showActionMenu(
      c,
      title: '${s['ex']} · 第 ${s['no']} 组',
      message: [
        setDisplay(s, c.units),
        if (feedback.isNotEmpty) feedback,
      ].join('\n'),
      actions: const [
        MenuAction(id: 'edit', label: '修改这组', icon: 'edit'),
        MenuAction(id: 'delete', label: '删除这组', icon: 'trash', danger: true),
      ],
    );
    if (!c.mounted) return;
    switch (picked?.id) {
      case 'edit':
        openEditSet(c, s);
      case 'delete':
        await _delete(c, s);
    }
  }

  Future<void> _delete(BuildContext c, Map<String, dynamic> s) async {
    final app = c.app;
    if (!await showConfirm(
      c,
      title: '${s['ex']} · 第 ${s['no']} 组',
      message: setDisplay(s, c.units),
      confirm: '删除',
      danger: true,
    )) {
      return;
    }
    try {
      await app.repo.deleteSets(iso, ['${s['id']}']);
      app.toast.show(
        '已删除这组',
        duration: const Duration(seconds: 6),
        actionLabel: '撤销',
        onAction: () async {
          app.toast.dismiss();
          try {
            await app.repo.restoreSets(iso, ['${s['id']}']);
            app.toast.show('已恢复');
          } on Object catch (e) {
            app.toast.show(AppController.message(e));
          }
        },
      );
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
    }
  }

  Widget _chip(BuildContext c, Map<String, dynamic> s) {
    final p = c.pal;
    final warm = s['type'] == '热身';
    final fg = warm ? p.secondary : p.text;
    final style = AppText.num(p, 15, color: fg);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: AppMessages.of(c).text('修改 ${s['ex']} 第 ${s['no']} 组'),
      child: Pressable(
        onTap: () => _more(c, s),
        child: Container(
          key: ValueKey('set-${s['id']}'),
          constraints: const BoxConstraints(minHeight: 36, minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: warm ? null : p.fill2,
            border: warm ? Border.all(color: p.sep) : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (setChipWeight(s, c.units) == '自重')
                  LText(
                    '自重',
                    style: AppText.hint(p).copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  )
                else
                  Text(setChipWeight(s, c.units), style: style),
                Text('×', style: style.copyWith(color: p.secondary)),
                Text(f.fmt(s['reps']), style: style),
                if (s['type'] == '递减')
                  Text(' ↓', style: style.copyWith(color: p.secondary)),
                if (s['flag'] == 'pain') ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.err,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = c.pal;
    final first = sets.first, last = sets.last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseThumb(
            ex: {'name': exercise, 'part': first['part']},
            size: 46,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                LText(
                  exercise,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(p).copyWith(
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in sets) _chip(c, s),
                    _tap(
                      c,
                      '再记一组',
                      () => openTrainSheet(
                        c,
                        preset: {
                          'part': first['part'],
                          'exercise': exercise,
                          'uni': sets.any(
                            (s) => '${s['notes']}'.contains('单边'),
                          ),
                          'rows': [
                            {
                              'weight': last['w'],
                              'reps': last['reps'],
                              'rpe': last['rpe'] ?? '',
                              'type': last['type'] ?? '正式',
                            },
                          ],
                        },
                      ),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 36,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: p.sep),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: AppIcon('plus', size: 16, color: p.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 饮食块

class _MealCard extends StatelessWidget {
  const _MealCard({required this.iso, required this.meal});
  final String iso;
  final Map<String, dynamic> meal;

  Widget _tag(BuildContext c, String text) {
    final p = c.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.fill2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LText(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.secondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final p = c.pal, m = meal;
    final paths = m['photo_ids'] as List? ?? m['local_photos'] as List? ?? [];
    final items = f.jsonRows(m['items']);
    final analyzing = m['source'] == '待分析' && !f.jsTruthy(m['kcal']);
    void edit() => openMealSheet(c, preset: {...m, 'editId': m['record_id']});
    return _card(
      c,
      key: ValueKey('meal-card-${m['record_id']}'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tap(
                    c,
                    '编辑${m['meal']}',
                    edit,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (paths.isNotEmpty)
                          PhotoImage(
                            path: '${paths.first}',
                            width: 52,
                            height: 52,
                            radius: 14,
                          )
                        else
                          ToneBadge(icon: mealIcon('${m['meal']}'), size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LText('${m['meal']}', style: AppText.title(p)),
                              const SizedBox(height: 4),
                              LText(
                                items.isEmpty
                                    ? '还没有食物明细'
                                    : items
                                          .map(
                                            (i) =>
                                                '${i['name']}${f.jsTruthy(i['portion']) ? ' ${i['portion']}' : ''}',
                                          )
                                          .join('、'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.hint(p).copyWith(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _tap(
                  c,
                  '删除这条饮食',
                  () async {
                    final app = c.app;
                    if (!await showConfirm(
                      c,
                      title: '删除这条${m['meal']}？',
                      confirm: '删除',
                      danger: true,
                    )) {
                      return;
                    }
                    try {
                      await app.repo.deleteMeal(iso, '${m['record_id']}');
                      app.toast.show('已删除');
                    } on Object catch (e) {
                      app.toast.show(AppController.message(e));
                    }
                  },
                  SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: AppIcon('trash', size: 18, color: p.tertiary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (analyzing) ...[
                    _tag(c, '待分析'),
                    if (paths.isNotEmpty)
                      Pressable(
                        onTap: edit,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Center(
                            widthFactor: 1,
                            child: LText(
                              'AI识别 ›',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    _stat(
                      c,
                      '${f.jsNumber(m['kcal']).round()}',
                      '千卡',
                      color: p.kcal,
                    ),
                    _stat(c, f.fmt(m['protein']), '蛋白', color: p.protein),
                    _stat(c, f.fmt(m['carbs']), '碳水'),
                    _stat(c, f.fmt(m['fat']), '脂肪'),
                  ],
                  if (records.needsAfterPhoto(m)) ...[
                    _tap(
                      c,
                      '我吃光了',
                      () async {
                        final app = c.app;
                        try {
                          await app.repo.finishMeal(iso, '${m['record_id']}');
                          app.haptics.saved();
                          app.toast.show('已标记吃光了');
                        } on Object catch (e) {
                          app.toast.show(AppController.message(e));
                        }
                      },
                      SizedBox(
                        height: 44,
                        child: Center(
                          widthFactor: 1,
                          child: LText(
                            '我吃光了',
                            style: AppText.body(p)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    _tap(
                      c,
                      '补拍剩余',
                      () => openMealSheet(
                        c,
                        preset: {...m, 'date': iso, 'editId': m['record_id']},
                      ),
                      SizedBox(
                        height: 44,
                        child: Center(
                          widthFactor: 1,
                          child: LText(
                            '补拍剩余',
                            style: AppText.body(p)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
