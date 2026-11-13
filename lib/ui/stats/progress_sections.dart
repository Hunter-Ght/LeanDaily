import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:leandaily/l10n/app_messages.dart';

import '../../domain/calendar.dart' as calendar;
import '../../domain/format.dart';
import '../../domain/equipment.dart' show partOfExercise;
import '../../domain/free_training.dart';
import '../../domain/movements.dart' show GROUP, MUSCLE, MUSCLES, musclesOf;
import '../../domain/muscles.dart' show workSets;
import '../../domain/stats_range.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/body_figure.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import '../stats/muscle/body_map.dart';
import '../../domain/muscle_brief.dart';
import 'muscle_brief_panel.dart';

/// 进度页的数据投影：只在记录变化或切换时间范围时重算一次。
class ProgressSummary {
  ProgressSummary._(
    this.range,
    this.window,
    this.heat,
    this.groupSets,
    this.trainDays,
    this.streak,
    this.setsByDate,
    this.today,
  );

  final StatsRange range;
  final RangeWindow window;

  /// 肌肉 id -> 0~1，所选范围内有效组数归一化。
  final Map<String, double> heat;

  /// 肌群 id -> 所选范围内的正式组数。
  final Map<String, int> groupSets;
  final int trainDays;
  final int streak;
  final Map<String, int> setsByDate;
  final String today;

  factory ProgressSummary.build(
    Map<String, Map<String, dynamic>> days,
    String today, [
    StatsRange range = StatsRange.weeks4,
  ]) {
    final sets = workSets(days);
    String? first;
    for (final s in sets) {
      final date = s['date'] as String;
      if (first == null || date.compareTo(first) < 0) first = date;
    }
    final window = rangeWindow(range, today, firstDate: first);
    final raw = <String, double>{};
    final groupSets = <String, int>{};
    final byDate = <String, int>{};
    for (final s in sets) {
      final date = s['date'] as String;
      byDate[date] = (byDate[date] ?? 0) + 1;
      if (!window.contains(date)) continue;
      final mv = musclesOf(s['ex'], s['part'] as String?);
      if (mv == null) continue;
      final group = mv['group'] as String?;
      if (group != null) groupSets[group] = (groupSets[group] ?? 0) + 1;
      for (final e in (mv['muscles'] as Map<String, num>).entries) {
        raw[e.key] = (raw[e.key] ?? 0) + e.value.toDouble();
      }
    }
    final top = raw.values.fold<double>(0, math.max);
    // 数据很少时不要把 1 组也染成满色：分母至少每 4 周 12 组。
    final scale = math.max(top, 3.0 * window.weeks);
    final heat = {for (final e in raw.entries) e.key: e.value / scale};
    var count = 0;
    for (var i = 0; i < window.days; i++) {
      if (byDate.containsKey(calendar.shiftDate(today, -i))) count++;
    }
    var streak = 0;
    var cursor = byDate.containsKey(today) ? 0 : 1;
    while (byDate.containsKey(calendar.shiftDate(today, -cursor))) {
      streak++;
      cursor++;
    }
    return ProgressSummary._(
      range,
      window,
      heat,
      groupSets,
      count,
      streak,
      byDate,
      today,
    );
  }
}

/// 时间范围的显示文案。
String rangeEyebrow(StatsRange r) => switch (r) {
  StatsRange.weeks4 => '近 4 周',
  StatsRange.weeks12 => '近 12 周',
  StatsRange.all => '全部记录',
};
String rangePill(StatsRange r) => switch (r) {
  StatsRange.weeks4 => '4 周',
  StatsRange.weeks12 => '12 周',
  StatsRange.all => '全部',
};

/// 标题：小号时间范围 + 大标题 + 右侧时间范围胶囊。
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.trainDays,
    required this.range,
    required this.onPickRange,
    this.showRange = true,
  });

  /// 还没有训练记录时不显示时间范围。
  final bool showRange;
  final int trainDays;
  final StatsRange range;
  final VoidCallback onPickRange;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (showRange) LText(rangeEyebrow(range), style: AppText.hint(p)),
              if (showRange && trainDays > 0) ...[
                Text(' · ', style: AppText.hint(p)),
                LText('练了', style: AppText.hint(p)),
                Text(
                  ' $trainDays ',
                  style: AppText.num(
                    p,
                    14,
                    weight: FontWeight.w600,
                    color: p.secondary,
                  ),
                ),
                LText('天', style: AppText.hint(p)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: LText('进度', style: AppText.display(p, size: 34))),
              if (showRange)
                Semantics(
                  button: true,
                  label: AppMessages.of(context).text('时间范围'),
                  value: AppMessages.of(context).text(rangePill(range)),
                  child: Pressable(
                    onTap: onPickRange,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      decoration: BoxDecoration(
                        color: p.fill2,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeSwitcher(
                            child: LText(
                              rangePill(range),
                              key: ValueKey(range),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Transform.rotate(
                            angle: math.pi / 2,
                            child: AppIcon(
                              'right',
                              size: 16,
                              color: p.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 所选范围累计热力人体 + 图例。点一块肌肉，在下方原地展开它的小结；再点一次或点别处收起。
class HeatHero extends StatelessWidget {
  const HeatHero({
    super.key,
    required this.heat,
    required this.bodyPaths,
    required this.onOpen,
    required this.selection,
    required this.brief,
    this.range = StatsRange.weeks4,
    this.height = 300,
  });
  final StatsRange range;
  final Map<String, double> heat;
  final Map<String, dynamic> bodyPaths;

  /// 「怎么练它」：打开这块肌肉的动作弹层。
  final ValueChanged<String> onOpen;

  /// 当前展开的肌肉 id（null = 收起）。放在外面，页面点别处时可以收起。
  final ValueNotifier<String?> selection;
  final MuscleBrief Function(String id) brief;
  final double height;

  /// 点击容差：小肌肉（小腿等）点在边上 16 点内也算。
  static const slop = 16.0;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final geometry = BodyGeometry(bodyPaths, female: BodySexScope.of(context));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final half = Size(box.maxWidth / 2, height);
                var point = Offset.zero;
                return Semantics(
                  button: true,
                  label: AppMessages.of(context).text(switch (range) {
                    StatsRange.weeks4 => '近 4 周肌肉热力图',
                    StatsRange.weeks12 => '近 12 周肌肉热力图',
                    StatsRange.all => '全部记录肌肉热力图',
                  }),
                  child: Listener(
                    onPointerDown: (e) => point = e.localPosition,
                    child: Pressable(
                      scale: 1,
                      onTap: () {
                        final back = point.dx >= half.width;
                        final painter = BodyPainter(
                          geometry: geometry,
                          back: back,
                          colors: const {},
                          palette: p,
                          selected: '',
                        );
                        final id = painter.muscleAt(
                          Offset(point.dx - (back ? half.width : 0), point.dy),
                          half,
                          slopPx: slop,
                        );
                        selection.value = id == null || id == selection.value
                            ? null
                            : id;
                      },
                      child: ValueListenableBuilder<String?>(
                        valueListenable: selection,
                        builder: (context, id, _) => BodyFigure(
                          height: height,
                          heat: heat,
                          selected: id ?? '',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                LText('练得少', style: AppText.hint(p)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(colors: [p.fill2, p.tint]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                LText('练得多', style: AppText.hint(p)),
              ],
            ),
            ValueListenableBuilder<String?>(
              valueListenable: selection,
              builder: (context, id, _) => Reveal(
                visible: id != null,
                child: id == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: MuscleBriefPanel(
                          key: ValueKey(id),
                          muscleId: id,
                          brief: brief(id),
                          range: range,
                          onOpen: () => onOpen(id),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _bigGroups = [
  'chest',
  'back',
  'shoulders',
  'quads',
  'hamstrings',
  'glutes',
];

/// 一条具体建议：近 4 周练得最少的大肌群 + 1~2 个现在能练的动作。
class SuggestionStrip extends StatelessWidget {
  const SuggestionStrip({
    super.key,
    required this.status,
    required this.owned,
    required this.onOpen,
    this.groupSets,
    this.range = StatsRange.weeks4,
  });
  final StatsRange range;

  /// 所选范围内各肌群的正式组数；为空时沿用 status 里的近 30 天。
  final Map<String, int>? groupSets;
  final Map<String, dynamic> status;
  final Set<String> owned;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final groups = status['groups'] as Map;
    if ((status['setCount'] as num) == 0) {
      return _shell(
        p,
        null,
        child: LText('记几次训练，这里会告诉你哪里练得最少。', style: AppText.body(p)),
      );
    }
    String? pick;
    num low = 1 << 30;
    for (final id in _bigGroups) {
      final n = groupSets != null
          ? (groupSets![id] ?? 0)
          : (groups[id]?['sets30'] as num?) ?? 0;
      if (n < low) {
        low = n;
        pick = id;
      }
    }
    if (pick == null) return const SizedBox.shrink();
    final group = pick;
    final names = [
      for (final g in recommendNow(status, owned: owned, perGroup: 2))
        if (g.group == group)
          ...g.exercises.where((e) => e.ready).map((e) => e.name),
    ].take(2).toList();
    var recovering = false;
    if (names.isEmpty) {
      // 该肌群现在没有已恢复的动作：挑最常用的动作，提示恢复后再练。
      names.addAll(
        [
          for (final name in freePool())
            if (exerciseAvailable(name, owned) &&
                MUSCLE[musclesOf(
                      name,
                      partOfExercise(name),
                    )!['primary']]?['group'] ==
                    group)
              name,
        ].take(2),
      );
      recovering = names.isNotEmpty;
    }
    final style = TextStyle(fontSize: 16, height: 1.45, color: p.text);
    final muscleId = MUSCLES.firstWhere((m) => m['group'] == group)['id']!;
    return _shell(
      p,
      () => onOpen(muscleId),
      child: LText.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: GROUP[group]!['name'],
              style: TextStyle(fontWeight: FontWeight.w800, color: p.tint),
            ),
            if (low > 0) ...[
              TextSpan(
                text: switch (range) {
                  StatsRange.weeks4 => '这 4 周只练了 ',
                  StatsRange.weeks12 => '这 12 周只练了 ',
                  StatsRange.all => '这段时间只练了 ',
                },
              ),
              TextSpan(
                text: fmt(low.round()),
                style: AppText.num(p, 17).copyWith(height: 1.2),
              ),
              const TextSpan(text: ' 组'),
            ] else
              TextSpan(
                text: switch (range) {
                  StatsRange.weeks4 => '这 4 周还没练到',
                  StatsRange.weeks12 => '这 12 周还没练到',
                  StatsRange.all => '这段时间还没练到',
                },
              ),
            if (names.isNotEmpty) ...[
              TextSpan(text: recovering ? '，恢复后试试' : '，下次试试'),
              // 动作名和“或”分开成段，各自按当前语言翻译。
              for (final (i, n) in names.indexed) ...[
                if (i > 0) const TextSpan(text: '或'),
                TextSpan(text: n),
              ],
            ],
            const TextSpan(text: '。'),
          ],
        ),
      ),
    );
  }

  Widget _shell(AppPalette p, VoidCallback? onTap, {required Widget child}) {
    final body = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: p.tintSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: LText(
              '建议',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.tint,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: child,
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? body
        : Semantics(
            button: true,
            child: Pressable(onTap: onTap, child: body),
          );
  }
}

/// 坚持格子：近 12 周每天是否训练（发力橙深浅）+ 图例。
class StreakGrid extends StatelessWidget {
  const StreakGrid({super.key, required this.summary});
  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final today = summary.today;
    final monday = calendar.mondayOf(today);
    final start = calendar.shiftDate(monday, -11 * 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          image: true,
          label: AppMessages.of(context).text('近 12 周训练日历'),
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 4.0;
              final cell = math.min(30.0, (box.maxWidth - gap * 11) / 12);
              return Center(
                child: SizedBox(
                  height: cell * 7 + gap * 6,
                  width: cell * 12 + gap * 11,
                  child: Row(
                    children: [
                      for (var w = 0; w < 12; w++) ...[
                        if (w > 0) const SizedBox(width: gap),
                        Column(
                          children: [
                            for (var d = 0; d < 7; d++) ...[
                              if (d > 0) const SizedBox(height: gap),
                              _cell(
                                p,
                                cell,
                                calendar.shiftDate(start, w * 7 + d),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LText('少', style: AppText.hint(p)),
            const SizedBox(width: 6),
            for (final l in const [0.0, .4, .7, 1.0]) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: _level(p, l),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
            const SizedBox(width: 3),
            LText('多', style: AppText.hint(p)),
          ],
        ),
      ],
    );
  }

  static Color _level(AppPalette p, double l) =>
      l == 0 ? p.fill : Color.lerp(p.tintSoft, p.tint, l)!;

  Widget _cell(AppPalette p, double size, String iso) {
    final future = iso.compareTo(summary.today) > 0;
    final sets = summary.setsByDate[iso] ?? 0;
    final level = sets == 0 ? 0.0 : (sets < 5 ? .4 : (sets < 10 ? .7 : 1.0));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: future ? p.fill.withValues(alpha: 0) : _level(p, level),
        borderRadius: BorderRadius.circular(math.max(3, size * .22)),
      ),
    );
  }
}

/// 区块里的可展开部分：一行标题 + 小箭头，点一下展开 / 收起，内容默认收起。不套卡片。
class CollapsibleBlock extends StatefulWidget {
  const CollapsibleBlock({
    super.key,
    required this.title,
    required this.child,
    this.initiallyOpen = false,
  });
  final String title;
  final Widget child;
  final bool initiallyOpen;
  @override
  State<CollapsibleBlock> createState() => _CollapsibleBlockState();
}

class _CollapsibleBlockState extends State<CollapsibleBlock> {
  late bool open = widget.initiallyOpen;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: AppMessages.of(context).text(widget.title),
          child: Pressable(
            onTap: () => setState(() => open = !open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.sep, width: .5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LText(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: open ? -math.pi / 2 : math.pi / 2,
                    child: AppIcon('right', size: 16, color: p.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        Reveal(
          visible: open,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// 墨色主按钮（非训练主操作）：背景 primary，文字 onPrimary。
class InkButton extends StatelessWidget {
  const InkButton(
    this.label, {
    super.key,
    required this.onTap,
    this.soft = false,
  });

  /// 同屏已有主按钮时用次级样式（浅灰底、正文色）。
  final bool soft;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: soft ? p.fill2 : p.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: LText(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: soft ? p.text : p.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
