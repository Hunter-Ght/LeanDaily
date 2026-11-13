import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

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
      'rest': 90,
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

final plusReps = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == '增加次数',
);

/// 热身页的深蹲示范是永远循环的动画，不能 pumpAndSettle。
Future<void> soft(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String label) async {
  if (label.startsWith('完成第') && find.text('跳过休息').evaluate().isNotEmpty) {
    await t.tap(find.text('跳过休息'));
    await settle(t);
  }
  await t.tap(find.text(label));
  await settle(t);
}

/// 英文截图：把还没导入的 pending 翻译并进目录。
Future<void> mergePending() async {
  await AppMessages.initialize();
  await AppMessages.debugMerge(
    jsonDecode(File('tool/l10n/pending/train.json').readAsStringSync())
        as Map<String, dynamic>,
  );
}

Future<void> tapSoft(WidgetTester t, String label) async {
  await t.tap(find.text(label));
  await soft(t);
}

Future<void> enter(WidgetTester t, {String? id}) async {
  openTrainingMode(t.element(find.byType(TodayPage)), exerciseId: id);
  await settle(t);
}

Future<Harness> pumpHome(
  WidgetTester t, {
  Locale locale = const Locale('zh', 'CN'),
  Size size = const Size(393, 852),
  void Function(FakeNative n)? seed,
  int sets = 2,
}) => Harness.pump(
  t,
  empty: true,
  locale: locale,
  size: size,
  seed: (n) {
    seedPlan(n, sets: sets);
    seed?.call(n);
  },
);

List<String> captureHaptics(WidgetTester t) {
  final effects = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          effects.add(call.arguments as String);
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return effects;
}

Future<void> seedBest(Harness h) => h.controller.repo.addSets(
  date: '2026-10-15',
  part: '胸',
  exercise: '哑铃地板卧推',
  unilateral: false,
  rows: [
    {'weight': 5, 'reps': 8, 'rpe': null, 'type': '正式'},
  ],
);

Future<void> close(WidgetTester t, Harness h) async {
  await t.pumpWidget(const SizedBox());
  h.controller.rest.clear();
  await t.pump(const Duration(seconds: 7));
}

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await mergePending();
  });

  group('热身示范与跟着做', () {
    testWidgets('有示范的项显示缩略图、点开看要点；没有示范的项有一行做法', (t) async {
      final h = await pumpHome(t);
      await enter(t);
      expect(find.text('徒手深蹲'), findsOneWidget);
      expect(find.text('坐下去再站起来，慢慢做 10 次'), findsOneWidget);
      expect(find.text('原地踏步，自然摆臂，身体微热即可'), findsOneWidget);
      // 只有「徒手深蹲」有动作库示范 → 一个缩略图。
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('热身完成'), findsOneWidget);
      expect(find.text('跳过热身'), findsOneWidget);
      await t.tap(find.text('徒手深蹲'));
      await soft(t);
      expect(find.text('关闭'), findsWidgets);
      expect(find.byType(TrainingMode), findsOneWidget);
      await h.shot(t, 'train-warm-guide');
      Navigator.of(t.element(find.text('关闭').first), rootNavigator: true).pop();
      await soft(t);
      await close(t, h);
    });

    testWidgets('跟着做：每项 60 秒，下一项可跳过，全部完成后进第一个动作', (t) async {
      final effects = captureHaptics(t);
      final h = await pumpHome(t);
      await enter(t);
      await tapSoft(t, '跟着做');
      expect(find.text('第 1/4 项'), findsOneWidget);
      expect(find.text('肩关节活动'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(h.controller.dayStates[h.controller.today]?['warm'], isNot(true));
      await t.pump(const Duration(seconds: 5));
      expect(find.text('0:55'), findsOneWidget);
      await tapSoft(t, '下一项');
      expect(find.text('第 2/4 项'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^(1:00|0:59)$')), findsOneWidget);
      // 倒计时走完自动下一项。
      await t.pump(const Duration(seconds: 60));
      expect(find.text('第 3/4 项'), findsOneWidget);
      await tapSoft(t, '下一项');
      expect(find.text('第 4/4 项'), findsOneWidget);
      expect(find.text('徒手深蹲'), findsOneWidget);
      expect(find.text('下一项'), findsNothing);
      effects.clear();
      await tapSoft(t, '热身完成');
      await settle(t);
      expect(h.controller.dayStates[h.controller.today]['warm'], true);
      expect(find.text('完成第 1 组'), findsOneWidget);
      expect(find.textContaining('第 1/2 项'), findsOneWidget);
      await close(t, h);
    });

    testWidgets('跟着做可退出回列表，仍可直接热身完成', (t) async {
      final h = await pumpHome(t);
      await enter(t);
      await tap(t, '跟着做');
      await tap(t, '退出跟做');
      expect(find.text('跟着做'), findsOneWidget);
      expect(find.text('热身完成'), findsOneWidget);
      await tap(t, '热身完成');
      expect(h.controller.dayStates[h.controller.today]['warm'], true);
      await close(t, h);
    });

    testWidgets('跟做中途跳过热身直接去动作，不记热身完成', (t) async {
      final h = await pumpHome(t);
      await enter(t);
      await tap(t, '跟着做');
      await tap(t, '跳过热身');
      expect(find.text('完成第 1 组'), findsOneWidget);
      expect(h.controller.dayStates[h.controller.today]?['warm'], isNot(true));
      await close(t, h);
    });

    for (final c in [
      ('zh', const Locale('zh', 'CN')),
      ('en', const Locale('en')),
    ]) {
      for (final size in [const Size(393, 852), const Size(360, 640)]) {
        testWidgets('热身截图 ${c.$1} ${size.width}x${size.height}', (t) async {
          final h = await pumpHome(t, locale: c.$2, size: size);
          await enter(t);
          await h.shot(t, 'train-warm-list-${c.$1}-${size.width.toInt()}');
          expect(t.takeException(), isNull);
          await t.tap(find.text(c.$1 == 'en' ? 'Follow along' : '跟着做'));
          await soft(t);
          await t.pump(const Duration(seconds: 3));
          await h.shot(
            t,
            'train-warm-follow-demo-${c.$1}-${size.width.toInt()}',
          );
          await t.tap(find.text(c.$1 == 'en' ? 'Next' : '下一项'));
          await soft(t);
          await t.tap(find.text(c.$1 == 'en' ? 'Next' : '下一项'));
          await soft(t);
          await h.shot(
            t,
            'train-warm-follow-text-${c.$1}-${size.width.toInt()}',
          );
          await t.tap(find.text(c.$1 == 'en' ? 'Next' : '下一项'));
          await soft(t);
          await t.pump(const Duration(milliseconds: 700));
          await h.shot(
            t,
            'train-warm-follow-squat-${c.$1}-${size.width.toInt()}',
          );
          expect(t.takeException(), isNull);
          await close(t, h);
        });
      }
    }
  });

  group('破纪录的当下反馈', () {
    for (final enabled in [true, false]) {
      testWidgets('休息页显示新纪录并轻震一次，同一动作只震一次，触感=$enabled', (t) async {
        final effects = captureHaptics(t);
        final h = await pumpHome(
          t,
          sets: 3,
          seed: (n) =>
              n.docs['android-settings'] = jsonEncode({'haptics': enabled}),
        );
        await seedBest(h);
        await enter(t, id: 'test-load');
        await t.tap(find.text('跳过热身'));
        await settle(t);
        effects.clear();
        await tap(t, '完成第 1 组');
        expect(find.byKey(const ValueKey('training-record')), findsOneWidget);
        expect(find.text('新纪录 · 哑铃地板卧推 · 5 kg × 10 次'), findsOneWidget);
        // 休息计时照常进行，并没有被遮挡。
        expect(find.text('休息中 · 共 90 秒'), findsOneWidget);
        expect(h.controller.rest.active, true);
        expect(
          effects.where((e) => e == 'HapticFeedbackType.mediumImpact').length,
          enabled ? 1 : 0,
        );
        await h.shot(t, 'train-record-zh');
        // 再涨一点：横幅更新为最高值，但不再震。
        effects.clear();
        await tap(t, '跳过休息');
        await t.tap(plusReps);
        await t.pump();
        await tap(t, '完成第 2 组');
        expect(find.text('新纪录 · 哑铃地板卧推 · 5 kg × 11 次'), findsOneWidget);
        expect(
          effects.where((e) => e == 'HapticFeedbackType.mediumImpact'),
          isEmpty,
        );
        // 没破纪录的一组：不显示。
        await tap(t, '跳过休息');
        await tap(t, '完成第 3 组');
        expect(find.byKey(const ValueKey('training-record')), findsNothing);
        await close(t, h);
      });
    }

    testWidgets('减弱动态效果时只显示、不震', (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final effects = captureHaptics(t);
      final h = await pumpHome(t);
      await seedBest(h);
      await enter(t, id: 'test-load');
      await t.tap(find.text('跳过热身'));
      await settle(t);
      effects.clear();
      await tap(t, '完成第 1 组');
      expect(find.byKey(const ValueKey('training-record')), findsOneWidget);
      expect(
        effects.where((e) => e == 'HapticFeedbackType.mediumImpact'),
        isEmpty,
      );
      await close(t, h);
    });

    testWidgets('没有历史或没破纪录时不显示', (t) async {
      final h = await pumpHome(t);
      await enter(t, id: 'test-load');
      await t.tap(find.text('跳过热身'));
      await settle(t);
      await tap(t, '完成第 1 组');
      expect(find.byKey(const ValueKey('training-record')), findsNothing);
      await close(t, h);
    });

    for (final c in [
      ('zh', const Locale('zh', 'CN')),
      ('en', const Locale('en')),
    ]) {
      for (final size in [const Size(393, 852), const Size(360, 640)]) {
        testWidgets('新纪录截图 ${c.$1} ${size.width}x${size.height}', (t) async {
          final h = await pumpHome(t, locale: c.$2, size: size);
          await seedBest(h);
          await enter(t, id: 'test-load');
          await t.tap(find.text(c.$1 == 'en' ? 'Skip warm-up' : '跳过热身'));
          await settle(t);
          await t.tap(
            find.textContaining(c.$1 == 'en' ? 'Finish set 1' : '完成第 1 组'),
          );
          await settle(t);
          expect(find.byKey(const ValueKey('training-record')), findsOneWidget);
          // 等组后感受面板收起（它在英文窄屏上自己有溢出，与本功能无关），再看休息页。
          t.takeException();
          await t.pump(const Duration(seconds: 7));
          await settle(t);
          expect(find.byKey(const ValueKey('training-record')), findsOneWidget);
          await h.shot(t, 'train-record-${c.$1}-${size.width.toInt()}');
          expect(t.takeException(), isNull);
          await close(t, h);
        });
      }
    }
  });

  group('再来一组', () {
    Future<void> doPlanned(WidgetTester t, {int sets = 1}) async {
      await t.tap(find.text('跳过热身'));
      await settle(t);
      for (var i = 1; i <= sets; i++) {
        await tap(t, '完成第 $i 组');
      }
    }

    testWidgets('做满后回到该动作，一点「再来一组」即用上一组数字进入记录，计划组数不变', (t) async {
      final h = await pumpHome(t, sets: 1);
      await enter(t, id: 'test-load');
      await t.tap(find.text('跳过热身'));
      await settle(t);
      await t.tap(plusReps);
      await t.pump();
      await tap(t, '完成第 1 组'); // 11 次
      await t.pump(const Duration(milliseconds: 700));
      await settle(t);
      expect(find.text('反向卷腹'), findsOneWidget); // 自动去了下一个动作
      // 回到哑铃地板卧推（休息还在走）。
      await t.tap(find.bySemanticsLabel('列表'));
      await settle(t);
      await t.tap(find.textContaining('哑铃地板卧推 ·'));
      await settle(t);
      expect(find.text('再来一组'), findsOneWidget);
      await h.shot(t, 'train-extra-rest-zh');
      await tap(t, '再来一组');
      expect(h.controller.rest.active, false);
      // 沿用上一组：5 kg × 11，主按钮已是第 2 组。
      final input = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is TrainingNumber && w.label == '次数',
        ),
        matching: find.byType(EditableText),
      );
      expect(t.widget<EditableText>(input).controller.text, '11');
      expect(find.text('完成第 2 组'), findsOneWidget);
      await tap(t, '完成第 2 组');
      final day = h.controller.repo.day(h.controller.today);
      final sets = (day['sets'] as List)
          .where((s) => s['ex'] == '哑铃地板卧推')
          .toList();
      expect(sets.length, 2);
      expect(sets.last['reps'], 11);
      expect(sets.last['type'], '正式');
      // 计划组数不变；计划外的组不再自动翻页，还能继续再来一组。
      final model = TodayModel(h.controller);
      expect(
        model.items.firstWhere(
          (i) => i['ex']['id'] == 'test-load',
        )['ex']['target'],
        1,
      );
      await t.pump(const Duration(milliseconds: 700));
      await settle(t);
      expect(find.text('再来一组'), findsOneWidget);
      expect(find.text('反向卷腹'), findsNothing);
      await close(t, h);
    });

    testWidgets('还有计划组没做完时不显示「再来一组」', (t) async {
      final h = await pumpHome(t, sets: 2);
      await enter(t, id: 'test-load');
      await doPlanned(t);
      expect(find.text('再来一组'), findsNothing);
      await close(t, h);
    });

    for (final c in [
      ('zh', const Locale('zh', 'CN')),
      ('en', const Locale('en')),
    ]) {
      for (final size in [const Size(393, 852), const Size(360, 640)]) {
        testWidgets('再来一组截图 ${c.$1} ${size.width}x${size.height}', (t) async {
          final h = await pumpHome(t, locale: c.$2, size: size, sets: 1);
          await enter(t, id: 'test-load');
          await t.tap(find.text(c.$1 == 'en' ? 'Skip warm-up' : '跳过热身'));
          await settle(t);
          await t.tap(
            find.textContaining(c.$1 == 'en' ? 'Finish set 1' : '完成第 1 组'),
          );
          await t.pump(const Duration(milliseconds: 700));
          await settle(t);
          await t.tap(find.bySemanticsLabel(c.$1 == 'en' ? 'List' : '列表'));
          await settle(t);
          await t.tap(
            find.textContaining(
              c.$1 == 'en' ? 'Dumbbell floor press ·' : '哑铃地板卧推 ·',
            ),
          );
          await settle(t);
          await h.shot(t, 'train-extra-rest-${c.$1}-${size.width.toInt()}');
          await t.tap(find.text(c.$1 == 'en' ? 'One more set' : '再来一组'));
          await settle(t);
          await h.shot(t, 'train-extra-set-${c.$1}-${size.width.toInt()}');
          expect(t.takeException(), isNull);
          await close(t, h);
        });
      }
    }
  });
}
