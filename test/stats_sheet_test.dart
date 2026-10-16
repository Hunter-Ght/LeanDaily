import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/catalog.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/ui/sheets/guide_sheet.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('muscle sheet ${dark ? 'dark' : 'light'}', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 2,
        dark: dark,
        size: const Size(393, 2600),
      );
      debugDisableShadows = true;
      openMuscleExercises(tester.element(find.byType(StatsPage)), 'chest');
      await settle(tester);
      expect(find.text('练「中下胸」'), findsOneWidget);
      expect(find.text('居家'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      await h.shot(tester, 'sheet-muscle-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('健身房'));
      await settle(tester);
      expect(find.text('主练'), findsWidgets);
      final exercise = exercisesForMuscle(
        'chest',
        'gym',
      ).firstWhere((e) => e['level'] != 'hard');
      await tester.tap(
        find.bySemanticsLabel(RegExp('查看${exercise['name']}示范')),
      );
      await settle(tester);
      expect(find.byType(GuideSheet), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await settle(tester);
      expect(find.text('练「中下胸」'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await settle(tester);
      expect(find.text('练「中下胸」'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('choose slot, optional, save to native and undo', (tester) async {
    final h = await Harness.pump(tester, tab: 2, size: const Size(393, 1600));
    debugDisableShadows = true;
    openMuscleExercises(tester.element(find.byType(StatsPage)), 'chest');
    await settle(tester);
    final exercise = exercisesForMuscle('chest', 'home').firstWhere(
      (e) => whereInPlan(
        h.controller.plan,
        e['name'] as String,
      ).where((w) => w['venue'] == 'home').isEmpty,
    );
    final name = exercise['name'] as String;
    await tester.tap(find.bySemanticsLabel('把$name加入计划'));
    await settle(tester);
    expect(find.text('加到哪一天'), findsWidgets);
    expect(find.textContaining('时长约'), findsWidgets);
    expect(find.textContaining('每周直接训练'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('作为可选动作'));
    await settle(tester);
    final confirm = find.textContaining('加入「');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await settle(tester);
    final persisted = jsonMap(jsonDecode(h.native.docs['fw-plan-v1']!));
    final places = whereInPlan(
      persisted,
      name,
    ).where((w) => w['venue'] == 'home').toList();
    expect(places, isNotEmpty);
    final list = listOf(
      jsonMap(jsonMap(persisted['workouts'])[places.first['workoutId']]),
      'home',
    );
    expect(
      jsonMap(list.firstWhere((e) => jsonMap(e)['name'] == name))['optional'],
      true,
    );
    await tester.tap(find.text('撤销'));
    await settle(tester);
    final undone = jsonMap(jsonDecode(h.native.docs['fw-plan-v1']!));
    expect(
      whereInPlan(undone, name).where((w) => w['venue'] == 'home'),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker back and no scheduled days', (tester) async {
    final h = await Harness.pump(tester, tab: 2, size: const Size(393, 1500));
    debugDisableShadows = true;
    await h.controller.updatePlan({
      ...h.controller.plan,
      'schedule': <String, dynamic>{},
    });
    openMuscleExercises(tester.element(find.byType(StatsPage)), 'calves');
    await settle(tester);
    await tester.tap(find.text('＋ 加入').first);
    await settle(tester);
    expect(find.text('当前计划里没有排训练日，先在「训练计划与提醒」里安排每周训练。'), findsOneWidget);
    await tester.tap(find.text('返回'));
    await settle(tester);
    expect(find.text('居家'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
