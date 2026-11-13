import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/ui/kit/body_figure.dart';
import 'package:leandaily/ui/sheets/muscle_exercises_sheet.dart';
import 'package:leandaily/ui/stats/muscle/body_map.dart';
import 'package:leandaily/ui/stats/muscle_brief_panel.dart';
import 'package:leandaily/ui/stats/body_route_card.dart';
import 'package:leandaily/ui/stats/progress_sections.dart';
import 'package:leandaily/ui/stats/strength_section.dart';

import 'support/harness.dart';

late Map<String, dynamic> _paths;

/// 在热力人体图上找一个能点中 [muscle] 的全局坐标（用和点击相同的命中逻辑）。
Offset _spot(WidgetTester tester, String muscle, {bool back = false}) {
  final rect = tester.getRect(
    find.descendant(
      of: find.byType(HeatHero),
      matching: find.byType(BodyFigure),
    ),
  );
  final half = Size(rect.width / 2, rect.height);
  final painter = BodyPainter(
    geometry: BodyGeometry(_paths),
    back: back,
    colors: const {},
    palette: tester.element(find.byType(HeatHero)).pal,
    selected: '',
  );
  final hits = <Offset>[];
  for (var y = 0.0; y < half.height; y += 2) {
    for (var x = 0.0; x < half.width; x += 2) {
      if (painter.muscleAt(Offset(x, y), half, slopPx: 0) == muscle) {
        hits.add(Offset(x, y));
      }
    }
  }
  if (hits.isNotEmpty) {
    // 取最靠近中心的命中点，避开边缘的取整误差。
    final mean =
        hits.fold(Offset.zero, (a, b) => a + b) / hits.length.toDouble();
    final best = hits.reduce(
      (a, b) => (a - mean).distance <= (b - mean).distance ? a : b,
    );
    return rect.topLeft + best + Offset(back ? half.width : 0, 0);
  }
  fail('no spot for $muscle');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Harness> _open(
  WidgetTester tester, {
  Size size = const Size(393, 1400),
  bool dark = false,
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final h = await Harness.pump(
    tester,
    tab: 2,
    size: size,
    dark: dark,
    locale: locale,
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    _paths = jsonDecode(
      await rootBundle.loadString('assets/muscle_map.json'),
    ) as Map<String, dynamic>;
    await BodyFigure.load();
  });

  testWidgets('tap a muscle expands a panel in place, tap again collapses', (
    tester,
  ) async {
    await _open(tester);
    BodyFigure.animateBreath = false;
    expect(find.byType(MuscleBriefPanel), findsNothing);
    await tester.tapAt(_spot(tester, 'chest'));
    await _settle(tester);
    expect(find.byType(MuscleBriefPanel), findsOneWidget);
    expect(find.text('怎么练它'), findsOneWidget);
    // 原地展开：没有弹出弹层。
    expect(find.byType(MuscleExercisesSheet), findsNothing);
    // 再点同一块肌肉收起。
    await tester.tapAt(_spot(tester, 'chest'));
    await _settle(tester);
    expect(find.byType(MuscleBriefPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small muscle (calves) is tappable; tapping elsewhere collapses',
    (tester) async {
      await _open(tester);
      // 小腿在背面更大，也在正面；各取一面验证。
      await tester.tapAt(_spot(tester, 'calves', back: true));
      await _settle(tester);
      expect(find.byType(MuscleBriefPanel), findsOneWidget);
      // 点别处（页面标题）收起。
      await tester.tapAt(tester.getCenter(find.text('进度').first));
      await _settle(tester);
      expect(find.byType(MuscleBriefPanel), findsNothing);
      // 点小肌肉边上 12 点内也算点中。
      final spot = _spot(tester, 'calves', back: true);
      await tester.tapAt(spot + const Offset(0, 12));
      await _settle(tester);
      expect(find.byType(MuscleBriefPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching muscle swaps the panel; link opens the sheet', (
    tester,
  ) async {
    await _open(tester);
    await tester.tapAt(_spot(tester, 'chest'));
    await _settle(tester);
    await tester.tapAt(_spot(tester, 'quads'));
    await _settle(tester);
    expect(find.byType(MuscleBriefPanel), findsOneWidget);
    expect(find.text('股四头肌'), findsOneWidget);
    await tester.tap(find.text('怎么练它'));
    await tester.pumpAndSettle();
    expect(find.byType(MuscleExercisesSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: expands and collapses without animation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester);
    await tester.tapAt(_spot(tester, 'chest'));
    await tester.pump();
    expect(find.byType(MuscleBriefPanel), findsOneWidget);
    await tester.tapAt(_spot(tester, 'chest'));
    await tester.pump();
    expect(find.byType(MuscleBriefPanel), findsNothing);
  });

  testWidgets('expansion animates when motion is allowed', (tester) async {
    await _open(tester);
    final before = tester.getSize(find.byType(HeatHero)).height;
    await tester.tapAt(_spot(tester, 'chest'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byType(HeatHero)).height;
    await _settle(tester);
    final after = tester.getSize(find.byType(HeatHero)).height;
    expect(mid, greaterThan(before));
    expect(mid, lessThan(after));
  });

  testWidgets('wide: weight sits in the left column to even out heights', (
    tester,
  ) async {
    await _open(tester, size: const Size(1024, 1500));
    final weight = tester.getTopLeft(find.byType(BodyRouteCard));
    final strength = tester.getTopLeft(find.byType(StrengthSection));
    final hero = tester.getTopLeft(find.byType(HeatHero));
    expect(weight.dx, lessThan(strength.dx));
    expect(weight.dy, greaterThan(hero.dy));
  });

  testWidgets('phone keeps the order hero, weight, strength', (tester) async {
    await _open(tester, size: const Size(393, 2200));
    final hero = tester.getTopLeft(find.byType(HeatHero)).dy;
    final weight = tester.getTopLeft(find.byType(BodyRouteCard)).dy;
    final strength = tester.getTopLeft(find.byType(StrengthSection)).dy;
    expect(hero, lessThan(weight));
    expect(weight, lessThan(strength));
  });

  final shots = {
    'light': (dark: false, en: false, size: const Size(393, 1500)),
    'dark': (dark: true, en: false, size: const Size(393, 1500)),
    'en': (dark: false, en: true, size: const Size(393, 1500)),
    'wide': (dark: false, en: false, size: const Size(1024, 768)),
  };
  for (final e in shots.entries) {
    testWidgets('screenshot ${e.key}', (tester) async {
      final h = await _open(
        tester,
        dark: e.value.dark,
        size: e.value.size,
        locale: e.value.en ? const Locale('en') : const Locale('zh', 'CN'),
      );
      debugDisableShadows = true;
      await tester.tapAt(_spot(tester, 'chest'));
      await _settle(tester);
      expect(find.byType(MuscleBriefPanel), findsOneWidget);
      await h.shot(tester, 'progress-heat-${e.key}');
      expect(tester.takeException(), isNull);
    });
  }
}
