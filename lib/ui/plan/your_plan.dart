import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/plan.dart' as plans;
import '../../domain/plan_insight.dart';
import '../../domain/plan_recipe.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/segments.dart';
import '../kit/transitions.dart';
import '../today/workout_title.dart';
import 'volume_bars.dart';
import 'week_picker.dart';

const _focusLabels = {
  'balanced': '均衡',
  'shoulders_back': '肩背',
  'chest_shoulders': '胸肩',
  'glutes_legs': '臀腿',
  'core': '腹部',
  'posture': '体态',
};

/// 标题第二行：排法 + 重点，整句翻译。
const _summaries = {
  ('full', 'balanced'): '全身都练，各部位均衡',
  ('full', 'shoulders_back'): '全身都练，肩背多一点',
  ('full', 'chest_shoulders'): '全身都练，胸肩多一点',
  ('full', 'glutes_legs'): '全身都练，臀腿多一点',
  ('full', 'core'): '全身都练，腹部多一点',
  ('full', 'posture'): '全身都练，重点改善体态',
  ('ul', 'balanced'): '上下半身分开练，各部位均衡',
  ('ul', 'shoulders_back'): '上下半身分开练，肩背多一点',
  ('ul', 'chest_shoulders'): '上下半身分开练，胸肩多一点',
  ('ul', 'glutes_legs'): '上下半身分开练，臀腿多一点',
  ('ul', 'core'): '上下半身分开练，腹部多一点',
  ('ul', 'posture'): '上下半身分开练，重点改善体态',
  ('ppl', 'balanced'): '推、拉、腿分开练，各部位均衡',
  ('ppl', 'shoulders_back'): '推、拉、腿分开练，肩背多一点',
  ('ppl', 'chest_shoulders'): '推、拉、腿分开练，胸肩多一点',
  ('ppl', 'glutes_legs'): '推、拉、腿分开练，臀腿多一点',
  ('ppl', 'core'): '推、拉、腿分开练，腹部多一点',
  ('ppl', 'posture'): '推、拉、腿分开练，重点改善体态',
};

/// 「换成……」按钮的文字：写清另一种排法的差别。
const _switchTo = {
  'full': '换成：每次全身都练',
  'ul': '换成：上半身和下半身分开练',
  'ppl': '换成：每天只练一个方向（推、拉、腿）',
};

/// 「你的方案」：按配方实时生成方案并展示，可以直接在上面调整。
/// 内容很长，不自带滚动，放进外层的滚动区使用。
///
/// 配方由外层持有：[recipe] 是当前配方，用户每改一项就用新的配方调用 [onChanged]。
class YourPlan extends StatefulWidget {
  const YourPlan({
    super.key,
    required this.recipe,
    required this.onChanged,
    @visibleForTesting this.build = buildRecipePlan,
  });
  final Map<String, dynamic> recipe;
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// 按配方生成方案。只有测试会换掉它。
  final Map<String, dynamic> Function(Map<String, dynamic> recipe) build;

  @override
  State<YourPlan> createState() => _YourPlanState();
}

class _YourPlanState extends State<YourPlan> {
  String _planKey = '';
  Map<String, dynamic> _plan = const {};
  int? _day;
  bool _gym = false;

  Map<String, dynamic> _planFor(Map<String, dynamic> r) {
    final key = jsonEncode(r);
    if (key != _planKey) {
      _plan = widget.build(r);
      _planKey = key;
    }
    return _plan;
  }

  void _toggle(Map<String, dynamic> r, int day) {
    final days = {...(r['weekdays'] as List).cast<int>()};
    final toast = context.app.toast;
    if (days.contains(day)) {
      if (days.length <= 2) {
        toast.show('每周至少练 2 天');
        return;
      }
      days.remove(day);
    } else {
      if (days.length >= 5) {
        toast.show('每周最多练 5 天');
        return;
      }
      days.add(day);
    }
    final next = days.toList()..sort((a, b) => (a + 6) % 7 - (b + 6) % 7);
    widget.onChanged(
      normalizeRecipe({
        ...r,
        'days': next.length,
        'weekdays': next,
        // 天数变了，排法回到这个天数下的默认排法。
        'split': splitsFor(next.length, '${r['experience']}').first,
      }),
    );
  }

  Widget _heading(String text, {double top = 36}) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 12),
    child: LText(text, style: AppText.title(context.pal)),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = normalizeRecipe(widget.recipe);
    final plan = _planFor(r);
    final weekdays = (r['weekdays'] as List).cast<int>();
    final venue = r['venue'] == 'gym' || (r['venue'] == 'both' && _gym)
        ? 'gym'
        : 'home';
    final insight = planInsight(plan, venue: venue);
    final labels = {
      for (final d in insight['week'] as List) d['dow'] as int: '${d['label']}',
    };
    final volume = weeklyVolume(plan, venue: venue);
    final alt = alternateRecipe(r);
    final notes = [
      for (final n
          in plan['recipeNotes'] is List
              ? plan['recipeNotes'] as List
              : const [])
        if ('$n'.trim().isNotEmpty) '$n',
    ];
    final cardio = plan['cardio'] is Map ? plan['cardio'] as Map : null;
    final cardioText = cardio != null && cardio['perWeek'] is num
        ? '休息日加 ${cardio['perWeek']} 次 ${cardio['minutes']} 分钟的快走或有氧'
        : null;
    final day = labels.containsKey(_day)
        ? _day!
        : weekdays.firstWhere(labels.containsKey, orElse: () => weekdays.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText(
          '每周 ${r['days']} 天\n每次约 ${r['minutes']} 分钟',
          key: const ValueKey('plan-headline'),
          style: AppText.display(p, size: 32),
        ),
        const SizedBox(height: 8),
        LText(
          _summaries[(r['split'], r['focus'])] ?? '',
          key: const ValueKey('plan-summary'),
          style: AppText.body(p).copyWith(color: p.secondary),
        ),
        const SizedBox(height: 22),
        WeekPicker(labels: labels, onToggle: (d) => _toggle(r, d)),
        const SizedBox(height: 4),
        LText('点一下调整哪几天练', style: AppText.hint(p)),
        _heading('每次多久'),
        AppSegments(
          labels: [for (final m in recipeMinutes) '$m 分钟'],
          selected: recipeMinutes.indexOf(r['minutes'] as int),
          onChanged: (i) =>
              widget.onChanged({...r, 'minutes': recipeMinutes[i]}),
        ),
        _heading('想重点练哪'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in recipeFocuses)
              _Choice(
                key: ValueKey('plan-focus-$f'),
                label: _focusLabels[f]!,
                selected: r['focus'] == f,
                onTap: () => widget.onChanged({...r, 'focus': f}),
              ),
          ],
        ),
        _heading('为什么这样排'),
        LText('每周各部位练几组，橙色是你想重点练的。', style: AppText.hint(p)),
        const SizedBox(height: 10),
        VolumeBars(rows: volume),
        _heading('每天练什么'),
        if (r['venue'] == 'both' &&
            (plan['workouts'] as Map).values.any(
              (w) => w is Map && w['gym'] is Map,
            ))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AppSegments(
              labels: const ['在家练', '健身房练'],
              selected: _gym ? 1 : 0,
              onChanged: (i) => setState(() => _gym = i == 1),
            ),
          ),
        _DayTabs(
          labels: labels,
          selected: day,
          onSelected: (d) => setState(() => _day = d),
        ),
        const SizedBox(height: 8),
        FadeSwitcher(
          child: _DayExercises(
            key: ValueKey('day-$day-$venue-${labels.length}'),
            plan: plan,
            day: day,
            venue: venue,
          ),
        ),
        if (notes.isNotEmpty || cardioText != null) ...[
          _heading('补充说明'),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LText(n, style: AppText.body(p).copyWith(fontSize: 15)),
            ),
          if (cardioText != null)
            LText(
              cardioText,
              key: const ValueKey('plan-cardio'),
              style: AppText.body(p).copyWith(fontSize: 15),
            ),
        ],
        if (alt != null) ...[
          const SizedBox(height: 28),
          Semantics(
            button: true,
            label: AppMessages.of(context).text(_switchTo['${alt['split']}']!),
            excludeSemantics: true,
            child: Pressable(
              key: const ValueKey('plan-alt'),
              onTap: () => widget.onChanged(alt),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Flexible(
                      child: LText(
                        _switchTo['${alt['split']}']!,
                        style: AppText.body(p)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppIcon('right', size: 16, color: p.text),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 单选的小胶囊：选中墨色底，没选中中性底。
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        haptic: !selected,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? p.primary : p.fill2,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            widthFactor: 1,
            child: LText(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? p.onPrimary : p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 训练日切换：和上面的一周圆点同样的一个字。
class _DayTabs extends StatelessWidget {
  const _DayTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final Map<int, String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final d in const [1, 2, 3, 4, 5, 6, 0])
          if (labels.containsKey(d))
            Semantics(
              button: true,
              selected: d == selected,
              label: AppMessages.of(context).text(weekdayNames[d]),
              excludeSemantics: true,
              child: Pressable(
                key: ValueKey('plan-tab-$d'),
                onTap: () => onSelected(d),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d == selected ? p.tint : p.tintSoft,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: LText(
                              labels[d]!,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: d == selected ? p.onTint : p.tint,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LText(
                        weekdayNames[d],
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: d == selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: d == selected ? p.text : p.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// 某一天的动作：缩略图、名称、「3 组 × 8～12 次」；点开看示范。
class _DayExercises extends StatelessWidget {
  const _DayExercises({
    super.key,
    required this.plan,
    required this.day,
    required this.venue,
  });
  final Map<String, dynamic> plan;
  final int day;
  final String venue;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final schedule = plan['schedule'] as Map? ?? {};
    final workout = (plan['workouts'] as Map?)?['${schedule['$day']}'];
    if (workout is! Map) return const SizedBox.shrink();
    final variant = venue == 'gym' && workout['gym'] is Map
        ? workout['gym'] as Map
        : workout;
    final list = (variant['exercises'] as List? ?? []).whereType<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LText(weekdayNames[day], style: AppText.h2(p)),
              Text(' · ', style: AppText.h2(p)),
              LText(workoutTitle('${workout['name']}'), style: AppText.h2(p)),
            ],
          ),
        ),
        for (final (i, raw) in list.indexed) ...[
          if (i > 0) Container(height: .5, color: p.sep),
          Builder(
            builder: (context) {
              final ex = Map<String, dynamic>.from(raw);
              return Semantics(
                button: true,
                label: AppMessages.of(context).text('${ex['name']}，看示范'),
                excludeSemantics: true,
                child: Pressable(
                  key: ValueKey('plan-ex-$day-$i'),
                  onTap: () => openGuide(context, '${ex['name']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        ExerciseThumb(ex: ex, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LText(
                                '${ex['name']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              LText(
                                plans.prescription(ex),
                                style: AppText.hint(p),
                              ),
                            ],
                          ),
                        ),
                        AppIcon('right', size: 16, color: p.tertiary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
