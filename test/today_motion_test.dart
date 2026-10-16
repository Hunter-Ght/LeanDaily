import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/ui/today/today_hero.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/today_tip_card.dart';
import 'package:leandaily/ui/today/today_widgets.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;
import 'today_sheets_test.dart' show loadExerciseImages;

import 'dart:convert';

import 'package:leandaily/ui/today/today_actions.dart';
import 'package:leandaily/ui/today/today_nutrition_strip.dart';

bool intermediate(WidgetTester tester, Finder scope) => tester
    .widgetList<FadeTransition>(
      find.descendant(of: scope, matching: find.byType(FadeTransition)),
    )
    .any((w) => w.opacity.value > 0 && w.opacity.value < 1);

Future<void> frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('tip priority replacement, expansion and removal animate', (
    tester,
  ) async {
    final h = await Harness.pump(tester, size: const Size(393, 2400));
    await h.controller.patchDayState(h.controller.today, {'ready': 'bad'});
    await frame(tester);
    expect(intermediate(tester, find.byKey(const ValueKey('tips'))), isTrue);
    expect(find.text('身体不舒服就别硬练'), findsOneWidget);
    await tester.pumpAndSettle();
    await h.controller.patchDayState(h.controller.today, {'ready': 'tired'});
    await frame(tester);
    expect(find.text('身体不舒服就别硬练'), findsOneWidget);
    expect(find.text('今天有点累'), findsOneWidget);
    expect(intermediate(tester, find.byKey(const ValueKey('tips'))), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('条提示 ›'));
    await frame(tester);
    expect(intermediate(tester, find.byKey(const ValueKey('tips'))), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(TodayTipCard), findsWidgets);
    await tester.tap(find.text('收起提示'));
    await frame(tester);
    expect(intermediate(tester, find.byKey(const ValueKey('tips'))), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(TodayTipCard), findsOneWidget);
    await h.controller.patchDayState(h.controller.today, {'ready': null});
    await tester.pumpAndSettle();
    final s = TodayModel(h.controller).suggestions.first;
    await h.controller.declineSuggestion(s);
    await frame(tester);
    expect(intermediate(tester, find.byKey(const ValueKey('tips'))), isTrue);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('hero counts, bar and completion interpolate locally', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2400),
    );
    final hero = find.byType(TodayHero);
    final model = TodayModel(h.controller);
    final first = jsonMap(model.items.first['ex']);
    await h.controller.repo.addSets(
      date: model.iso,
      part: '${first['part']}',
      exercise: '${first['name']}',
      rows: [
        {'weight': 0, 'reps': 10, 'type': '正式'},
      ],
    );
    await frame(tester);
    final count = tester.widget<TweenAnimationBuilder<double>>(
      find
          .descendant(
            of: hero,
            matching: find.byType(TweenAnimationBuilder<double>),
          )
          .first,
    );
    expect(count.tween.end, 1);
    final number = tester
        .widget<Text>(
          find
              .descendant(
                of: hero,
                matching: find.byWidgetPredicate(
                  (w) => w is Text && w.textSpan != null,
                ),
              )
              .first,
        )
        .textSpan!
        .toPlainText();
    expect(number, isNot(startsWith('1 /')));
    final bar = find.descendant(of: hero, matching: find.byType(TodayBar));
    final width = tester
        .widget<FractionallySizedBox>(
          find.descendant(of: bar, matching: find.byType(FractionallySizedBox)),
        )
        .widthFactor!;
    expect(width, greaterThan(0));
    expect(width, lessThan(1 / jsNumber(model.prog['totalSets'])));
    await tester.pumpAndSettle();
    final current = TodayModel(h.controller);
    for (final item in current.items) {
      final e = jsonMap(item['ex']);
      final missing =
          jsNumber(current.before['${e['id']}']!['sets']).toInt() -
          jsNumber(item['done']).toInt();
      if (missing <= 0) continue;
      await h.controller.repo.addSets(
        date: current.iso,
        part: '${e['part']}',
        exercise: '${e['name']}',
        rows: [
          for (var i = 0; i < missing; i++)
            {'weight': 0, 'reps': 10, 'type': '正式'},
        ],
      );
    }
    await frame(tester);
    expect(TodayModel(h.controller).complete, isTrue);
    expect(intermediate(tester, hero), isTrue);
    expect(find.text('继续训练'), findsOneWidget);
    expect(find.textContaining('今天练完了'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('继续训练'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('nutrition profile, frequent foods and protein goal reveal', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2600),
    );
    final strip = find.byType(TodayNutritionStrip);
    await h.controller.setProfile(fourProfile());
    await frame(tester);
    expect(intermediate(tester, strip), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('展开营养条带')));
    await frame(tester);
    expect(intermediate(tester, strip), isTrue);
    await tester.pumpAndSettle();
    expect(find.textContaining('还差约'), findsOneWidget);
    await h.controller.repo.saveMeal(
      date: h.controller.today,
      meal: '午餐',
      source: '手动填写',
      items: [
        {'name': '鸡蛋', 'kcal': 140, 'protein': h.controller.proteinGoal + 1},
      ],
    );
    await frame(tester);
    expect(intermediate(tester, strip), isTrue);
    expect(find.textContaining('还差约'), findsOneWidget);
    expect(find.text('鸡蛋'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('还差约'), findsNothing);
    final meal = jsonRows(h.controller.repo.meals(h.controller.today)['meals'])
        .first;
    await h.controller.repo.deleteMeal(
      h.controller.today,
      '${meal['record_id']}',
    );
    await frame(tester);
    expect(intermediate(tester, strip), isTrue);
    await tester.pumpAndSettle();
    expect(find.textContaining('还差约'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'exercise status, warmup and rules fade while state survives notifications',
    (tester) async {
      final h = await Harness.pump(
        tester,
        empty: true,
        size: const Size(393, 2600),
      );
      final actions = find.byType(TodayActions);
      final state = tester.state(actions);
      final model = TodayModel(h.controller);
      await h.controller.patchDayState(model.iso, {'warm': true});
      await frame(tester);
      expect(intermediate(tester, actions), isTrue);
      await tester.pumpAndSettle();
      final e = jsonMap(model.items.first['ex']);
      await h.controller.repo.addSets(
        date: model.iso,
        part: '${e['part']}',
        exercise: '${e['name']}',
        rows: [
          {'weight': 0, 'reps': 10, 'type': '正式'},
        ],
      );
      await frame(tester);
      expect(intermediate(tester, actions), isTrue);
      await tester.pumpAndSettle();
      final target = model.before['${e['id']}']!;
      final remaining = jsNumber(target['sets']).toInt() - 1;
      await h.controller.repo.addSets(
        date: model.iso,
        part: '${e['part']}',
        exercise: '${e['name']}',
        rows: [
          for (var i = 0; i < remaining; i++)
            {'weight': 0, 'reps': 10, 'type': '正式'},
        ],
      );
      await frame(tester);
      expect(intermediate(tester, actions), isTrue);
      expect(find.byKey(const ValueKey('complete')), findsWidgets);
      await tester.pumpAndSettle();
      final rule = find.textContaining('今天要记住的');
      await tester.tap(rule);
      await frame(tester);
      expect(intermediate(tester, actions), isTrue);
      await tester.pumpAndSettle();
      await h.controller.patchDayState(model.iso, {'ready': 'bad'});
      await tester.pumpAndSettle();
      expect(tester.state(actions), same(state));
      expect(
        find.text((model.workout['rules'] as List).join('\n')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('today scroll position survives controller notifications', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    final list = tester.widget<ListView>(find.byType(ListView).first);
    list.controller!.jumpTo(200);
    await tester.pumpAndSettle();
    final offset = list.controller!.offset;
    await h.controller.patchDayState(h.controller.today, {'warm': true});
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListView>(find.byType(ListView).first).controller,
      same(list.controller),
    );
    expect(list.controller!.offset, offset);
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('today transitions honor reduced motion and rapid tip reversal', (
    tester,
  ) async {
    final h = await Harness.pump(tester, size: const Size(393, 2400));
    final tips = find.byKey(const ValueKey('tips'));
    await h.controller.patchDayState(h.controller.today, {'ready': 'bad'});
    await frame(tester);
    await h.controller.patchDayState(h.controller.today, {'ready': 'tired'});
    await frame(tester);
    expect(intermediate(tester, tips), isTrue);
    await h.controller.patchDayState(h.controller.today, {'ready': 'bad'});
    await tester.pumpAndSettle();
    expect(find.text('今天有点累'), findsNothing);
    expect(find.text('身体不舒服就别硬练'), findsOneWidget);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    await h.controller.patchDayState(h.controller.today, {'ready': 'tired'});
    await tester.pump();
    expect(find.text('身体不舒服就别硬练'), findsNothing);
    expect(find.text('今天有点累'), findsOneWidget);
    expect(intermediate(tester, tips), isFalse);
    expect(
      tester
          .widgetList<TweenAnimationBuilder<double>>(
            find.descendant(
              of: find.byType(TodayHero),
              matching: find.byType(TweenAnimationBuilder<double>),
            ),
          )
          .every((w) => w.duration == Duration.zero),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  for (final dark in [false, true]) {
    testWidgets('today screenshot $dark', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
      );
      await loadExerciseImages(tester);
      await h.shot(tester, 'today-motion-${dark ? 'dark' : 'light'}');
      await tester.pump(const Duration(seconds: 4));
    });
  }
  testWidgets('last tip appearance and disappearance include bottom spacing', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2400),
    );
    final tips = find.byKey(const ValueKey('tips'));
    expect(find.byType(TodayTipCard), findsNothing);
    final initial = tester.getSize(tips).height;
    await h.controller.patchDayState(h.controller.today, {'ready': 'bad'});
    await frame(tester);
    expect(intermediate(tester, tips), isTrue);
    final middle = tester.getSize(tips).height;
    await tester.pumpAndSettle();
    final expanded = tester.getSize(tips).height;
    expect(middle, greaterThan(initial));
    expect(middle, lessThan(expanded));
    await h.controller.patchDayState(h.controller.today, {'ready': null});
    await frame(tester);
    expect(intermediate(tester, tips), isTrue);
    expect(tester.getSize(tips).height, greaterThan(initial));
    expect(tester.getSize(tips).height, lessThan(expanded));
    await tester.pumpAndSettle();
    expect(tester.getSize(tips).height, initial);
    expect(find.byType(TodayTipCard), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
