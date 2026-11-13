import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/goals.dart';
import '../../domain/muscle_brief.dart';
import '../../domain/muscles.dart' show muscleStatus;
import '../../domain/strength_hint.dart';
import '../../domain/stats.dart';
import '../kit/menu.dart';
import '../../domain/stats_range.dart';
import '../../domain/week_achievement.dart';
import 'body_route_card.dart';
import 'weekly_review_card.dart' show weeklyReviewFor;
import 'strength_section.dart';
import 'streak_section.dart';
import 'progress_empty.dart';
import 'muscle/muscle_card.dart';
import 'progress_sections.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.wide, required this.two});
  final bool wide, two;
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsRange _range = StatsRange.weeks4;
  StatsRange? _summaryRange;
  Map<String, dynamic>? bodyPaths;
  Timer? _minute;
  // 点热力人体后展开的肌肉；点页面别处收起。
  final _picked = ValueNotifier<String?>(null);
  bool _visible = true;
  Object? _recordsToken;
  String _statsDate = '';
  Map<String, dynamic> _days = {}, _meals = {}, _stats = {};
  Map<String, Map<String, dynamic>> _muscleDays = {};
  ProgressSummary? _summary;
  Map<String, dynamic> _status = {};

  void _refreshProjection(AppController app) {
    final changed = !identical(_recordsToken, app.repo.snapshotToken);
    if (changed) {
      _recordsToken = app.repo.snapshotToken;
      _days = app.repo.allDays();
      _meals = app.repo.allMeals();
      _muscleDays = _days.map((k, v) => MapEntry(k, jsonMap(v)));
    }
    if (changed || _statsDate != app.today || _summaryRange != _range) {
      _summaryRange = _range;
      _statsDate = app.today;
      _stats = buildStats(app.today, null, null, days: _days, meals: _meals);
      _summary = ProgressSummary.build(_muscleDays, app.today, _range);
      _status = muscleStatus(_muscleDays, app.clock().millisecondsSinceEpoch);
    }
  }

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/muscle_map.json').then((value) {
      if (mounted) {
        setState(() => bodyPaths = jsonDecode(value) as Map<String, dynamic>);
      }
    });
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _visible) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _minute?.cancel();
    _picked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        // Tab changes, sync status and keyboard insets must not aggregate the
        // entire training/meal history again. A record mutation invalidates it.
        _refreshProjection(app);
        final days = _days;
        final stats = _stats;
        final week = jsonMap(stats['week']);
        final target = weekTargetFromHistory(
          app.goals['weekDays']!,
          jsonMap(app.plan['schedule']).length,
          days,
        );
        final exercises = jsonRows(stats['exercises']);
        final bests = jsonRows(stats['bests']);
        // 没有任何正式组 = 还没有训练记录：整页只放一个引导（体重可以独立记录）。
        final empty = bests.isEmpty;
        final summary = _summary!;
        final hits = weekHits(
          weekDays: jsonRows(week['days']),
          meals: _meals,
          proteinGoal: app.proteinGoal,
          kcalGoal: app.kcalGoal,
        );
        final muscleDetail = bodyPaths == null
            ? const SizedBox.shrink()
            : CollapsibleBlock(
                title: '查看每块肌肉',
                child: MuscleCard(
                  days: _muscleDays,
                  nowMs: app.clock().millisecondsSinceEpoch,
                  bodyPaths: bodyPaths!,
                  onOpen: (id) => openMuscleExercises(context, id),
                ),
              );
        final hero = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: bodyPaths != null,
              child: bodyPaths == null
                  ? const SizedBox.shrink()
                  : HeatHero(
                      heat: summary.heat,
                      range: _range,
                      bodyPaths: bodyPaths!,
                      onOpen: (id) => openMuscleExercises(context, id),
                      selection: _picked,
                      brief: (id) => muscleBrief(
                        _muscleDays,
                        id,
                        summary.window,
                        app.today,
                      ),
                      height: widget.wide ? 360 : 300,
                    ),
            ),
            const SizedBox(height: 8),
            muscleDetail,
          ],
        );
        final suggestion = SuggestionStrip(
          status: _status,
          groupSets: summary.groupSets,
          range: _range,
          owned: app.myGym,
          onOpen: (id) => openMuscleExercises(context, id),
        );
        final strength = StrengthSection(
          exercises: exercises,
          bests: bests,
          today: app.today,
          range: _range,
          timedNames: timedExerciseNames(app.plan),
          stepFor: (name) => strengthStepFor(
            name,
            plan: app.plan,
            days: _days,
            dayStates: app.dayStates,
            progress: app.progress,
            today: app.today,
            options: app.progressOptions,
          ),
        );
        final streak = StreakSection(
          summary: summary,
          hits: hits,
          trainTarget: target,
          review: weeklyReviewFor(app),
        );
        List<Widget> spaced(List<Widget> items, [double gap = 32]) => [
          for (final (i, w) in items.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            w,
          ],
        ];
        // 五块：热力人体（含建议）→ 体重 → 力量 → 坚持。没有记录时只剩引导 + 体重。
        // 宽屏分两栏时，体重放左栏：左栏（人体 + 建议）本来比右栏（力量 + 坚持）短一大截。
        final heroBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaced([hero, suggestion], 16),
        );
        final leftItems = empty
            ? [ProgressEmpty(height: widget.wide ? 300 : 240)]
            : [heroBlock, const BodyRouteCard()];
        final rightItems = empty
            ? [const BodyRouteCard(softAction: true)]
            : [strength, streak];
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _picked.value = null,
          child: SingleChildScrollView(
            key: const PageStorageKey('stats-scroll'),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 52,
              widget.wide ? 24 : 16,
              widget.wide ? 24 : 104 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final twoCols = box.maxWidth >= 640;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProgressHeader(
                          showRange: !empty,
                          trainDays: summary.trainDays,
                          range: _range,
                          onPickRange: _pickRange,
                        ),
                        if (twoCols)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: spaced(leftItems),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: spaced(rightItems),
                                ),
                              ),
                            ],
                          )
                        else
                          ...spaced([...leftItems, ...rightItems]),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickRange() async {
    final picked = await showActionMenu(
      context,
      title: '时间范围',
      actions: [
        for (final r in StatsRange.values)
          MenuAction(id: r.name, label: rangeEyebrow(r), selected: r == _range),
      ],
    );
    if (picked == null || !mounted) return;
    final next = StatsRange.values.firstWhere((r) => r.name == picked.id);
    if (next != _range) setState(() => _range = next);
  }
}
