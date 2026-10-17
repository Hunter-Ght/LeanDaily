import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart' as f;
import '../../domain/records.dart' as records;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart';
import '../kit/menu.dart';
import '../kit/photo_image.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'set_display.dart';

/// 训练 | 饮食 切换条：固定在日历下方、列表上方，长长的训练也不用往下滑找饮食。
/// 各带一个数量，一眼知道这天记了多少。
class DaySectionSwitch extends StatelessWidget {
  const DaySectionSwitch({
    super.key,
    required this.train,
    required this.sets,
    required this.meals,
    required this.onSection,
  });
  final bool train;
  final int sets, meals;
  final ValueChanged<String> onSection;

  @override
  Widget build(BuildContext c) {
    final p = c.pal;
    Widget cell(String label, int count, bool on) => Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: AppMessages.of(c).text(label),
        child: Pressable(
          onTap: on ? null : () => onSection(label),
          scale: 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.segOn : null,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: LText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? p.tint : p.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      key: const ValueKey('day-section-switch'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.seg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [cell('训练', sets, train), cell('饮食', meals, !train)],
        ),
      ),
    );
  }
}

/// Repository projections for a single date, also used by the adjacent pager panes.
class DayCards extends StatelessWidget {
  const DayCards({
    super.key,
    required this.iso,
    this.columns = false,
    this.scrollController,
    this.bottomPadding = 78,
    this.lastAdd = const [],
    this.shown = '训练',
  });

  /// 竖屏下一次只看一块：'训练' 或 '饮食'（切换条在列表上方，见 [DaySectionSwitch]）。
  final String shown;
  final String iso;
  final bool columns;
  final ScrollController? scrollController;
  final double bottomPadding;
  final List<Map<String, dynamic>> lastAdd;

  @override
  Widget build(BuildContext context) {
    final day = context.app.repo.day(iso);
    final groups = f.groupSets(day['sets'] as List?);
    final meals = f.jsonRows(context.app.repo.meals(iso)['meals']);
    if (!columns) return lazyList(context, day, groups, meals);
    final train = section(context, '训练', [
      if (f.userNote(day).isNotEmpty) ...[
        LText('备注', style: AppText.hint(context.pal)),
        card(
          context,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(f.userNote(day)),
          ),
        ),
      ],
      if (groups.isEmpty)
        empty(context, '这天还没练', '记一组', () => openTrainSheet(context)),
      if (lastAdd.isNotEmpty) banner(context),
      for (final group in groups)
        training(
          context,
          '${group[0]}',
          f.jsonRows(group[1]),
          day,
          firstCard:
              identical(group, groups.first) &&
              f.userNote(day).isEmpty &&
              lastAdd.isEmpty,
        ),
      if (groups.isNotEmpty)
        action(
          context,
          '记另一个动作',
          () => openTrainSheet(context),
          centered: true,
        ),
    ]);
    final meal = section(context, '饮食', [
      if (meals.isEmpty)
        empty(
          context,
          '这天还没记饮食',
          '记饮食',
          () => openQuickFood(context, date: iso),
        ),
      for (final m in meals)
        mealCard(context, m, firstCard: identical(m, meals.first)),
      if (meals.isNotEmpty)
        action(
          context,
          '记饮食',
          () => openQuickFood(context, date: iso),
          centered: true,
        ),
    ]);
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.only(top: 12, bottom: bottomPadding),
      physics: const ClampingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: train),
          Expanded(child: meal),
        ],
      ),
    );
  }

  Widget lazyList(
    BuildContext c,
    Map<String, dynamic> day,
    List<List<dynamic>> groups,
    List<Map<String, dynamic>> meals,
  ) {
    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
    final showTrain = shown != '饮食';
    final builders = <({Key key, WidgetBuilder builder})>[
      if (showTrain) ...[
        if (lastAdd.isNotEmpty)
          (key: const ValueKey('last-add'), builder: (_) => padded(banner(c))),
        if (f.userNote(day).isNotEmpty)
          (
            key: const ValueKey('note'),
            builder: (_) => padded(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LText('备注', style: AppText.hint(c.pal)),
                  card(
                    c,
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(f.userNote(day)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (groups.isEmpty)
          (
            key: const ValueKey('empty-train'),
            builder: (_) =>
                padded(empty(c, '这天还没练', '记一组', () => openTrainSheet(c))),
          ),
        for (final group in groups)
          (
            key: ValueKey('exercise-${group[0]}'),
            builder: (_) => padded(
              training(
                c,
                '${group[0]}',
                f.jsonRows(group[1]),
                day,
                firstCard:
                    identical(group, groups.first) &&
                    f.userNote(day).isEmpty &&
                    lastAdd.isEmpty,
              ),
            ),
          ),
        if (groups.isNotEmpty)
          (
            key: const ValueKey('add-train'),
            builder: (_) => padded(
              action(c, '记另一个动作', () => openTrainSheet(c), centered: true),
            ),
          ),
      ] else ...[
        if (meals.isEmpty)
          (
            key: const ValueKey('empty-meal'),
            builder: (_) => padded(
              empty(c, '这天还没记饮食', '记饮食', () => openQuickFood(c, date: iso)),
            ),
          ),
        for (final meal in meals)
          (
            key: ValueKey('meal-${meal['record_id']}'),
            builder: (_) => padded(
              mealCard(c, meal, firstCard: identical(meal, meals.first)),
            ),
          ),
        if (meals.isNotEmpty)
          (
            key: const ValueKey('add-meal'),
            builder: (_) => padded(
              action(
                c,
                '记饮食',
                () => openQuickFood(c, date: iso),
                centered: true,
              ),
            ),
          ),
      ],
    ];
    return MotionLazyList(
      key: ValueKey('log-list-$iso'),
      controller: scrollController,
      padding: EdgeInsets.only(top: 12, bottom: bottomPadding),
      items: builders,
    );
  }

  Widget banner(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
        tap(
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

  Widget section(BuildContext c, String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
        child: LText(
          title,
          key: ValueKey('section-$iso-$title'),
          style: AppText.sect(c.pal),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: MotionList(
          children: [
            for (final (i, child) in children.indexed)
              KeyedSubtree(key: child.key ?? ValueKey('slot-$i'), child: child),
          ],
        ),
      ),
    ],
  );
  Widget card(BuildContext c, Widget child, {bool first = false, Key? key}) =>
      Container(
        key: key,
        margin: EdgeInsets.only(top: first ? 0 : 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: c.pal.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );
  Widget tap(BuildContext c, String label, VoidCallback onTap, Widget child) =>
      Semantics(
        button: true,
        excludeSemantics: true,
        label: AppMessages.of(c).text(label),
        child: Pressable(onTap: onTap, child: child),
      );
  Widget empty(
    BuildContext c,
    String title,
    String label,
    VoidCallback onTap,
  ) => card(
    c,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: LText(
              title,
              style: AppText.hint(c.pal).copyWith(fontSize: 15),
            ),
          ),
          tap(
            c,
            label,
            onTap,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: LText(
                label,
                style: AppText.navWeek(c.pal).copyWith(color: c.pal.tint),
              ),
            ),
          ),
        ],
      ),
    ),
    first: true,
  );
  Widget action(
    BuildContext c,
    String label,
    VoidCallback onTap, {
    bool centered = false,
  }) {
    final button = tap(
      c,
      label,
      onTap,
      Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.center,
          children: [
            AppIcon('plus', size: 16, color: c.pal.tint),
            const SizedBox(width: 6),
            Flexible(
              child: LText(
                label,
                textAlign: TextAlign.center,
                style: AppText.body(c.pal).copyWith(color: c.pal.tint),
              ),
            ),
          ],
        ),
      ),
    );
    return centered ? card(c, button) : button;
  }

  Widget meta(BuildContext c, String text, {int? maxLines}) => LText(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: c.pal.secondary,
    ),
  );
  Widget tag(BuildContext c, String text) {
    final p = c.pal;
    final dark = p.bg.computeLuminance() < 0.1;
    final warm = ToneBadge.tone(p, 'sun', dark);
    final drop = ToneBadge.tone(p, 'back', dark);
    final fg = switch (text) {
      '单边' => p.secondary,
      '热身' => warm.fg,
      '递减' => drop.fg,
      '疼痛' => p.err,
      _ => p.secondary,
    };
    final bg = switch (text) {
      '单边' => p.tintSoft,
      '热身' => warm.bg,
      '递减' => drop.bg,
      '疼痛' => p.err.withValues(alpha: 0.12),
      _ => p.fill,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LText(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget line(BuildContext c, Widget child, {double inset = 28}) => Column(
    children: [
      Padding(
        padding: EdgeInsets.only(left: inset),
        child: Container(height: 0.5, color: c.pal.sep),
      ),
      child,
    ],
  );
  Widget trash(BuildContext c, String label, VoidCallback onTap) => tap(
    c,
    label,
    onTap,
    SizedBox.square(
      dimension: 44,
      child: Center(child: AppIcon('trash', size: 18, color: c.pal.secondary)),
    ),
  );

  Future<void> deleteSet(BuildContext c, Map<String, dynamic> s) async {
    final app = c.app;
    if (!await showConfirm(
      c,
      title: '${s['ex']} · 第 ${s['no']} 组',
      message: setDisplay(s),
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

  Widget freshRow(BuildContext c, Map<String, dynamic> set, Widget child) =>
      TweenAnimationBuilder<double>(
        key: ValueKey('fresh-${set['id']}'),
        tween: Tween(
          begin: lastAdd.any((s) => s['id'] == set['id']) ? 0.28 : 0,
          end: 0,
        ),
        duration: const Duration(milliseconds: 1100),
        builder: (_, alpha, child) => ColoredBox(
          color: c.pal.ok.withValues(alpha: alpha),
          child: child,
        ),
        child: child,
      );

  Widget training(
    BuildContext c,
    String exercise,
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> day, {
    bool firstCard = false,
  }) {
    final first = sets.first, last = sets.last;
    final vol = f.workVolume(sets);
    final e1 = f.jsonMap(f.jsonMap(day['totals'])['best_e1rm'])[exercise];
    return card(
      c,
      key: ValueKey('exercise-$exercise'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: Row(
              children: [
                ToneBadge.part('${first['part']}'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        exercise,
                        style: AppText.sect(c.pal).copyWith(height: 1.2),
                      ),
                      const SizedBox(height: 3),
                      meta(
                        c,
                        [
                          '${first['part']}',
                          if (vol != 0) '${f.fmt(vol)} kg',
                          if (f.jsTruthy(e1)) 'e1RM ${f.fmt(e1)}',
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          MotionList(
            children: [
              for (final s in sets)
                KeyedSubtree(
                  key: ValueKey(s['id']),
                  child: line(
                    c,
                    freshRow(
                      c,
                      s,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: tap(
                                c,
                                '修改 ${s['ex']} 第 ${s['no']} 组',
                                () => openEditSet(c, s),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 44,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 22,
                                        child: LText(
                                          '${s['no']}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: c.pal.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            LText(
                                              setDisplay(s),
                                              style: AppText.body(c.pal).copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                            if (setEffortLabel(s['rpe'])
                                                .isNotEmpty)
                                              meta(c, setEffortLabel(s['rpe'])),
                                            if (s['type'] != '正式')
                                              tag(c, '${s['type']}'),
                                            if ('${s['notes']}'.contains('单边'))
                                              tag(c, '单边'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            tap(
                              c,
                              '这组的更多操作',
                              () => deleteSet(c, s),
                              SizedBox.square(
                                dimension: 44,
                                child: Center(
                                  child: AppIcon(
                                    'more',
                                    size: 18,
                                    color: c.pal.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          line(
            c,
            action(
              c,
              '再记一组',
              () => openTrainSheet(
                c,
                preset: {
                  'part': first['part'],
                  'exercise': exercise,
                  'uni': sets.any((s) => '${s['notes']}'.contains('单边')),
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
            ),
            inset: 16,
          ),
        ],
      ),
      first: firstCard,
    );
  }

  Widget mealCard(
    BuildContext c,
    Map<String, dynamic> m, {
    bool firstCard = false,
  }) {
    final paths = m['photo_ids'] as List? ?? m['local_photos'] as List? ?? [];
    final items = f.jsonRows(m['items']);
    return card(
      c,
      key: ValueKey('meal-${m['record_id']}'),
      Column(
        children: [
          tap(
            c,
            '编辑${m['meal']}',
            () => openMealSheet(c, preset: {...m, 'editId': m['record_id']}),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(
                children: [
                  if (paths.isNotEmpty)
                    PhotoImage(
                      path: '${paths.first}',
                      width: 44,
                      height: 44,
                      radius: 12,
                    )
                  else
                    ToneBadge(icon: mealIcon('${m['meal']}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LText('${m['meal']}', style: AppText.sect(c.pal)),
                            if ('${m['time'] ?? ''}'.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    'clock',
                                    size: 13,
                                    color: c.pal.secondary,
                                  ),
                                  const SizedBox(width: 3),
                                  meta(c, '${m['time']}'),
                                ],
                              ),
                          ],
                        ),
                        meta(
                          c,
                          items.isEmpty
                              ? '还没有食物明细'
                              : items
                                    .map(
                                      (i) =>
                                          '${i['name']}${f.jsTruthy(i['portion']) ? ' ${i['portion']}' : ''}',
                                    )
                                    .join('、'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  AppIcon('right', size: 16, color: c.pal.tertiary),
                ],
              ),
            ),
          ),
          line(
            c,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (m['source'] == '待分析' && !f.jsTruthy(m['kcal'])) ...[
                          tag(c, '待分析'),
                          if (paths.isNotEmpty)
                            Pressable(
                              onTap: () => openMealSheet(
                                c,
                                preset: {...m, 'editId': m['record_id']},
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Center(
                                  widthFactor: 1,
                                  child: LText(
                                    'AI识别 ›',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: c.pal.tint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ] else ...[
                          LText(
                            '${f.jsNumber(m['kcal']).round()} kcal',
                            style: AppText.body(c.pal)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          meta(
                            c,
                            '蛋白 ${f.fmt(m['protein'])} · 碳水 ${f.fmt(m['carbs'])} · 脂肪 ${f.fmt(m['fat'])}',
                          ),
                        ],
                        if (f.jsNumber(m['photos']) > 0)
                          meta(c, '· ${m['photos']} 张'),
                        if (records.needsAfterPhoto(m)) tag(c, '待补吃完后照片'),
                      ],
                    ),
                  ),
                  trash(c, '删除这条饮食', () async {
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
                  }),
                ],
              ),
            ),
            inset: 16,
          ),
        ],
      ),
      first: firstCard,
    );
  }
}
