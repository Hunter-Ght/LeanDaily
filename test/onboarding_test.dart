import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/onboarding/ruler.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/ui/onboarding/onboarding_flow.dart';
import 'package:leandaily/ui/onboarding/diagnosis_step.dart';
import 'package:leandaily/ui/onboarding/body_fat_step.dart';
import 'package:leandaily/ui/onboarding/plan_step.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/onboarding/onboarding_widgets.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('继续'));
  await settle(tester);
}

Future<void> showPlanItem(
  WidgetTester tester,
  String label, {
  double delta = 250,
}) async {
  final finder = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(PlanStep),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });

  testWidgets('unknown body fat estimates and quick start saves defaults', (
    tester,
  ) async {
    final h = await Harness.pump(tester, newUser: true);
    await next(tester);
    expect(find.bySemanticsLabel('我不知道'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '我不知道',
            ),
          )
          .properties
          .selected,
      isTrue,
    );
    expect(find.text('粗略估算 · BMI 公式'), findsOneWidget);
    expect(find.textContaining('误差 ±5%'), findsOneWidget);
    expect(h.native.docs['fw-profile-v1'], isNull);
    await tester.tap(find.bySemanticsLabel('用默认设置，直接开始'));
    await settle(tester);
    expect(jsonDecode(h.native.docs['fw-profile-v1']!)['bodyFatMethod'], 'bmi');
    expect(h.controller.profile!['venue'], 'bodyweight');
    expect(h.controller.library.items, hasLength(1));
    expect(h.native.docs['fw-onboarded-v1'], '1');
  });

  testWidgets('upgrade quick start preserves plan', (tester) async {
    final h = await Harness.pump(tester);
    final before = h.native.docs['fw-plan-v1'];
    final count = h.controller.library.items.length;
    openOnboarding(tester.element(find.byType(Navigator)), upgrade: true);
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('用默认设置，直接开始'));
    await settle(tester);
    expect(h.native.docs['fw-profile-v1'], isNotNull);
    expect(h.native.docs['fw-plan-v1'], before);
    expect(h.controller.library.items, hasLength(count));
  });

  testWidgets(
    '640 height disclaimer clears button and goal editor reveals floor',
    (tester) async {
      await Harness.pump(tester, newUser: true, size: const Size(393, 640));
      await next(tester);
      await next(tester);
      expect(find.byType(GoalBodyFatSlider), findsNothing);
      final scroll = find.descendant(
        of: find.byType(DiagnosisStep),
        matching: find.byType(Scrollable),
      );
      final disclaimer = find.byKey(const ValueKey('diagnosis-disclaimer'));
      await tester.scrollUntilVisible(disclaimer, 120, scrollable: scroll);
      await settle(tester);
      final rect = tester.getRect(disclaimer);
      expect(rect.top, greaterThanOrEqualTo(64));
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.getRect(find.bySemanticsLabel('继续')).top),
      );
      await tester.ensureVisible(find.bySemanticsLabel('调整目标体脂'));
      await tester.tap(find.bySemanticsLabel('调整目标体脂'));
      await settle(tester);
      final floor = find.text('目标体脂安全下限：8%');
      await tester.scrollUntilVisible(floor, 120, scrollable: scroll);
      expect(find.byType(GoalBodyFatSlider), findsOneWidget);
      expect(floor, findsOneWidget);
    },
  );

  for (final dark in [false, true]) {
    for (final size in [const Size(393, 852), const Size(360, 640)]) {
      testWidgets('route and plan clear fixed footer $size dark=$dark', (
        tester,
      ) async {
        final h = await Harness.pump(
          tester,
          newUser: true,
          dark: dark,
          size: size,
          seed: (native) => native.docs['fw-profile-v1'] = jsonEncode({
            ...profileDefaults,
            'sex': 'female',
            'weightKg': 70,
            'bodyFatPct': 30,
            'bodyFatMethod': 'manual',
            'goalBodyFatPct': 20,
          }),
        );
        await next(tester);
        await next(tester);
        final scheme = dark ? 'dark' : 'light';
        final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
        await h.shot(tester, 'r-onb-3-female-$dimensions-$scheme');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('diagnosis-disclaimer')),
          100,
          scrollable: find.descendant(
            of: find.byType(DiagnosisStep),
            matching: find.byType(Scrollable),
          ),
        );
        await settle(tester);
        expect(
          tester
              .getBottomRight(
                find.byKey(const ValueKey('diagnosis-disclaimer')),
              )
              .dy,
          lessThanOrEqualTo(tester.getTopLeft(find.bySemanticsLabel('继续')).dy),
        );
        final diagnosisScroll = find.descendant(
          of: find.byType(DiagnosisStep),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (w) => w is OnboardingButton && w.label == '调整目标体脂',
          ),
          -100,
          scrollable: diagnosisScroll,
        );
        await tester.tap(find.bySemanticsLabel('调整目标体脂'));
        await settle(tester);
        await tester.scrollUntilVisible(
          find.text('目标体脂安全下限：16%'),
          100,
          scrollable: diagnosisScroll,
        );
        expect(
          tester.getBottomRight(find.text('目标体脂安全下限：16%')).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.bySemanticsLabel('继续')).dy),
        );
        await next(tester);
        expect(find.text('活动量'), findsNothing);
        expect(find.text('不方便的部位'), findsNothing);
        final days = [
          for (var n = 2; n <= 6; n++) find.bySemanticsLabel('$n 天'),
        ];
        final dayRects = [for (final day in days) tester.getRect(day)];
        for (final rect in dayRects) {
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(rect.width, greaterThanOrEqualTo(44));
          expect(rect.width, closeTo(dayRects.first.width, .01));
          expect(rect.top, dayRects.first.top);
        }
        final card = find.descendant(
          of: find.byType(PlanStep),
          matching: find.byWidgetPredicate(
            (w) => w is PlanCard && w.size == PlanCardSize.large,
          ),
        );
        await tester.scrollUntilVisible(
          card,
          100,
          scrollable: find
              .descendant(
                of: find.byType(PlanStep),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await settle(tester);
        final start = tester.getRect(find.bySemanticsLabel('开始'));
        final skip = tester.getRect(find.bySemanticsLabel('稍后再选，先用推荐的'));
        expect(skip.top - start.bottom, greaterThanOrEqualTo(10));
        expect(tester.getRect(card).bottom, lessThanOrEqualTo(start.top - 12));
        expect(tester.getRect(card).top, greaterThanOrEqualTo(60));
        await h.shot(tester, 'r-onb-4-$dimensions-$scheme');
        await showPlanItem(tester, '更多设置 ›', delta: -100);
        await tester.tap(find.bySemanticsLabel('更多设置 ›'));
        await settle(tester);
        await showPlanItem(tester, '肩', delta: 100);
        await tester.tap(find.bySemanticsLabel('肩'));
        await settle(tester);
        expect(find.text('活动量'), findsOneWidget);
        expect(find.text('不方便的部位'), findsOneWidget);
        await showPlanItem(tester, '收起更多设置', delta: -100);
        await tester.tap(find.bySemanticsLabel('收起更多设置'));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel('开始'));
        await settle(tester);
        expect(jsonDecode(h.native.docs['fw-profile-v1']!)['limits'], ['肩']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final current in [3, 50, 11]) {
    testWidgets('scale clamps markers and separates close labels $current', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: AppPalette.light.bg,
          builder: (context, _) => PaletteScope(
            palette: AppPalette.light,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox(
                  width: 280,
                  child: BodyFatScale(current: current, goal: 11, male: true),
                ),
              ),
            ),
          ),
        ),
      );
      final scale = tester.getRect(find.byType(BodyFatScale));
      for (final name in ['current', 'goal']) {
        final marker = tester.getRect(
          find.byKey(ValueKey('body-fat-$name-marker')),
        );
        expect(marker.width, 22);
        expect(marker.left, greaterThanOrEqualTo(scale.left));
        expect(marker.right, lessThanOrEqualTo(scale.right));
      }
      expect(
        tester.getSize(find.byKey(const ValueKey('body-fat-rail'))).height,
        14,
      );
      final currentLabel = tester.getRect(find.text('你现在 $current%'));
      final goalLabel = tester.getRect(find.text('目标 11%'));
      expect(currentLabel.overlaps(goalLabel), isFalse);
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    for (final route in ['cut', 'bulk', 'female']) {
      testWidgets('route screenshot $route $dark', (tester) async {
        final sample = {
          ...profileDefaults,
          'sex': route == 'female' ? 'female' : 'male',
          'weightKg': route == 'bulk' ? 45 : 100,
          'bodyFatPct': route == 'bulk' ? 12 : 30,
          if (route == 'female') 'goalBodyFatPct': 20,
          'bodyFatMethod': 'manual',
        };
        final h = await Harness.pump(
          tester,
          newUser: true,
          dark: dark,
          size: const Size(393, 852),
          seed: (native) => native.docs['fw-profile-v1'] = jsonEncode(sample),
        );
        await next(tester);
        await next(tester);
        expect(
          find.text(stageName(buildTargets(sample)['stage'] as String)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DiagnosisStep),
            matching: find.textContaining('±0'),
          ),
          findsNothing,
        );
        expect(
          find.text('体脂 ${route == 'bulk' ? 12 : 30}%（手动输入）'),
          findsOneWidget,
        );
        if (route == 'female') {
          expect(
            tester.widget<BodyFatScale>(find.byType(BodyFatScale)).goal,
            20,
          );
        }
        await h.shot(tester, 'r-onb-3-$route-${dark ? 'dark' : 'light'}');
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'four steps, screenshots and persistent completion ${dark ? 'dark' : 'light'}',
      (tester) async {
        final h = await Harness.pump(
          tester,
          newUser: true,
          dark: dark,
          size: const Size(393, 852),
        );
        final scheme = dark ? 'dark' : 'light';
        expect(find.byType(OnboardingFlow), findsOneWidget);
        expect(h.native.docs['fw-profile-v1'], isNull);
        for (var step = 1; step <= 4; step++) {
          await h.shot(tester, 'r-onb-$step-$scheme');
          if (step < 4) await next(tester);
        }
        await tester.tap(find.bySemanticsLabel('开始'));
        await settle(tester);
        final profile = jsonDecode(h.native.docs['fw-profile-v1']!) as Map;
        expect(profile['sex'], 'male');
        expect(profile['age'], 30);
        expect(profile['bodyFatMethod'], 'bmi');
        expect(h.native.docs['fw-onboarded-v1'], '1');
        final library = jsonDecode(h.native.docs['fw-plans-v1']!) as Map;
        expect(library['items'], hasLength(1));
        expect(library['activeId'], library['items'][0]['id']);
        expect(
          jsonDecode(h.native.docs['fw-plan-v1']!),
          library['items'][0]['plan'],
        );
        expect(find.byType(OnboardingFlow), findsNothing);
      },
    );
  }

  testWidgets(
    'new user skip resets conservative defaults and still selects a plan',
    (tester) async {
      final h = await Harness.pump(tester, newUser: true);
      await tester.tap(find.bySemanticsLabel('女'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('跳过'));
      await settle(tester);
      expect(find.text('训练安排'), findsOneWidget);
      expect(h.native.docs['fw-onboarded-v1'], isNull);
      await tester.tap(find.bySemanticsLabel('稍后再选，先用推荐的'));
      await settle(tester);
      final p = jsonDecode(h.native.docs['fw-profile-v1']!) as Map;
      expect(p['sex'], 'male');
      expect(p['age'], 30);
      expect(p['heightCm'], 175);
      expect(p['weightKg'], 70);
      expect(p['bodyFatMethod'], 'bmi');
      expect(h.native.docs['fw-plans-v1'], isNotNull);
      expect(h.native.docs['fw-onboarded-v1'], '1');
    },
  );

  for (final skip in [false, true]) {
    testWidgets(
      'upgrade ${skip ? 'skip' : 'complete'} leaves legacy plan bytes unchanged',
      (tester) async {
        final h = await Harness.pump(
          tester,
          seed: (native) => native.docs.remove('fw-onboarded-v1'),
        );
        final before = h.native.docs['fw-plan-v1'];
        final progress = h.native.docs['fw-progress-v1'];
        openOnboarding(tester.element(find.byType(Navigator)), upgrade: true);
        await settle(tester);
        expect(find.text('体脂'), findsOneWidget);
        if (skip) {
          await tester.tap(find.bySemanticsLabel('跳过'));
        } else {
          await tester.tap(find.bySemanticsLabel('上一步'));
          await settle(tester);
          await tester.tap(find.bySemanticsLabel('女'));
          await settle(tester);
          await next(tester);
          await next(tester);
          await next(tester);
          await showPlanItem(tester, '保留我现有的计划');
          expect(find.bySemanticsLabel('保留我现有的计划'), findsOneWidget);
          await tester.tap(find.bySemanticsLabel('保留计划，完成评估'));
        }
        await settle(tester);
        expect(h.native.docs['fw-plan-v1'], before);
        expect(h.native.docs['fw-progress-v1'], progress);
        expect(h.native.docs['fw-onboarded-v1'], '1');
        expect(h.native.docs['fw-profile-v1'], skip ? isNull : isNotNull);
        if (!skip) {
          expect(
            (jsonDecode(h.native.docs['fw-profile-v1']!) as Map)['sex'],
            'female',
          );
        }
        expect(find.byType(OnboardingFlow), findsNothing);
      },
    );
  }

  testWidgets('upgrade can add template without activating it', (tester) async {
    final h = await Harness.pump(tester);
    final before = h.native.docs['fw-plan-v1'];
    final active = h.controller.library.activeId;
    openOnboarding(tester.element(find.byType(Navigator)), upgrade: true);
    await settle(tester);
    for (var i = 0; i < 2; i++) {
      await next(tester);
    }
    await tester.tap(find.bySemanticsLabel('两边都会去'));
    await settle(tester);
    await showPlanItem(tester, '选这个方案');
    await tester.tap(find.bySemanticsLabel('选这个方案'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('另外添加，完成评估'));
    await settle(tester);
    expect(h.native.docs['fw-plan-v1'], before);
    expect(h.controller.library.activeId, active);
    expect(
      (jsonDecode(h.native.docs['fw-plans-v1']!) as Map)['items'],
      hasLength(2),
    );
  });

  for (final sample in [
    {
      'sex': 'male',
      'weightKg': 100,
      'bodyFatPct': 30,
      'bodyFatMethod': 'manual',
    },
    {'sex': 'female', 'bodyFatPct': 30, 'bodyFatMethod': 'manual'},
    {'weightKg': 45, 'bodyFatPct': 12, 'bodyFatMethod': 'manual'},
    {'bodyFatPct': 6, 'bodyFatMethod': 'manual', 'goalBodyFatPct': 3},
    {'age': 16, 'bodyFatPct': 30, 'bodyFatMethod': 'manual'},
  ]) {
    testWidgets('diagnosis renders domain stage and warnings $sample', (
      tester,
    ) async {
      final p =
          normalizeProfile({...profileDefaults, ...sample})['profile']
              as Profile;
      final targets = buildTargets(p);
      await Harness.pump(
        tester,
        newUser: true,
        seed: (native) => native.docs['fw-profile-v1'] = jsonEncode(p),
      );
      for (var i = 0; i < 2; i++) {
        await next(tester);
      }
      expect(find.text(stageName(targets['stage'] as String)), findsOneWidget);
      expect(find.text(routeText(targets['stage'] as String)), findsOneWidget);
      for (final warning in targets['warnings'] as List) {
        if ((warning as String).startsWith('体脂为估算值')) continue;
        await tester.scrollUntilVisible(
          find.text(warning),
          150,
          scrollable: find.descendant(
            of: find.byType(DiagnosisStep),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(warning), findsOneWidget);
      }
    });
  }

  testWidgets(
    'manual body fat blocks invalid ranges and supports backward drag',
    (tester) async {
      final h = await Harness.pump(tester, newUser: true);
      await next(tester);
      await tester.tap(find.bySemanticsLabel('我知道'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText), '80');
      await settle(tester);
      expect(find.text('请填写有效范围内的数值'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('继续'));
      await settle(tester);
      expect(find.text('体脂'), findsOneWidget);
      await tester.drag(find.text('体脂'), const Offset(-250, 0));
      await settle(tester);
      expect(find.text('体脂'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('上一步'));
      await settle(tester);
      expect(find.text('基本信息'), findsOneWidget);
      await next(tester);
      expect(find.text('体脂'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '18.5');
      await settle(tester);
      await next(tester);
      expect(find.text('你的路线'), findsOneWidget);
      await tester.drag(find.text('你的路线'), const Offset(300, 0));
      await settle(tester);
      expect(find.text('体脂'), findsOneWidget);
      expect(h.native.docs['fw-profile-v1'], isNull);
    },
  );

  testWidgets('female measurements estimate and persist Navy body fat', (
    tester,
  ) async {
    final h = await Harness.pump(tester, newUser: true);
    await tester.tap(find.bySemanticsLabel('女'));
    await settle(tester);
    await next(tester);
    await tester.tap(find.bySemanticsLabel('量一量'));
    await settle(tester);
    for (final (i, value) in ['90', '34', '100'].indexed) {
      await tester.enterText(find.byType(EditableText).at(i), value);
      await settle(tester);
    }
    final expected = estimateBodyFat({
      ...profileDefaults,
      'sex': 'female',
      'bodyFatMethod': 'navy',
      'waistCm': 90,
      'neckCm': 34,
      'hipCm': 100,
    });
    expect(find.text('约 ${expected['value']}%（误差 ±3%）'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await next(tester);
    }
    await tester.tap(find.bySemanticsLabel('开始'));
    await settle(tester);
    final p = jsonDecode(h.native.docs['fw-profile-v1']!) as Map;
    expect(p['sex'], 'female');
    expect(p['bodyFatMethod'], 'navy');
    expect(p['hipCm'], 100);
    expect(p['waistCm'], 90);
    expect(p['neckCm'], 34);
  });

  testWidgets('picker stores the selected band and preview switches venues', (
    tester,
  ) async {
    final h = await Harness.pump(tester, newUser: true);
    await next(tester);
    await tester.tap(find.bySemanticsLabel('看图选'));
    await settle(tester);
    final band = find.bySemanticsLabel('约 20%');
    await tester.drag(
      find
          .descendant(
            of: find.byType(BodyFatStep),
            matching: find.byType(ListView),
          )
          .last,
      const Offset(-300, 0),
    );
    await settle(tester);
    await tester.tap(band);
    await settle(tester);
    expect(find.text('约 20.0%（误差 ±4%）'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await next(tester);
    }
    await tester.tap(find.bySemanticsLabel('两边都会去'));
    await settle(tester);
    await showPlanItem(tester, '选这个方案');
    await tester.tap(find.bySemanticsLabel('选这个方案'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('预览每天练什么'));
    await settle(tester);
    await tester.ensureVisible(find.text('健身房版'));
    await tester.tap(find.text('健身房版'));
    await settle(tester);
    expect(find.textContaining('上斜哑铃卧推'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('使用这个方案'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('开始').last);
    await settle(tester);
    final p = jsonDecode(h.native.docs['fw-profile-v1']!) as Map;
    expect(p['bodyFatMethod'], 'picker');
    expect(p['bodyFatPct'], 20);
  });

  testWidgets(
    'page drag uses date-paging threshold and can interrupt a spring',
    (tester) async {
      await Harness.pump(tester, newUser: true);
      await tester.drag(find.text('基本信息'), const Offset(-90, 0));
      await settle(tester);
      expect(find.text('基本信息'), findsOneWidget);
      await tester.drag(find.text('基本信息'), const Offset(-170, 0));
      await settle(tester);
      expect(find.text('体脂'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('继续'));
      await tester.pump(const Duration(milliseconds: 60));
      final gesture = await tester.startGesture(const Offset(180, 190));
      await gesture.moveBy(const Offset(180, 0));
      await gesture.up();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('继续'), findsOneWidget);
    },
  );

  testWidgets('keyboard keeps the continue button above its inset', (
    tester,
  ) async {
    await Harness.pump(tester, newUser: true);
    await next(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    final button = find.bySemanticsLabel('继续');
    expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(550));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pump();
  });

  testWidgets('failed save restores controls and can be retried', (
    tester,
  ) async {
    final h = await Harness.pump(tester, newUser: true);
    await tester.tap(find.bySemanticsLabel('跳过'));
    await settle(tester);
    h.native.failNextPut = StateError('test disk failure');
    await tester.tap(find.bySemanticsLabel('开始'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(h.native.docs['fw-onboarded-v1'], isNull);
    await tester.tap(find.bySemanticsLabel('开始'));
    await settle(tester);
    expect(h.native.docs['fw-onboarded-v1'], '1');
    expect(h.native.docs['fw-plans-v1'], isNotNull);
  });

  for (final spec in [
    ('年龄', '岁', 10.0, 90.0, 1.0),
    ('身高', 'cm', 120.0, 230.0, 1.0),
    ('体重', 'kg', 30.0, 250.0, .1),
  ]) {
    testWidgets('ruler actual profile bounds ${spec.$1}', (tester) async {
      var value = spec.$3;
      await tester.pumpWidget(
        WidgetsApp(
          color: AppPalette.light.bg,
          builder: (context, _) => PaletteScope(
            palette: AppPalette.light,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: ProfileRuler(
                    label: spec.$1,
                    unit: spec.$2,
                    value: value,
                    min: spec.$3,
                    max: spec.$4,
                    step: spec.$5,
                    onChanged: (v) => value = v,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-30000, 0),
      );
      await tester.pumpAndSettle();
      expect(value, spec.$4);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(30000, 0),
      );
      await tester.pumpAndSettle();
      expect(value, spec.$3);
    });
  }

  testWidgets('ruler clamps flings and snaps to tenths at both bounds', (
    tester,
  ) async {
    var value = 30.0;
    await tester.pumpWidget(
      WidgetsApp(
        color: AppPalette.light.bg,
        builder: (context, _) => PaletteScope(
          palette: AppPalette.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 320,
                child: ProfileRuler(
                  label: '体重',
                  unit: 'kg',
                  value: value,
                  min: 30,
                  max: 31,
                  step: .1,
                  onChanged: (next) => value = next,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(value, 31);
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(600, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(value, 30);
  });
}
