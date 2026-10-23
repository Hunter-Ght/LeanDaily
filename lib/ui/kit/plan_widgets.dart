import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../domain/movements.dart' show MUSCLES;
import '../../theme/theme.dart';
import '../stats/muscle/body_map.dart';
import 'pressable.dart';
import 'grouped.dart';
import 'form.dart';
import '../../domain/plan_insight.dart';

enum PlanCardSize { large, medium, small }

class WeekDots extends StatelessWidget {
  const WeekDots({
    super.key,
    required this.week,
    this.diameter = 28,
    this.showWeekdays = true,
  });
  final List week;
  final double diameter;
  final bool showWeekdays;
  static String describe(List week) => week
      .map(
        (d) =>
            '周${const ['日', '一', '二', '三', '四', '五', '六'][d['dow'] as int]}${d['label']}',
      )
      .join(' ');
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppMessages.of(context).text(describe(week)),
    excludeSemantics: true,
    child: Row(
      children: [
        for (final day in [1, 2, 3, 4, 5, 6, 0])
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showWeekdays) ...[
                  LText(
                    const ['日', '一', '二', '三', '四', '五', '六'][day],
                    style: TextStyle(
                      fontSize: 11,
                      color: context.pal.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Builder(
                  builder: (context) {
                    final matches = week.where((d) => d['dow'] == day);
                    final active = matches.isNotEmpty;
                    return Container(
                      width: diameter,
                      height: diameter,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? context.pal.tint : context.pal.fill2,
                      ),
                      child: active
                          ? LText(
                              '${matches.first['label']}',
                              textScaler: TextScaler.noScaling,
                              style: TextStyle(
                                fontSize: diameter < 20 ? 11 : 13,
                                fontWeight: FontWeight.w700,
                                color: context.pal.onTint,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class MiniBody extends StatelessWidget {
  const MiniBody({super.key, required this.levels, this.height = 84});
  final Map<String, int> levels;
  final double height;
  static Future<Map<String, dynamic>>? _data;
  static Map<String, dynamic>? _loaded;
  static Future<Map<String, dynamic>> load() => _data ??= rootBundle
      .loadString('assets/muscle_map.json')
      .then((s) => _loaded = jsonDecode(s) as Map<String, dynamic>);
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * 1.1,
    child: FutureBuilder<Map<String, dynamic>>(
      future: load(),
      initialData: _loaded,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey(
            Object.hashAll(
              levels.entries.map((e) => Object.hash(e.key, e.value)),
            ),
          ),
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          builder: (context, t, _) {
            final p = context.pal;
            final colors = <String, Color>{
              for (final m in MUSCLES)
                m['id']!: Color.lerp(
                  p.fill2,
                  (levels[m['id']] ?? 0) == 0
                      ? p.fill2
                      : p.tint.withValues(
                          alpha: const [
                            0,
                            .35,
                            .65,
                            1,
                          ][levels[m['id']] ?? 0].toDouble(),
                        ),
                  t,
                )!,
            };
            return Row(
              children: [
                for (final back in [false, true])
                  Expanded(
                    child: CustomPaint(
                      size: Size(height * .55, height),
                      painter: BodyPainter(
                        geometry: BodyGeometry(
                          snapshot.data!,
                          female: BodySexScope.of(context),
                        ),
                        back: back,
                        colors: colors,
                        palette: p,
                        selected: '',
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.level});
  final int level;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var i = 1; i <= 3; i++)
        Container(
          width: 4,
          height: 5 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i <= level ? context.pal.tint : context.pal.fill,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      const SizedBox(width: 3),
      Flexible(
        child: LText(
          const ['新手可上手', '有基础', '老手'][(level - 1).clamp(0, 2)],
          style: TextStyle(fontSize: 12, color: context.pal.secondary),
        ),
      ),
    ],
  );
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.tagline,
    required this.insight,
    this.size = PlanCardSize.medium,
    this.level = 1,
    this.feature,
    this.selected = false,
    this.reasons = const [],
    this.onTap,
    this.footer,
  });
  final String name, tagline;
  final Map<String, dynamic> insight;
  final PlanCardSize size;
  final int level;
  final String? feature;
  final bool selected;
  final List<String> reasons;
  final VoidCallback? onTap;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final small = size == PlanCardSize.small;
    final height = switch (size) {
      PlanCardSize.large => 104.0,
      PlanCardSize.medium => 84.0,
      PlanCardSize.small => 68.0,
    };
    final week = insight['week'] as List;
    final content = Container(
      padding: EdgeInsets.all(small ? 12 : 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? p.tint : p.card, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reasons.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final reason in ['为你推荐', ...reasons])
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.tintSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LText(
                      reason,
                      style: TextStyle(fontSize: 12, color: p.secondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: p.fill2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MiniBody(
                  levels: Map<String, int>.from(insight['muscleLevels'] as Map),
                  height: height,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText.rich(
                      TextSpan(
                        text: name,
                        children: [
                          if (feature != null)
                            TextSpan(
                              text: '  $feature',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.secondary,
                              ),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: small ? 17 : 18,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    LText(
                      tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: p.secondary,
                      ),
                    ),
                    if (!small) ...[const SizedBox(height: 8), _meta(context)],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WeekDots(
            week: week,
            diameter: small
                ? 24
                : size == PlanCardSize.large
                ? 32
                : 28,
          ),
          if (small) ...[const SizedBox(height: 10), _meta(context)],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
    final animated = _SelectionScale(selected: selected, child: content);
    if (onTap == null) return animated;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: AppMessages.of(context)
          .text('$name，每周 ${week.length} 天，${WeekDots.describe(week)}'),
      child: Pressable(onTap: onTap, child: animated),
    );
  }

  Widget _meta(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      LText(
        '约 ${insight['minutes']} 分钟 / 次 ·',
        style: TextStyle(fontSize: 12, color: context.pal.secondary),
      ),
      LevelMeter(level: level),
    ],
  );
}

/// Shared preview for onboarding and the template catalog.
class PlanPreview extends StatefulWidget {
  const PlanPreview({
    super.key,
    required this.plan,
    required this.tagline,
    this.venue = 'home',
  });
  final Map<String, dynamic> plan;
  final String tagline, venue;
  @override
  State<PlanPreview> createState() => _PlanPreviewState();
}

class _PlanPreviewState extends State<PlanPreview> {
  late String _venue = widget.venue;
  @override
  Widget build(BuildContext context) {
    final insight = planInsight(widget.plan, venue: _venue);
    final workouts = widget.plan['workouts'] as Map? ?? {};
    final schedule = widget.plan['schedule'] as Map? ?? {};
    final hasGym = workouts.values.any((w) => w['gym'] is Map);
    final p = context.pal;
    return GroupScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: MiniBody(
                    levels: Map<String, int>.from(
                      insight['muscleLevels'] as Map,
                    ),
                    height: 190,
                  ),
                ),
                const SizedBox(height: 12),
                LText(
                  '${widget.tagline} · 约 ${insight['minutes']} 分钟 / 次',
                  style: AppText.hint(p),
                ),
                const SizedBox(height: 14),
                WeekDots(week: insight['week'] as List, diameter: 34),
              ],
            ),
          ),
          const GroupHeader('每天练什么'),
          if (hasGym)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FormSegments(
                labels: const ['居家版', '健身房版'],
                selected: _venue == 'gym' ? 1 : 0,
                onChanged: (i) =>
                    setState(() => _venue = i == 0 ? 'home' : 'gym'),
              ),
            ),
          GroupCard(
            children: [
              for (final day in insight['week'] as List)
                Builder(
                  builder: (context) {
                    final workout =
                        workouts[schedule['${day['dow']}'] ??
                                schedule[day['dow']]]
                            as Map;
                    final variant = _venue == 'gym' && workout['gym'] is Map
                        ? workout['gym'] as Map
                        : workout;
                    final exercises = (variant['exercises'] as List? ?? [])
                        .cast<Map>();
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.tint,
                            ),
                            child: LText(
                              '${day['label']}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: p.onTint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LText(
                                  '周${const ['日', '一', '二', '三', '四', '五', '六'][day['dow'] as int]} · ${workout['name']}',
                                  style: AppText.h2(p),
                                ),
                                const SizedBox(height: 6),
                                LText(
                                  exercises.map((ex) => ex['name']).join(' · '),
                                  style: AppText.hint(p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const GroupHeader('组数与动作提示'),
          for (final workout in workouts.values)
            Builder(
              builder: (context) {
                final variant = _venue == 'gym' && workout['gym'] is Map
                    ? workout['gym'] as Map
                    : workout as Map;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: LText('${workout['name']}', style: AppText.h2(p)),
                    ),
                    if ('${variant['note'] ?? workout['note'] ?? ''}'
                        .isNotEmpty)
                      LText(
                        '${variant['note'] ?? workout['note']}',
                        style: AppText.hint(p),
                      ),
                    for (final ex in variant['exercises'] as List? ?? []) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LText(
                          '${ex['name']} · ${ex['sets']} 组 × ${ex['min']}–${ex['max']} ${ex['unit'] == 'sec' ? '秒' : '次'}${ex['side'] == true ? ' / 每侧' : ''}${ex['optional'] == true ? ' · 可选' : ''}',
                          style: AppText.hint(p),
                        ),
                      ),
                      if ('${ex['tip'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: LText(
                            '${ex['name']}：${ex['tip']}',
                            style: AppText.hint(p),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SelectionScale extends StatefulWidget {
  const _SelectionScale({required this.selected, required this.child});
  final bool selected;
  final Widget child;
  @override
  State<_SelectionScale> createState() => _SelectionScaleState();
}

class _SelectionScaleState extends State<_SelectionScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  void _animate() {
    final target = widget.selected ? 1.005 : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scale.value = target;
    } else {
      _scale.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 300, damping: 25),
          _scale.value,
          target,
          _scale.velocity,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(_SelectionScale old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _animate();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    child: widget.child,
    builder: (context, child) =>
        Transform.scale(scale: _scale.value, child: child),
  );
}
