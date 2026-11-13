import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/domain/units.dart';
import 'package:leandaily/ui/kit/number_field.dart';
import 'package:leandaily/ui/me/me_page.dart';
import 'package:leandaily/ui/onboarding/profile_steps.dart';
import 'package:leandaily/ui/onboarding/ruler.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

import 'support/harness.dart';

const en = Locale('en', 'US');

void imperial(FakeNative n) =>
    n.docs['android-settings'] = jsonEncode({'units': 'imperial'});

void seedPlan(FakeNative native) {
  final plan = jsonDecode(native.docs['fw-plan-v1']!) as Map;
  plan['workouts']['w3']['exercises'] = [
    {
      'id': 'test-load',
      'name': '哑铃地板卧推',
      'part': '胸',
      'sets': 2,
      'min': 10,
      'max': 12,
      'weight': 9.072, // 20 lb
      'unit': 'reps',
      'core': true,
      'rest': 90,
    },
  ];
  native.docs['fw-plan-v1'] = jsonEncode(plan);
  imperial(native);
}

Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);

  group('default and setting', () {
    testWidgets('existing users stay metric; the setting is in Me', (t) async {
      final h = await Harness.pump(t, tab: 3, region: 'US');
      expect(h.controller.units, Units.metric);
      expect(find.text('公制（kg · cm）'), findsOneWidget);
      await t.ensureVisible(find.text('单位'));
      await settle(t);
      await t.tap(find.text('单位'));
      await settle(t);
      await t.tap(find.text('英制（lb · ft in）'));
      await settle(t);
      expect(h.controller.units, Units.imperial);
      expect(
        jsonDecode(h.native.docs['android-settings']!)['units'],
        'imperial',
      );
      expect(find.text('英制（lb · ft in）'), findsOneWidget);
    });

    testWidgets('new installs follow the system region', (t) async {
      final us = await Harness.pump(t, newUser: true, region: 'US');
      expect(us.controller.units, Units.imperial);
      expect(find.text('lb · ft in'), findsOneWidget);
    });

    testWidgets('new install outside the US starts metric', (t) async {
      final cn = await Harness.pump(t, newUser: true, region: 'CN');
      expect(cn.controller.units, Units.metric);
    });

    testWidgets('finishing onboarding keeps the first-run default', (t) async {
      final h = await Harness.pump(t, newUser: true, region: 'US');
      await h.controller.skipOnboarding();
      expect(
        jsonDecode(h.native.docs['android-settings']!)['units'],
        'imperial',
      );
      expect(h.controller.units, Units.imperial);
    });
  });

  for (final (name, locale, dark) in [
    ('en', en, false),
    ('en-dark', en, true),
    ('zh', const Locale('zh', 'CN'), false),
  ]) {
    testWidgets('onboarding imperial rulers and switch ($name)', (t) async {
      final h = await Harness.pump(
        t,
        newUser: true,
        region: 'US',
        locale: locale,
        dark: dark,
      );
      expect(find.text('5 ft 9 in'), findsOneWidget);
      expect(find.text('155.0 lb'), findsOneWidget);
      await h.shot(t, 'units-onboarding-$name');
      // 切回公制：读数变 cm / kg
      await t.tap(find.text('kg · cm'));
      await settle(t);
      expect(h.controller.units, Units.metric);
      expect(find.text('175 cm'), findsOneWidget);
      expect(find.text('70.0 kg'), findsOneWidget);
      await t.tap(find.text('lb · ft in'));
      await settle(t);
      expect(find.text('5 ft 9 in'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'untouched rulers use whole imperial defaults, touched keep conversion',
    (t) async {
      await Harness.pump(t, newUser: true, region: 'US', locale: en);
      expect(find.text('5 ft 9 in'), findsOneWidget);
      expect(find.text('155.0 lb'), findsOneWidget);
      await t.tap(find.text('kg · cm'));
      await settle(t);
      expect(find.text('175 cm'), findsOneWidget);
      expect(find.text('70.0 kg'), findsOneWidget);
      await t.tap(find.text('lb · ft in'));
      await settle(t);
      expect(find.text('155.0 lb'), findsOneWidget);
      // 动过体重刻度尺后，切到公制按换算值，再切回英制仍是 lb 换算值而不是默认值
      await t.drag(
        find.descendant(
          of: find.byKey(const ValueKey('weightKg-imperial')),
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(-100, 0),
      );
      await settle(t);
      final moved = t
          .widgetList<Text>(find.textContaining(' lb'))
          .map((w) => w.data!)
          .single;
      expect(moved, isNot('155.0 lb'));
      await t.tap(find.text('kg · cm'));
      await settle(t);
      await t.tap(find.text('lb · ft in'));
      await settle(t);
      expect(find.text(moved), findsOneWidget);
      // 身高没动过，仍是整数默认值
      expect(find.text('5 ft 9 in'), findsOneWidget);
    },
  );

  for (final (size, locale, units) in [
    (const Size(393, 850), en, 'imperial'),
    (const Size(393, 850), en, 'metric'),
    (const Size(393, 850), const Locale('zh', 'CN'), 'imperial'),
    (const Size(360, 740), en, 'imperial'),
    (const Size(360, 740), en, 'metric'),
    (const Size(360, 740), const Locale('zh', 'CN'), 'imperial'),
    (const Size(360, 740), const Locale('zh', 'CN'), 'metric'),
  ]) {
    testWidgets(
      'onboarding step 1 fits without scrolling $size ${locale.languageCode} $units',
      (t) async {
        final h = await Harness.pump(
          t,
          newUser: true,
          size: size,
          locale: locale,
          seed: (n) =>
              n.docs['android-settings'] = jsonEncode({'units': units}),
        );
        final page = t.getRect(find.byType(IdentityStep));
        final privacy = t.getRect(
          find.textContaining(
            locale.languageCode == 'en' ? 'Privacy policy' : '隐私政策',
          ),
        );
        final next = t.getRect(
          find.bySemanticsLabel(
            locale.languageCode == 'en' ? 'Continue' : '继续',
          ),
        );
        final card = t.getRect(find.byType(ProfileRuler).last);
        final scroll = t.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(IdentityStep),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          scroll.position.maxScrollExtent,
          lessThanOrEqualTo(0.5),
          reason: 'step 1 scrolls',
        );
        // 隐私政策行固定在「继续」上方（滚动页之外）：卡片在它上面，它在主按钮上面，都在屏内。
        expect(card.bottom, lessThanOrEqualTo(page.bottom));
        expect(page.bottom, lessThanOrEqualTo(privacy.top + 1));
        expect(privacy.bottom, lessThanOrEqualTo(next.top + 1));
        expect(next.bottom, lessThanOrEqualTo(size.height));
        // 顶栏左侧留给「上一步」/ 备份恢复按钮：单位分段不在那里
        final unitSwitch = t.getRect(find.byType(UnitSwitch));
        expect(unitSwitch.top, greaterThan(page.top));
        expect(h.controller.units.id, units);
        await h.shot(
          t,
          'units-onboarding-fit-${size.width.toInt()}-${locale.languageCode}-$units',
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('ruler stores kg/cm from imperial drags', (t) async {
    final h = await Harness.pump(t, newUser: true, region: 'US', locale: en);
    final ruler = find.byKey(const ValueKey('weightKg-imperial'));
    await t.drag(
      find.descendant(of: ruler, matching: find.byType(SingleChildScrollView)),
      const Offset(-100, 0),
    );
    await settle(t);
    // 拖动后的读数是 lb；提交时按 kg 存进资料，切到公制应看到对应的 kg。
    final label = t
        .widgetList<Text>(find.textContaining(' lb'))
        .map((w) => w.data!)
        .single;
    final lbValue = double.parse(label.replaceAll(' lb', ''));
    expect(lbValue, greaterThan(154.3));
    await t.tap(find.text('kg · cm'));
    await settle(t);
    expect(
      find.text(
        '${Units.imperial.bodyWeightToKg(lbValue).toStringAsFixed(1)} kg',
      ),
      findsOneWidget,
    );
    expect(find.byType(ProfileRuler), findsNWidgets(3));
    expect(h.controller.units, Units.metric);
  });

  for (final (name, locale) in [('en', en), ('zh', const Locale('zh', 'CN'))]) {
    testWidgets('training mode shows lb and steps 2.5 / 5 ($name)', (t) async {
      final h = await Harness.pump(
        t,
        empty: true,
        seed: seedPlan,
        locale: locale,
        size: const Size(393, 852),
      );
      openTrainingMode(
        t.element(find.byType(TodayPage)),
        exerciseId: 'test-load',
      );
      await settle(t);
      if (find
          .text(name == 'en' ? 'Skip warm-up' : '跳过热身')
          .evaluate()
          .isNotEmpty) {
        await t.tap(find.text(name == 'en' ? 'Skip warm-up' : '跳过热身'));
        await settle(t);
      }
      final number = find.byWidgetPredicate(
        (w) => w is TrainingNumber && w.label == '重量',
      );
      String field() => t
          .widget<EditableText>(
            find.descendant(of: number, matching: find.byType(EditableText)),
          )
          .controller
          .text;
      expect(field(), '20');
      expect(find.text('lb'), findsWidgets);
      expect(find.textContaining('kg'), findsNothing);
      final plus = find.descendant(of: number, matching: find.text('+'));
      final minus = find.descendant(of: number, matching: find.text('−'));
      await t.tap(plus);
      await settle(t);
      expect(field(), '25');
      await t.tap(minus);
      await t.tap(minus);
      await settle(t);
      expect(field(), '17.5');
      await t.tap(plus);
      await settle(t);
      expect(field(), '20');
      await t.tap(plus);
      await settle(t);
      expect(field(), '25');
      await h.shot(t, 'units-training-$name');
      // 记一组：存的是 kg，25 lb = 11.34 kg
      await t.tap(find.text(name == 'en' ? 'Finish set 1' : '完成第 1 组'));
      await settle(t);
      final sets = (jsonDecode(h.native.docs['android-state']!)['sets'] as Map)
          .values
          .cast<Map>();
      expect(sets.single['w'], closeTo(11.34, 1e-9));
      expect(Units.imperial.loadValue(sets.single['w'] as num), 25);
      h.controller.rest.clear();
      await t.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('plan weight 5 kg reads 10 lb everywhere and saves that stage', (
    t,
  ) async {
    final h = await Harness.pump(
      t,
      empty: true,
      locale: en,
      size: const Size(393, 852),
      seed: (n) {
        seedPlan(n);
        final plan = jsonDecode(n.docs['fw-plan-v1']!) as Map;
        plan['workouts']['w3']['exercises'][0]['weight'] = 5;
        n.docs['fw-plan-v1'] = jsonEncode(plan);
      },
    );
    // 今日动作列表
    expect(find.textContaining('10 lb'), findsWidgets);
    expect(find.textContaining('11 lb'), findsNothing);
    openTrainingMode(
      t.element(find.byType(TodayPage)),
      exerciseId: 'test-load',
    );
    await settle(t);
    if (find.text('Skip warm-up').evaluate().isNotEmpty) {
      await t.tap(find.text('Skip warm-up'));
      await settle(t);
    }
    final number = find.byWidgetPredicate(
      (w) => w is TrainingNumber && w.label == '重量',
    );
    expect(
      t
          .widget<EditableText>(
            find.descendant(of: number, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '10',
    );
    expect(find.textContaining('10 lb'), findsWidgets);
    expect(find.textContaining('11 lb'), findsNothing);
    // 动作要点：建议重量也是 10 lb
    await t.tap(find.textContaining('Key points'));
    await settle(t);
    expect(find.text('10'), findsWidgets);
    expect(find.text('11'), findsNothing);
    Navigator.of(
      t.element(find.text('Dumbbell floor press').first),
      rootNavigator: true,
    ).pop();
    await settle(t);
    await t.tap(find.text('Finish set 1'));
    await settle(t);
    final sets = (jsonDecode(h.native.docs['android-state']!)['sets'] as Map)
        .values
        .cast<Map>();
    expect(sets.single['w'], Units.imperial.loadToKg(10));
    expect(Units.imperial.load(sets.single['w'] as num), '10');
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });

  for (final (name, locale) in [('en', en), ('zh', const Locale('zh', 'CN'))]) {
    testWidgets('progress page in lb ($name)', (t) async {
      final h = await Harness.pump(
        t,
        tab: 2,
        locale: locale,
        seed: (n) {
          imperial(n);
          n.docs['fw-body-v1'] = jsonEncode({
            'v': 1,
            'entries': [
              {'date': '2026-10-09', 'weightKg': 70.5},
              {'date': '2026-10-13', 'weightKg': 70.2},
              {'date': '2026-10-15', 'weightKg': 69.9},
            ],
          });
        },
      );
      await settle(t);
      expect(find.textContaining('kg'), findsNothing);
      expect(find.textContaining('lb'), findsWidgets);
      await h.shot(t, 'units-progress-$name');
      // 力量列表：最佳成绩、估算极限变化都写 lb
      await t.dragFrom(const Offset(200, 600), const Offset(0, -520));
      await settle(t);
      expect(find.textContaining('kg'), findsNothing);
      await h.shot(t, 'units-progress-strength-$name');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('body log in lb stores kg and shows lb (en)', (t) async {
    final h = await Harness.pump(
      t,
      tab: 3,
      locale: en,
      size: const Size(393, 852),
      seed: (n) {
        imperial(n);
        n.docs['fw-profile-v1'] = jsonEncode({'weightKg': 70, 'waistCm': 80});
      },
    );
    openBodyLog(t.element(find.byType(MePage)));
    await settle(t);
    final input = find.descendant(
      of: find.byType(SheetInput).first,
      matching: find.byType(EditableText),
    );
    expect(t.widget<EditableText>(input).controller.text, '154.3');
    await t.enterText(input, '180.5');
    await h.shot(t, 'units-body-log-en');
    await t.tap(find.text('Save'));
    await settle(t);
    final doc = jsonDecode(h.native.docs['fw-body-v1']!);
    final kg = doc['entries'].last['weightKg'] as num;
    expect(kg, closeTo(81.873, 1e-9));
    expect(Units.imperial.bodyWeight(kg), '180.5');
    expect(find.textContaining('Logged 180.5 lb'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('body log rejects out-of-range lb with an lb message', (t) async {
    await Harness.pump(t, tab: 3, seed: imperial);
    openBodyLog(t.element(find.byType(MePage)));
    await settle(t);
    final input = find.descendant(
      of: find.byType(SheetInput).first,
      matching: find.byType(EditableText),
    );
    await t.enterText(input, '40');
    await t.tap(find.text('保存'));
    await settle(t);
    expect(find.textContaining('67–551 lb'), findsOneWidget);
  });

  for (final tab in [0, 1]) {
    testWidgets('today and log pages write lb, never kg (tab $tab)', (t) async {
      final h = await Harness.pump(t, tab: tab, seed: imperial);
      await settle(t);
      expect(find.textContaining('kg'), findsNothing);
      expect(find.textContaining('cm'), findsNothing);
      await h.shot(t, 'units-tab$tab-zh');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('metric stays untouched for existing users', (t) async {
    final h = await Harness.pump(t, tab: 3);
    openBodyLog(t.element(find.byType(MePage)));
    await settle(t);
    expect(find.text('kg'), findsWidgets);
    expect(find.textContaining('lb'), findsNothing);
    expect(h.controller.units, Units.metric);
  });
}
