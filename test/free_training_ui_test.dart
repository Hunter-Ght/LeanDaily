import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/free_training.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/ui/sheets/alternatives_sheet.dart';
import 'package:leandaily/ui/sheets/my_gym_sheet.dart';
import 'package:leandaily/ui/sheets/train/exercise_info.dart';
import 'package:leandaily/ui/sheets/train_sheet.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> openTrain(
  WidgetTester tester, {
  Map<String, dynamic>? preset,
}) async {
  openTrainSheet(tester.element(find.byType(Navigator).first), preset: preset);
  await settle(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false); // 命中的是外层 Pressable
  await settle(tester);
}

void main() {
  setUpAll(Harness.setUpAll);
  setUp(TrainSheet.resetPickerMode);
  tearDown(customMuscles.clear);

  // 当前样例数据下的推荐，测试里据此找要点的动作。
  List<FreeGroup> reco(Harness h) =>
      recommendNow(recoveryStatus(h.controller), owned: h.controller.myGym);

  testWidgets('opens on recommend with groups and exercises', (tester) async {
    final h = await Harness.pump(tester);
    await openTrain(tester);
    final groups = reco(h);
    expect(groups, isNotEmpty);
    expect(find.text('按肌肉恢复推荐；器械被占就点“换一个”'), findsOneWidget);
    expect(find.text('设置我的健身房'), findsOneWidget);
    expect(
      find.byKey(ValueKey('reco-group-${groups.first.group}')),
      findsOneWidget,
    );
    final first = groups.first.exercises.first;
    expect(find.byKey(ValueKey('reco-${first.name}')), findsOneWidget);
    expect(find.byKey(ValueKey('swap-${first.name}')), findsOneWidget);
  });

  testWidgets('tapping a recommended exercise goes to the logger', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    await openTrain(tester);
    final first = reco(h).first.exercises.first;
    final row = find.descendant(
      of: find.byKey(ValueKey('reco-${first.name}')),
      matching: find.text(first.name),
    );
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text(first.name), findsWidgets);
    // 头部“器械被占？换一个”只在有替代动作时出现
    expect(
      find.byKey(const ValueKey('busy-swap')),
      alternativesFor(recoveryStatus(h.controller), first.name).isEmpty
          ? findsNothing
          : findsOneWidget,
    );
  }, skip: false);

  testWidgets('swap opens alternatives and the pick replaces the exercise', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    await openTrain(tester);
    final status = recoveryStatus(h.controller);
    // 找一对“推荐动作 → 替代动作”，替代动作自己也有替代，才能验证记组页头部能再换一次
    final (src, alt) = [
      for (final e in reco(h).expand((g) => g.exercises))
        for (final a in alternativesFor(status, e.name))
          if (alternativesFor(status, a.name).isNotEmpty) (e, a),
    ].first;
    await tapKey(tester, 'swap-${src.name}');
    expect(find.byType(AlternativesSheet), findsOneWidget);
    await tapKey(tester, 'alt-${alt.name}');
    expect(find.byType(AlternativesSheet), findsNothing);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text(alt.name), findsWidgets);
    // 记组页头部也有“器械被占？换一个”，可以再换一次
    expect(find.byKey(const ValueKey('busy-swap')), findsOneWidget);
    await tapKey(tester, 'busy-swap');
    expect(find.byType(AlternativesSheet), findsOneWidget);
  });

  testWidgets('my gym saves the selection and recommend shows the filter', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    await openTrain(tester);
    await tapKey(tester, 'gym-entry');
    expect(find.byType(MyGymSheet), findsOneWidget);
    expect(find.text('勾选你常去的健身房有的器械。不勾选任何器械表示不限。'), findsOneWidget);
    await tapKey(tester, 'gym-leg-press');
    await tester.tap(find.text('保存').last);
    await settle(tester);
    expect(h.controller.myGym, {'leg-press'});
    expect(find.byType(MyGymSheet), findsNothing);
    expect(find.text('只看我的健身房（1 台器械）'), findsOneWidget);
    // 按器械页显示状态行，并且仍可点开所有器械
    await tester.ensureVisible(find.text('按器械'));
    await tester.tap(find.text('按器械'));
    await settle(tester);
    expect(find.text('我的健身房：已选 1 台 · 编辑'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('equipment-pec-deck')),
    );
    expect(find.byKey(const ValueKey('equipment-pec-deck')), findsOneWidget);
  });

  testWidgets('my gym select all and clear', (tester) async {
    final h = await Harness.pump(tester);
    await openTrain(tester);
    await tapKey(tester, 'gym-entry');
    await tester.tap(find.text('全选'));
    await settle(tester);
    await tester.tap(find.text('保存').last);
    await settle(tester);
    expect(h.controller.myGym.length, greaterThan(5));
    await tapKey(tester, 'gym-entry');
    await tester.tap(find.text('清空'));
    await settle(tester);
    await tester.tap(find.text('保存').last);
    await settle(tester);
    expect(h.controller.myGym, isEmpty);
  });

  testWidgets('today entry opens the logger in recommend mode', (tester) async {
    final h = await Harness.pump(tester);
    final entry = find.byKey(const ValueKey('free-training'));
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('自由练：现在能练什么 ›'));
    await settle(tester);
    expect(find.byType(TrainSheet), findsOneWidget);
    expect(
      find.byKey(ValueKey('reco-group-${reco(h).first.group}')),
      findsOneWidget,
    );
  });

  for (final size in const [Size(393, 852), Size(820, 1180), Size(320, 640)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      final h = await Harness.pump(tester, size: size);
      await openTrain(tester);
      expect(tester.takeException(), isNull);
      final status = recoveryStatus(h.controller);
      final src = reco(h)
          .expand((g) => g.exercises)
          .firstWhere((e) => alternativesFor(status, e.name).isNotEmpty);
      await tapKey(tester, 'swap-${src.name}');
      expect(find.byType(AlternativesSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('关闭').last);
      await settle(tester);
      await tapKey(tester, 'gym-entry');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'gym-leg-press');
      await tester.tap(find.text('保存').last);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('按器械'));
      await tester.tap(find.text('按器械'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('推荐'));
      await tester.tap(find.text('推荐'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
