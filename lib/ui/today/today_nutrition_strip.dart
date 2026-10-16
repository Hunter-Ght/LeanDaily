import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/calendar.dart';
import '../../domain/format.dart' hide shiftDate;
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/app_icon.dart';
import '../kit/transitions.dart';
import 'today_model.dart';
import 'today_widgets.dart';

/// Same 14-day occurrence ranking as QuickFoodSheet; retain the latest portion
/// so a direct tap records an honest serving rather than an assumed weight.
List<Map<String, dynamic>> frequentTodayFoods(AppController app, String date) {
  final counts = <String, int>{}, entries = <String, Map<String, dynamic>>{};
  for (var i = 0; i < 14; i++) {
    for (final meal in jsonRows(app.repo.meals(shiftDate(date, -i))['meals'])) {
      for (final entry in jsonRows(meal['items'])) {
        final name = '${entry['name']}';
        counts[name] = (counts[name] ?? 0) + 1;
        entries.putIfAbsent(name, () => entry);
      }
    }
  }
  final ranked = entries.values.toList()
    ..sort((a, b) => counts[b['name']]!.compareTo(counts[a['name']]!));
  return ranked;
}

final _dailyAchievements = Expando<Map<String, Set<String>>>();

class TodayNutritionStrip extends StatefulWidget {
  const TodayNutritionStrip({super.key, required this.model});
  final TodayModel model;
  @override
  State<TodayNutritionStrip> createState() => _TodayNutritionStripState();
}

class _TodayNutritionStripState extends State<TodayNutritionStrip>
    with SingleTickerProviderStateMixin {
  bool busy = false, expanded = false;
  String _date = '';
  Set<String> _achieved = {};
  final Set<String> _pulsing = {};
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TodayNutritionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkGoals(feedback: true);
  }

  @override
  void initState() {
    super.initState();
    _checkGoals(feedback: false);
  }

  void _checkGoals({required bool feedback}) {
    final m = widget.model, app = m.app;
    if (_date != m.iso) {
      _date = m.iso;
      final days = _dailyAchievements[m.app] ??= {};
      _achieved = days.putIfAbsent(m.iso, () => <String>{});
    }
    if (app.profile == null) return;
    final totals = jsonMap(app.repo.meals(m.iso)['totals']);
    final crossed = <String>{};
    for (final entry in {
      'protein': app.proteinGoal,
      'kcal': app.kcalGoal,
    }.entries) {
      if (entry.value > 0 &&
          jsNumber(totals[entry.key]) >= entry.value &&
          _achieved.add(entry.key)) {
        crossed.add(entry.key);
      }
    }
    if (crossed.isNotEmpty && feedback) {
      _pulsing
        ..clear()
        ..addAll(crossed);
      app.haptics.saved();
      _pulse.forward(from: 0);
    }
  }

  Future<void> add(Map<String, dynamic>? food) async {
    if (busy) return;
    final app = widget.model.app, date = widget.model.iso;
    setState(() => busy = true);
    try {
      if (food == null) {
        await app.addProteinPowder(date);
      } else {
        final now = app.clock();
        await app.repo.saveMeal(
          date: date,
          meal: '加餐',
          time:
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          source: '手动填写',
          items: [Map<String, dynamic>.from(food)],
        );
        app.toast.show('已记入 ${food['name']}');
      }
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model, app = m.app, p = context.pal;
    final recent = frequentTodayFoods(app, m.iso);
    final totals = jsonMap(app.repo.meals(m.iso)['totals']);
    final protein = jsNumber(totals['protein']),
        kcal = jsNumber(totals['kcal']);
    final powder = jsonMap(jsonMap(app.plan['protein'])['powder']);
    final frequent = recent
        .where(
          (f) =>
              powder.isEmpty || !'${f['name']}'.startsWith('${powder['name']}'),
        )
        .take(powder.isEmpty ? 3 : 2);
    Widget metric(
      String label,
      num value,
      num goal,
      String unit,
      Color color,
    ) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, height: 1.1, color: p.secondary),
            ),
            Text(
              '${fmt(value)} / ${fmt(goal)} $unit',
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
            Reveal(
              visible: value > goal && goal > 0,
              child: Text(
                '超出 ${fmt(value - goal)}',
                style: TextStyle(fontSize: 12, color: p.secondary),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => TodayBar(
                height: 4,
                value: goal > 0 ? (value / goal).clamp(0, 1).toDouble() : 0,
                color:
                    _pulsing.contains(label == '蛋白' ? 'protein' : 'kcal') &&
                        !MediaQuery.disableAnimationsOf(context)
                    ? Color.lerp(
                        color,
                        p.text,
                        .25 * (1 - (2 * _pulse.value - 1).abs()),
                      )!
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
    return Reveal(
      visible: app.profile != null || recent.isNotEmpty,
      child: TodayCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: expanded ? '收起营养条带' : '展开营养条带',
                    child: Pressable(
                      onTap: () => setState(() => expanded = !expanded),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Reveal(
                              visible: app.profile == null,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '已吃 ${fmt(kcal)} 千卡 · 蛋白 ${fmt(protein)} g',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: p.text,
                                  ),
                                ),
                              ),
                            ),
                            Reveal(
                              visible: app.profile != null,
                              child: Row(
                                children: [
                                  metric(
                                    '蛋白',
                                    protein,
                                    app.proteinGoal,
                                    'g',
                                    p.protein,
                                  ),
                                  metric(
                                    '热量',
                                    kcal,
                                    app.kcalGoal,
                                    '千卡',
                                    p.kcal,
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
                Semantics(
                  button: true,
                  label: '添加饮食',
                  child: Pressable(
                    onTap: () => openQuickFood(context, date: m.iso),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: p.fill2,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AppIcon('plus', size: 20, color: p.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Reveal(
              visible: expanded,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Reveal(
                      visible: powder.isNotEmpty || frequent.isNotEmpty,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '常吃',
                            style: TextStyle(fontSize: 13, color: p.secondary),
                          ),
                          FadeSwitcher(
                            child: Wrap(
                              key: ValueKey(
                                [
                                  if (powder.isNotEmpty) powder['name'],
                                  ...frequent.map((f) => f['name']),
                                ].join('|'),
                              ),
                              spacing: 8,
                              children: [
                                if (powder.isNotEmpty)
                                  TodayFoodChip(
                                    name: '${powder['name']}',
                                    protein: jsNumber(powder['protein']),
                                    onTap: busy ? null : () => add(null),
                                  ),
                                for (final food in frequent)
                                  TodayFoodChip(
                                    name: '${food['name']}',
                                    protein: jsNumber(food['protein']),
                                    onTap: busy ? null : () => add(food),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Reveal(
                      visible: app.profile != null && protein < app.proteinGoal,
                      child: Text(
                        '还差约 ${fmt((app.proteinGoal - protein).round())} g 蛋白',
                        style: TextStyle(fontSize: 13, color: p.secondary),
                      ),
                    ),
                    Wrap(
                      spacing: 20,
                      children: [
                        TodayButton(
                          '快速记饮食',
                          onTap: () => openQuickFood(context, date: m.iso),
                        ),
                        TodayButton(
                          '拍照记录',
                          onTap: () {
                            app.setDate(m.iso);
                            openMealSheet(context);
                          },
                        ),
                      ],
                    ),
                    Text(
                      '营养数据为估算，可按实际份量调整。',
                      style: TextStyle(fontSize: 13, color: p.secondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact visual pill with a separate 44-point touch target.
class TodayFoodChip extends StatelessWidget {
  const TodayFoodChip({
    super.key,
    required this.name,
    required this.protein,
    required this.onTap,
  });
  final String name;
  final num protein;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: '添加 $name，${fmt(protein)} g 蛋白',
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.fill2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.text),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '+${fmt(protein)} g 蛋白',
                  style: TextStyle(fontSize: 12, color: p.secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
