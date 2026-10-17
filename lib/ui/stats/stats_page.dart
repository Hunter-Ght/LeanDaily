import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/goals.dart';
import '../../domain/stats.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/pressable.dart';
import 'body_route_card.dart';
import 'weekly_review_card.dart';
import 'muscle/muscle_card.dart';
import 'review_card.dart';
import 'stat_widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.wide, required this.two});
  final bool wide, two;
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String picked = '';
  bool allBests = false;
  Map<String, dynamic>? bodyPaths;
  Timer? _minute;
  bool _visible = true;
  Object? _recordsToken;
  String _statsDate = '';
  Map<String, dynamic> _days = {}, _meals = {}, _stats = {};
  Map<String, Map<String, dynamic>> _muscleDays = {};

  void _refreshProjection(AppController app) {
    final changed = !identical(_recordsToken, app.repo.snapshotToken);
    if (changed) {
      _recordsToken = app.repo.snapshotToken;
      _days = app.repo.allDays();
      _meals = app.repo.allMeals();
      _muscleDays = _days.map((k, v) => MapEntry(k, jsonMap(v)));
    }
    if (changed || _statsDate != app.today) {
      _statsDate = app.today;
      _stats = buildStats(app.today, null, null, days: _days, meals: _meals);
    }
  }

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/body_paths.json').then((value) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = context.pal;
        final review = weeklyReviewFor(app);
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
        final current =
            exercises.where((e) => e['ex'] == picked).firstOrNull ??
            exercises.firstOrNull;
        final points = current == null
            ? <Map<String, dynamic>>[]
            : jsonRows(current['points']);
        final bodyweight =
            points.isNotEmpty &&
            points.every((e) => jsNumber(e['weight']) == 0);
        final chart = chartPoints(
          bodyweight
              ? [
                  for (final e in points) {...e, 'e1': e['reps']},
                ]
              : points,
        );
        final last = points.lastOrNull;
        final bests = jsonRows(stats['bests']);
        return SingleChildScrollView(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: LText('进度', style: AppText.navDay(p)),
                  ),
                  Reveal(
                    visible: review != null,
                    child: review != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              WeeklyReviewCard(review: review),
                              const SizedBox(height: 12),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const BodyRouteCard(),
                  const SizedBox(height: 12),
                  Reveal(
                    visible: bodyPaths != null,
                    child: bodyPaths != null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: MuscleCard(
                              days: _muscleDays,
                              nowMs: app.clock().millisecondsSinceEpoch,
                              bodyPaths: bodyPaths!,
                              onOpen: (id) => openMuscleExercises(context, id),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const ReviewCard(),
                  const SizedBox(height: 12),
                  _weekOverview(week, target),
                  const SizedBox(height: 12),
                  StatBlock(
                    title: '动作曲线',
                    children: current == null
                        ? [
                            const SizedBox(height: 8),
                            LText(
                              '记过正式组之后，这里会画出每次的估算极限。',
                              style: AppText.hint(p),
                            ),
                          ]
                        : [
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final e in exercises)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Semantics(
                                        button: true,
                                        selected: e == current,
                                        label: AppMessages.of(context)
                                            .text('${e['ex']}'),
                                        child: Pressable(
                                          onTap: () => setState(
                                            () => picked = e['ex'] as String,
                                          ),
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minHeight: 44,
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: e == current
                                                  ? p.tintSoft
                                                  : p.fill,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: LText(
                                              '${e['ex']}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: e == current
                                                    ? p.tint
                                                    : p.text,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            LText(
                              bodyweight ? '次数' : '估算极限',
                              style: AppText.hint(p),
                            ),
                            FadeSwitcher(
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '${current['ex']}:${last?['iso']}',
                                ),
                                child: LText(
                                  bodyweight
                                      ? '${fmt(last!['reps'])} 次'
                                      : '${fmt(last!['e1'])} kg',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: p.text,
                                  ),
                                ),
                              ),
                            ),
                            LText(
                              bodyweight
                                  ? '最近一次 · ${shortDate(last['iso'])} · 自重 × ${fmt(last['reps'])} 次'
                                  : '最近一次估算极限 · ${shortDate(last['iso'])} · ${fmt(last['weight'])}×${fmt(last['reps'])}',
                              style: AppText.hint(p),
                            ),
                            FadeSwitcher(
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '${current['ex']}:${last['iso']}',
                                ),
                                child: Semantics(
                                  label: AppMessages.of(context).text(
                                    '${current['ex']} 的${bodyweight ? '次数' : '估算极限'}',
                                  ),
                                  image: true,
                                  child: SizedBox(
                                    height: 150,
                                    child: CustomPaint(
                                      painter: EstimateChart(
                                        jsonRows(chart['dots']),
                                        p.tint,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final e in [
                                  jsonRows(chart['list']).first,
                                  jsonRows(chart['list']).last,
                                ])
                                  LText(
                                    shortDate(e['iso']),
                                    style: AppText.hint(p),
                                  ),
                              ],
                            ),
                          ],
                  ),
                  const SizedBox(height: 12),
                  StatBlock(
                    title: '个人最佳',
                    children: [
                      if (bests.isEmpty)
                        LText('还没有正式组。', style: AppText.hint(p)),
                      for (final (index, b) in bests.indexed)
                        Reveal(
                          visible: allBests || index < 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: p.sep, width: .5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      LText(
                                        '${b['ex']}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: p.text,
                                        ),
                                      ),
                                      LText(
                                        jsNumber(b['heavy']) == 0
                                            ? shortDate(b['date'])
                                            : '极限 ${fmt(b['e1'])} · ${shortDate(b['date'])}',
                                        style: AppText.hint(p),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                LText(
                                  jsNumber(b['heavy']) == 0
                                      ? '自重 × ${fmt(b['heavyReps'])} 次'
                                      : '${fmt(b['heavy'])} kg × ${fmt(b['heavyReps'])}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: p.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (bests.length > 5)
                        FormButton(
                          allBests ? '收起' : '查看全部',
                          plain: true,
                          onTap: () => setState(() => allBests = !allBests),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _weekOverview(Map<String, dynamic> week, num target) {
    final app = context.app, p = context.pal;
    final days = jsonRows(week['days']), meals = app.repo.allMeals();
    final protein = days
        .where(
          (d) =>
              jsNumber(
                jsonMap(jsonMap(meals[d['iso']])['totals'])['protein'],
              ) >=
              app.proteinGoal,
        )
        .length;
    final kcal = days
        .where(
          (d) =>
              jsNumber(d['kcal']) >= app.kcalGoal * .9 &&
              jsNumber(d['kcal']) <= app.kcalGoal * 1.1,
        )
        .length;
    return StatBlock(
      title: '本周总览',
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            for (final item in [
              ('训练天数', '${week['trainDays']}/${fmt(target)}', p.tint),
              ('蛋白达标', '$protein/7', p.protein),
              ('热量在范围内', '$kcal/7', p.kcal),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 16, height: 3, color: item.$3),
                    const SizedBox(height: 8),
                    LText(
                      item.$2,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    LText(item.$1, style: AppText.hint(p)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final item in [('训练', 'sets', p.tint), ('饮食', 'kcal', p.kcal)])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(item.$1, style: AppText.hint(p)),
                    SizedBox(
                      height: 84,
                      child: CustomPaint(
                        painter: WeekBars(
                          [
                            for (final day in days)
                              {
                                ...day,
                                'label': AppMessages.of(context)
                                    .text('${day['label']}'),
                              },
                          ],
                          item.$2,
                          item.$3,
                          p,
                          DefaultTextStyle.of(context).style,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
