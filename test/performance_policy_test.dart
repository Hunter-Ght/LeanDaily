import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/frame_trace.dart';
import 'package:leandaily/app/shell.dart';
import 'package:leandaily/ui/kit/render_effects.dart';
import 'package:leandaily/ui/log/log_page.dart';
import 'package:leandaily/ui/me/me_page.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/ui/stats/muscle/muscle_card.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await rootBundle.loadString('assets/body_paths.json');
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('compositing policy $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;

      await Harness.pump(tester, tab: 2);
      final android = platform == TargetPlatform.android;
      expect(RenderEffects.liveBlur, !android);
      expect(RenderEffects.sheetBackgroundTransform, !android);
      final filters = tester.widgetList<BackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(filters, isNotEmpty);
      expect(filters.every((f) => f.enabled == !android), isTrue);
      final transforms = find.ancestor(
        of: find.byType(PageHost),
        matching: find.byType(Transform),
      );
      expect(transforms.evaluate().length, android ? 0 : 1);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('pages mount on demand and hidden pages mute tickers', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    expect(find.byType(StatsPage, skipOffstage: false), findsNothing);
    expect(find.byType(LogPage, skipOffstage: false), findsNothing);
    expect(find.byType(MePage, skipOffstage: false), findsNothing);
    h.controller.setTab(2);
    await tester.pumpAndSettle();
    final statsState = tester.state(find.byType(StatsPage));
    expect(
      TickerMode.valuesOf(tester.element(find.byType(StatsPage))).enabled,
      isTrue,
    );
    h.controller.setTab(3);
    await tester.pumpAndSettle();
    final hidden = find.byType(StatsPage, skipOffstage: false);
    expect(tester.state(hidden), same(statsState));
    expect(TickerMode.valuesOf(tester.element(hidden)).enabled, isFalse);
    h.controller.setTab(2);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(StatsPage)), same(statsState));
  });

  testWidgets('history projection reused until records change', (tester) async {
    final h = await Harness.pump(tester, tab: 2, empty: true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    MuscleCard muscle() => tester.widget<MuscleCard>(find.byType(MuscleCard));
    final before = muscle().days;
    final token = h.controller.repo.snapshotToken;
    h.controller.setTab(3);
    await tester.pumpAndSettle();
    h.controller.setTab(2);
    await tester.pumpAndSettle();
    expect(muscle().days, same(before));
    expect(h.controller.repo.snapshotToken, same(token));
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '哑铃卧推',
      rows: [
        {'weight': 12, 'reps': 10, 'type': '正式'},
      ],
    );
    await tester.pumpAndSettle();
    expect(h.controller.repo.snapshotToken, isNot(same(token)));
    expect(muscle().days, isNot(same(before)));
    expect(find.bySemanticsLabel('哑铃卧推 的估算极限'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('unchanged muscle colors do not restart tween', (tester) async {
    final h = await Harness.pump(tester, tab: 2);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final tweens = find.descendant(
      of: find.byType(MuscleCard),
      matching: find.byWidgetPredicate((w) => w is TweenAnimationBuilder),
    );
    expect(tweens, findsOneWidget);
    final state = tester.state<ImplicitlyAnimatedWidgetState>(tweens);
    final before = state.animation.value;
    await h.controller.saveGoals({...h.controller.goals});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.animation.value, before);
    await tester.pumpAndSettle();
  });

  FrameTiming frame(int buildMs, int rasterMs) => FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: buildMs * 1000,
    rasterStart: buildMs * 1000,
    rasterFinish: (buildMs + rasterMs) * 1000,
    rasterFinishWallTime: 0,
  );
  test('frame budgets follow 60/90/120 Hz and distinguish UI/raster work', () {
    final frames = [frame(5, 6), frame(9, 10), frame(12, 18)];
    expect(FrameTrace.summarize(frames, 60)['pipelineOverBudget'], 1);
    expect(FrameTrace.summarize(frames, 90)['pipelineOverBudget'], 1);
    expect(FrameTrace.summarize(frames, 120)['pipelineOverBudget'], 2);
    expect(FrameTrace.summarize(frames, 60)['buildP90Ms'], 12);
    expect(FrameTrace.summarize(frames, 60)['rasterP90Ms'], 18);
    expect(FrameTrace.summarize([], 0)['budgetMs'], closeTo(16.667, .001));
  });
}
