import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/app/routes.dart' show openEditSet;
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/ui/log/set_display.dart';
import 'package:leandaily/ui/sheets/edit_set_sheet.dart';

import 'support/harness.dart';

void seedPlan(FakeNative native, {int sets = 2}) {
  final plan = jsonDecode(native.docs['fw-plan-v1']!) as Map;
  plan['workouts']['w3']['exercises'] = [
    {
      'id': 'test-load',
      'name': '哑铃地板卧推',
      'part': '胸',
      'sets': sets,
      'min': 10,
      'max': 12,
      'weight': 5,
      'unit': 'reps',
      'core': true,
      'side': true,
      'rest': 90,
      'alts': [
        {'name': '哑铃平板卧推', 'weight': 5, 'machine': false},
      ],
    },
    {
      'id': 'test-body',
      'name': '反向卷腹',
      'part': '核心',
      'sets': sets,
      'min': 10,
      'max': 15,
      'weight': 0,
      'unit': 'reps',
      'core': true,
      'rest': 75,
    },
  ];
  native.docs['fw-plan-v1'] = jsonEncode(plan);
}

Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String label) async {
  final element = t.element(find.text(label));
  final scrollable = Scrollable.maybeOf(element);
  if (scrollable != null &&
      axisDirectionToAxis(scrollable.position.axisDirection) == Axis.vertical) {
    await scrollable.position.ensureVisible(element.findRenderObject()!);
  }
  await t.tap(find.text(label));
  await settle(t);
}

Future<void> images(WidgetTester t) async {
  final context = t.element(find.byType(TodayPage));
  await t.runAsync(() async {
    for (final f
        in Directory('assets/exercises')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))) {
      await precacheImage(ResizeImage(AssetImage(f.path), width: 400), context);
    }
  });
  await settle(t);
}

Future<void> enter(WidgetTester t, {String? id}) async {
  final context = t.element(find.byType(TodayPage));
  openTrainingMode(context, exerciseId: id);
  await settle(t);
  if (id != null && find.text('跳过热身').evaluate().isNotEmpty) {
    await tap(t, '跳过热身');
  }
}

Map<String, dynamic> rows(Harness h) =>
    (jsonDecode(h.native.docs['android-state'] ?? '{"sets":{}}')['sets'] as Map)
        .cast<String, dynamic>();
void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('今日入口、热身、保存字段、反馈超时、编辑及常亮恢复', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      seed: seedPlan,
      size: const Size(393, 852),
    );
    await images(t);
    await tap(t, '开始训练');
    expect(find.byType(TrainingMode), findsOneWidget);
    expect(h.native.awake, true);
    expect(h.controller.dayStates[h.controller.today]['started'], true);
    await tap(t, '热身完成');
    expect(h.controller.dayStates[h.controller.today]['warm'], true);
    await tap(t, '完成第 1 组');
    final row = rows(h).values.single as Map;
    expect(row, containsPair('ex', '哑铃地板卧推'));
    expect(row, containsPair('part', '胸'));
    expect(row, containsPair('w', 5));
    expect(row, containsPair('reps', 10));
    expect(row, containsPair('rpe', null));
    expect(row, containsPair('type', '正式'));
    expect(row, containsPair('notes', '单边'));
    expect(row.keys.toSet(), {
      'id',
      'ts',
      'date',
      'part',
      'ex',
      'no',
      'w',
      'reps',
      'type',
      'rpe',
      'notes',
    });
    expect(row['date'], h.controller.today);
    expect(row['no'], 1);
    expect(row['ts'], h.controller.clock().millisecondsSinceEpoch);
    expect(find.text('刚才这组还能做几次'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    await t.pump(const Duration(milliseconds: 120));
    final fade = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('刚才这组还能做几次'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, allOf(greaterThan(0), lessThan(1)));
    await settle(t);
    expect(find.text('刚才这组还能做几次'), findsNothing);
    expect(find.text('第 1 组 · 补充感受 ›'), findsOneWidget);
    await tap(t, '第 1 组 · 补充感受 ›');
    expect(find.text('刚才这组还能做几次'), findsOneWidget);
    expect((rows(h).values.single as Map)['rpe'], null);
    expect((rows(h).values.single as Map).containsKey('flag'), false);
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '第 1 组 完成，编辑',
      ),
    );
    await settle(t);
    expect(find.text('改这一组'), findsOneWidget);
    // Close the edit sheet with the navigator, then the full-screen route.
    Navigator.of(t.element(find.text('改这一组')), rootNavigator: true).pop();
    await settle(t);
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    expect(h.native.awake, false);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });
  testWidgets('最后一组自动切换、自重无重量、全部完成小结', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      seed: (n) => seedPlan(n, sets: 1),
      size: const Size(393, 852),
    );
    await images(t);
    await enter(t, id: 'test-load');
    await tap(t, '完成第 1 组');
    await t.pump(const Duration(milliseconds: 700));
    await settle(t);
    expect(find.text('反向卷腹'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '重量'),
      findsNothing,
    );
    await tap(t, '完成第 1 组');
    await t.pump(const Duration(milliseconds: 700));
    await settle(t);
    expect(find.text('练完了'), findsOneWidget);
    expect(find.text('训练量'), findsOneWidget);
    expect(find.text('刚才这组还能做几次'), findsNothing);
    expect(find.bySemanticsLabel('列表'), findsNothing);
    await tap(t, '完成');
    expect(h.native.awake, false);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });
  testWidgets('反馈更新原组，数字可直接输入并沿用上一组', (t) async {
    final h = await Harness.pump(t, empty: true, seed: seedPlan);
    await images(t);
    await enter(t, id: 'test-load');
    final input = find.descendant(
      of: find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '次数'),
      matching: find.byType(EditableText),
    );
    await t.enterText(input, '11');
    await tap(t, '完成第 1 组');
    await t.tap(find.text('2').last);
    await settle(t);
    await t.tap(find.text('有点痛'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final row = rows(h).values.single as Map;
    expect(row['reps'], 11);
    expect(row['rpe'], 8);
    expect(row['flag'], 'pain');
    expect(find.textContaining('疼痛请停止'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1200));
    await settle(t);
    expect(find.text('刚才这组还能做几次'), findsNothing);
    expect(find.text('第 1 组 · 还能做 2 次 · 有点痛 ✎'), findsOneWidget);
    expect(find.bySemanticsLabel('第 1 组 完成，有感受记录'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    await enter(t, id: 'test-load');
    expect(t.widget<EditableText>(input).controller.text, '11');
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });
  testWidgets('休息可延长跳过、长按连续增减、列表跳转和下拉关闭', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      seed: seedPlan,
      size: const Size(393, 852),
    );
    await images(t);
    await enter(t, id: 'test-load');
    final plus = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == '增加次数',
    );
    final gesture = await t.startGesture(t.getCenter(plus));
    await t.pump(const Duration(milliseconds: 950));
    await gesture.up();
    await settle(t);
    final input = find.descendant(
      of: find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '次数'),
      matching: find.byType(EditableText),
    );
    expect(
      num.parse(t.widget<EditableText>(input).controller.text),
      greaterThan(11),
    );
    await tap(t, '完成第 1 组');
    final until = h.controller.rest.untilMs;
    await tap(t, '+15 秒');
    expect(h.controller.rest.untilMs, until + 15000);
    await tap(t, '跳过');
    expect(h.controller.rest.active, false);
    await t.tap(find.bySemanticsLabel('列表'));
    await settle(t);
    await t.tap(find.textContaining('反向卷腹 ·'));
    await settle(t);
    expect(find.text('反向卷腹'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '重量'),
      findsNothing,
    );
    await t.fling(find.textContaining('第 2/2 项'), const Offset(0, 180), 1200);
    await settle(t);
    expect(find.byType(TrainingMode), findsNothing);
    expect(h.native.awake, false);
    await t.pump(const Duration(seconds: 7));
  });
  testWidgets('换动作沿用 swaps，保留原组，精简不改训练记录', (t) async {
    final h = await Harness.pump(t, empty: true, seed: seedPlan);
    await images(t);
    await enter(t, id: 'test-load');
    await tap(t, '完成第 1 组');
    await tap(t, '更多 ›');
    await tap(t, '换动作');
    await tap(t, '哑铃平板卧推');
    await tap(t, '换');
    expect(
      h.controller.dayStates[h.controller.today]['swaps']['test-load'],
      '哑铃平板卧推',
    );
    expect((rows(h).values.single as Map)['ex'], '哑铃地板卧推');
    expect(find.text('哑铃平板卧推'), findsOneWidget);
    await tap(t, '更多 ›');
    await tap(t, '改成精简');
    expect(h.controller.dayStates[h.controller.today]['lite'], true);
    expect(rows(h), hasLength(1));
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 7));
  });
  testWidgets('时长动作显示秒、每次增减五秒并保存', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      seed: (n) {
        seedPlan(n);
        final plan = jsonDecode(n.docs['fw-plan-v1']!);
        final ex = plan['workouts']['w3']['exercises'][1];
        ex['name'] = '平板支撑';
        ex['unit'] = 'sec';
        ex['min'] = 20;
        ex['max'] = 40;
        n.docs['fw-plan-v1'] = jsonEncode(plan);
      },
    );
    await images(t);
    await enter(t, id: 'test-body');
    expect(
      find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '秒'),
      findsOneWidget,
    );
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '增加秒',
      ),
    );
    await settle(t);
    await tap(t, '完成第 1 组');
    expect((rows(h).values.single as Map)['reps'], 25);
    expect((rows(h).values.single as Map)['w'], 0);
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 7));
  });
  testWidgets('减少动态效果时无位移，自重小结显示次数且隐藏反馈', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await Harness.pump(
      t,
      empty: true,
      seed: (n) {
        seedPlan(n, sets: 1);
        final plan = jsonDecode(n.docs['fw-plan-v1']!);
        plan['workouts']['w3']['exercises'].removeAt(0);
        n.docs['fw-plan-v1'] = jsonEncode(plan);
      },
    );
    await images(t);
    await enter(t, id: 'test-body');
    final number = find.byWidgetPredicate((w) => w is TrainingNumber);
    final bump = find.descendant(of: number, matching: find.byType(Transform));
    for (final transform in t.widgetList<Transform>(bump)) {
      expect(transform.transform, Matrix4.identity());
    }
    expect(
      find.descendant(
        of: find.byType(TrainingMode),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byType(TrainingMode),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await tap(t, '完成第 1 组');
    await t.pump(const Duration(milliseconds: 700));
    await settle(t);
    expect(find.text('练完了'), findsOneWidget);
    expect(find.text('自重'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('kg'), findsNothing);
    expect(find.text('刚才这组还能做几次'), findsNothing);
    expect(find.bySemanticsLabel('列表'), findsNothing);
    await tap(t, '完成');
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 7));
  });
  testWidgets('整页横滑、四分之一阈值、首尾回弹和动作各自默认值', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      seed: seedPlan,
      size: const Size(393, 852),
    );
    await images(t);
    await enter(t, id: 'test-load');
    final repsInput = find.descendant(
      of: find.byWidgetPredicate((w) => w is TrainingNumber && w.label == '次数'),
      matching: find.byType(EditableText),
    );
    await t.enterText(repsInput, '17');
    await t.pump();
    await t.flingFrom(const Offset(330, 400), const Offset(-180, 0), 700);
    await settle(t);
    expect(find.textContaining('第 1/2 项'), findsOneWidget);
    expect(t.widget<EditableText>(repsInput).controller.text, '17');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    Future<void> dragAt(Offset at, Offset delta, {int ms = 1200}) async {
      await t.timedDragFrom(at, delta, Duration(milliseconds: ms));
      await settle(t);
    }

    await dragAt(const Offset(330, 380), const Offset(-60, 0));
    expect(find.textContaining('第 1/2 项'), findsOneWidget);
    final reverse = await t.startGesture(const Offset(330, 400));
    await reverse.moveBy(const Offset(-145, 0));
    await t.pump(const Duration(milliseconds: 200));
    await reverse.moveBy(const Offset(100, 0));
    await t.pump(const Duration(milliseconds: 500));
    await reverse.up();
    await settle(t);
    expect(find.textContaining('第 1/2 项'), findsOneWidget);
    // Image, number edge, whitespace and title all belong to the same pager.
    for (final at in [
      const Offset(240, 150),
      const Offset(365, 560),
      const Offset(335, 410),
      const Offset(300, 340),
    ]) {
      await dragAt(at, const Offset(-150, 0));
      expect(find.textContaining('第 2/2 项'), findsOneWidget);
      expect(t.widget<EditableText>(repsInput).controller.text, '10');
      await dragAt(at, const Offset(150, 0));
      expect(find.textContaining('第 1/2 项'), findsOneWidget);
      expect(t.widget<EditableText>(repsInput).controller.text, '10');
    }
    await t.flingFrom(const Offset(330, 400), const Offset(-55, 0), 700);
    await settle(t);
    expect(find.textContaining('第 2/2 项'), findsOneWidget);
    await dragAt(const Offset(330, 400), const Offset(-150, 0));
    expect(find.text('练完了'), findsOneWidget);
    await dragAt(const Offset(330, 400), const Offset(-150, 0));
    expect(find.text('练完了'), findsOneWidget);
    await dragAt(const Offset(150, 400), const Offset(150, 0));
    await dragAt(const Offset(150, 400), const Offset(150, 0));
    await dragAt(const Offset(150, 400), const Offset(150, 0));
    expect(find.textContaining('热身 ', findRichText: true), findsOneWidget);
    await dragAt(const Offset(150, 400), const Offset(150, 0));
    expect(find.text('热身完成'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    h.controller.rest.clear();
  });

  testWidgets('记录页编辑感受可取消，并保留未操作的历史 RPE', (t) async {
    final h = await Harness.pump(
      t,
      tab: 1,
      seed: (n) {
        final state = jsonDecode(n.docs['android-state']!) as Map;
        for (final row in (state['sets'] as Map).values) {
          row['rpe'] = 6.5;
          row['flag'] = 'pain';
        }
        n.docs['android-state'] = jsonEncode(state);
      },
    );
    final original = jsonRows(h.controller.day['sets']).first;
    Future<void> edit() async {
      final row = jsonRows(h.controller.day['sets'])
          .firstWhere((s) => s['id'] == original['id']);
      openEditSet(t.element(find.byKey(const ValueKey('day-pager'))), row);
      await settle(t);
    }

    await edit();
    await tap(t, '保存');
    expect((rows(h)[original['id']] as Map)['rpe'], 6.5);
    await edit();
    await tap(t, '3+');
    await tap(t, '有点痛');
    await tap(t, '保存');
    final cleared = rows(h)[original['id']] as Map;
    expect(cleared['rpe'], null);
    expect(cleared.containsKey('flag'), false);
    await edit();
    await t.tap(
      find.descendant(of: find.byType(EditSetSheet), matching: find.text('1')),
    );
    await settle(t);
    await tap(t, '动作变形');
    await tap(t, '保存');
    final saved = rows(h)[original['id']] as Map;
    expect(saved['rpe'], 9);
    expect(saved['flag'], 'form');
    expect(saved['ts'], original['ts']);
    expect(find.text('还能做 1 次'), findsOneWidget);
    expect(find.textContaining('动作变形'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('弹层覆盖暂停示范、关闭恢复，翻页只保留一份完整示范', (t) async {
    final h = await Harness.pump(t, empty: true, seed: seedPlan);
    await images(t);
    await enter(t, id: 'test-load');
    double frame() => t
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('demo-frame-0')))
        .opacity;
    await t.tap(find.text('动作要点 ›'));
    await settle(t);
    final before = frame();
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(), before);
    Navigator.of(t.element(find.text('怎么做')), rootNavigator: true).pop();
    await settle(t);
    final resumed = frame();
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(), 1 - resumed);
    await t.flingFrom(const Offset(330, 400), const Offset(-180, 0), 700);
    await settle(t);
    expect(find.byType(ExerciseDemo), findsOneWidget);
    expect(find.textContaining('第 2/2 项'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('关闭'));
    await settle(t);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });

  for (final dark in [false, true]) {
    testWidgets('感受回补、编辑保存与记录显示及截图 ${dark ? 'dark' : 'light'}', (t) async {
      final scheme = dark ? 'dark' : 'light';
      final h = await Harness.pump(
        t,
        dark: dark,
        seed: (n) => seedPlan(n, sets: 3),
        size: const Size(393, 852),
      );
      await images(t);
      await enter(t, id: 'test-load');
      int frame() =>
          t
                  .widget<AnimatedOpacity>(
                    find.byKey(const ValueKey('demo-frame-0')),
                  )
                  .opacity ==
              1
          ? 0
          : 1;
      await t.tap(find.byType(ExerciseDemo));
      await t.pump();
      if (frame() == 1) {
        await t.tap(find.byType(ExerciseDemo));
        await t.pump(const Duration(milliseconds: 1100));
        await t.tap(find.byType(ExerciseDemo));
        await t.pump();
      }
      await t.tap(find.byType(ExerciseDemo));
      await t.pump(const Duration(milliseconds: 450));
      expect(frame(), 0);
      await h.shot(t, 'r-train-demo-a-$scheme');
      await t.pump(const Duration(milliseconds: 1100));
      await t.pump(const Duration(milliseconds: 450));
      expect(frame(), 1);
      await h.shot(t, 'r-train-demo-b-$scheme');
      await tap(t, '完成第 1 组');
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      expect(find.text('第 1 组 · 补充感受 ›'), findsOneWidget);
      await h.shot(t, 'r-train-feedback-bar-$scheme');
      await tap(t, '第 1 组 · 补充感受 ›');
      await t.tap(find.text('2').last);
      await t.pump();
      await t.tap(find.text('动作变形'));
      await t.pump(const Duration(milliseconds: 1200));
      await settle(t);
      expect(find.text('第 1 组 · 还能做 2 次 · 动作变形 ✎'), findsOneWidget);
      await h.shot(t, 'r-train-feedback-bar-done-$scheme');
      final row = jsonRows(h.controller.repo.day(h.controller.today)['sets'])
          .lastWhere((s) => s['ex'] == '哑铃地板卧推');
      expect(find.byKey(ValueKey('feedback-dot-${row['id']}')), findsOneWidget);
      await t.tap(find.bySemanticsLabel('第 1 组 完成，有感受记录'));
      await settle(t);
      await h.shot(t, 'r-train-editset-$scheme');
      await tap(t, '3+');
      await tap(t, '有点痛');
      await tap(t, '保存');
      final edited = rows(h)[row['id']] as Map;
      expect(edited['rpe'], 7);
      expect(edited['flag'], 'pain');
      expect(edited['id'], row['id']);
      expect(edited['ts'], row['ts']);
      expect(find.text('第 1 组 · 还能做 3+ 次 · 有点痛 ✎'), findsOneWidget);
      expect(
        setFeedbackLabel(edited.cast<String, dynamic>()),
        '还能做 3+ 次 · 有点痛',
      );
      await tap(t, '完成第 2 组');
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      expect(find.text('第 2 组 · 补充感受 ›'), findsOneWidget);
      expect(find.text('第 1 组 · 还能做 3+ 次 · 有点痛 ✎'), findsNothing);
      await t.flingFrom(const Offset(330, 400), const Offset(-180, 0), 700);
      await settle(t);
      expect(find.text('第 2 组 · 补充感受 ›'), findsNothing);
      await t.tap(find.bySemanticsLabel('关闭'));
      await settle(t);
      h.controller.rest.clear();
      h.controller.setTab(1);
      await settle(t);
      expect(find.text('还能做 3+ 次'), findsOneWidget);
      expect(find.textContaining('有点痛'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
    });
  }

  for (final size in [
    const Size(393, 852),
    const Size(393, 760),
    const Size(360, 640),
  ]) {
    testWidgets('组后反馈不遮挡两个步进器 ${size.width}×${size.height}', (t) async {
      final h = await Harness.pump(t, seed: seedPlan, size: size);
      await images(t);
      await enter(t, id: 'test-load');
      await tap(t, '完成第 1 组');
      final panel = t.getRect(find.byKey(const ValueKey('training-feedback')));
      final primary = t.getRect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '完成第 2 组',
        ),
      );
      final scroll = t.getRect(
        find.descendant(
          of: find.byType(TrainingMode),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(panel.height, lessThanOrEqualTo(96));
      expect(primary.bottom, closeTo(size.height - 14, 1));
      expect(panel.overlaps(primary), false);
      for (final label in ['次数', '重量']) {
        final number = find.byWidgetPredicate(
          (w) => w is TrainingNumber && w.label == label,
        );
        final rect = t.getRect(number);
        expect(rect.overlaps(panel), false, reason: label);
        expect(rect.overlaps(primary), false, reason: label);
        expect(rect.top, greaterThanOrEqualTo(scroll.top), reason: label);
        expect(rect.bottom, lessThanOrEqualTo(scroll.bottom), reason: label);
      }
      // Verify the next weight can actually be changed while feedback is up.
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '增加重量',
        ),
      );
      await t.pumpAndSettle();
      final weightInput = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is TrainingNumber && w.label == '重量',
        ),
        matching: find.byType(EditableText),
      );
      expect(t.widget<EditableText>(weightInput).controller.text, '5.5');
      if (size.width == 360) await h.shot(t, 'r-train-feedback-small');
      await t.tap(find.bySemanticsLabel('关闭'));
      await settle(t);
      h.controller.rest.clear();
      await t.pump(const Duration(seconds: 7));
    });
  }
  for (final dark in [false, true]) {
    testWidgets('训练六种状态截图 ${dark ? 'dark' : 'light'}', (t) async {
      final scheme = dark ? 'dark' : 'light';
      final h = await Harness.pump(
        t,
        dark: dark,
        seed: seedPlan,
        size: const Size(393, 852),
      );
      await images(t);
      await enter(t);
      await h.shot(t, 'r-train-warm-$scheme');
      await tap(t, '热身完成');
      await h.shot(t, 'r-train-set-$scheme');
      await tap(t, '完成第 1 组');
      await h.shot(t, 'r-train-feedback-$scheme');
      await t.pump(const Duration(seconds: 6));
      await settle(t);
      await h.shot(t, 'r-train-rest-$scheme');
      await tap(t, '完成第 2 组');
      await t.pump(const Duration(milliseconds: 700));
      await settle(t);
      await h.shot(t, 'r-train-bodyweight-$scheme');
      await tap(t, '完成第 1 组');
      await tap(t, '完成第 2 组');
      await t.pump(const Duration(milliseconds: 700));
      await settle(t);
      await h.shot(t, 'r-train-summary-$scheme');
      expect(TodayModel(h.controller).complete, true);
      expect(
        jsonRows(h.controller.repo.day(h.controller.today)['sets']).length,
        greaterThanOrEqualTo(4),
      );
      await tap(t, '完成');
      h.controller.rest.clear();
      await t.pump(const Duration(seconds: 4));
    });
  }
}
