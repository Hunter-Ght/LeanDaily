import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/equipment.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/ui/kit/number_field.dart';
import 'package:leandaily/ui/sheets/equipment_sheet.dart';
import 'package:leandaily/ui/sheets/train_sheet.dart';

import 'support/harness.dart';

Future<void> openTrain(
  WidgetTester tester, {
  Map<String, dynamic>? preset,
}) async {
  openTrainSheet(tester.element(find.byType(Navigator).first), preset: preset);
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is SheetInput && w.label == label),
  matching: find.byType(EditableText),
);

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

// 恢复标签：「可以练」或「约 X 天恢复」，取决于样例数据里最近练过什么
final tag = RegExp('可以练|天恢复');

void main() {
  setUpAll(Harness.setUpAll);
  tearDown(customMuscles.clear);

  testWidgets('equipment mode: leg press shows setup and logs 腿举', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openTrain(tester);
    await tester.tap(find.text('按器械'));
    await settle(tester);
    expect(find.text('固定器械'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('equipment-leg-press')),
    );
    await tester.tap(find.byKey(const ValueKey('equipment-leg-press')));
    await settle(tester);
    // 器械详情是同一个弹层里的一页，不再另开弹层
    expect(find.byType(EquipmentDetail), findsOneWidget);
    expect(find.byType(TrainSheet), findsOneWidget);
    expect(find.text('上器械前先调好'), findsOneWidget);
    expect(find.text('脚踩踏板中部，与肩同宽'), findsOneWidget);
    expect(find.text('腿举'), findsWidgets);
    expect(find.textContaining(tag), findsOneWidget);
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    expect(find.byType(EquipmentDetail), findsNothing);
    expect(find.byType(TrainSheet), findsOneWidget);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('腿举'), findsOneWidget);
    expect(find.text('看示范'), findsOneWidget);
    // 头部卡：大白话位置在前，专业名在括号里
    expect(find.textContaining('练：大腿前面（股四头肌）'), findsOneWidget);
    expect(find.textContaining(tag), findsOneWidget);
  });

  testWidgets('search across parts finds 腿举 via alias 倒蹬', (tester) async {
    await Harness.pump(tester);
    await openTrain(tester);
    await tester.enterText(input('搜索或输入动作'), '倒蹬');
    await settle(tester);
    expect(find.byKey(const ValueKey('hit-腿举')), findsOneWidget);
    expect(find.text('来自：倒蹬'), findsOneWidget);
    expect(find.text('使用「倒蹬」'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hit-腿举')));
    await settle(tester);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('腿举'), findsOneWidget);
    expect(find.text('腿'), findsOneWidget);
  });

  testWidgets('custom exercise can pick its main muscle', (tester) async {
    final h = await Harness.pump(tester);
    await openTrain(tester, preset: {'part': '胸', 'exercise': '我的自创动作'});
    expect(find.text('主要练哪块肌肉？'), findsOneWidget);
    expect(find.textContaining(tag), findsNothing);
    await tester.tap(find.text('中下胸'));
    await settle(tester);
    expect(customMuscles['我的自创动作'], 'chest');
    expect(h.controller.date, isNotEmpty);
    expect(find.textContaining(tag), findsOneWidget);
    // 选了之后还能改
    await tester.tap(find.text('上胸'));
    await settle(tester);
    expect(customMuscles['我的自创动作'], 'chest_up');
  });

  testWidgets('keyword-guessed custom name follows the guess and can be fixed', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openTrain(tester);
    await tester.enterText(input('搜索或输入动作'), '我的臀中肌外展');
    await settle(tester);
    await tester.tap(find.textContaining('使用「'));
    await settle(tester);
    // 名字里有“臀”，按关键字猜到臀部动作：部位跟着变成腿，并让用户确认肌肉
    expect(find.text('腿'), findsWidgets);
    expect(find.text('主要练哪块肌肉？'), findsOneWidget);
    await tester.tap(find.text('其他'));
    await settle(tester);
    await tester.ensureVisible(find.text('后束肩'));
    await tester.tap(find.text('后束肩'));
    await settle(tester);
    expect(customMuscles['我的臀中肌外展'], 'delt_rear');
    expect(find.text('肩'), findsWidgets);
  });

  Future<void> openEquipmentPage(WidgetTester tester, String id) async {
    await openTrain(tester);
    await tester.tap(find.text('按器械'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(ValueKey('equipment-$id')));
    await tester.tap(find.byKey(ValueKey('equipment-$id')));
    await settle(tester);
  }

  testWidgets('back stack: picker > equipment > logger > back > back > cancel', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openEquipmentPage(tester, 'leg-press');
    // 器械详情页：左上返回、没有保存、记录按钮固定在底部
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    expect(find.text('保存'), findsNothing);
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    // 记组页：从器械详情进来，左上返回，右上保存
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('记录这一组'), findsOneWidget);
    await tester.tap(find.text('返回'));
    await settle(tester);
    expect(find.byType(EquipmentDetail), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    await tester.tap(find.text('返回'));
    await settle(tester);
    // 回到选动作页，保持“按器械”模式
    expect(find.byType(EquipmentDetail), findsNothing);
    expect(find.text('固定器械'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('返回'), findsNothing);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(find.byType(TrainSheet), findsNothing);
  });

  testWidgets('system back steps back one level at a time', (tester) async {
    await Harness.pump(tester);
    await openEquipmentPage(tester, 'leg-press');
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(EquipmentDetail), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('固定器械'), findsOneWidget);
    expect(find.byType(TrainSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(TrainSheet), findsNothing);
  });

  testWidgets('back from a filled logger asks before clearing the sets', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openEquipmentPage(tester, 'leg-press');
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    await tester.enterText(input('重量'), '100');
    await tester.enterText(input('次数'), '10');
    await tester.tap(find.text('返回'));
    await settle(tester);
    expect(find.text('返回会清掉已填的组'), findsOneWidget);
    // 取消确认：留在记组页，组还在
    await tester.tap(find.text('取消').last);
    await settle(tester);
    expect(find.byType(EquipmentDetail), findsNothing);
    expect(find.text('更换'), findsOneWidget);
    // 确认：回到器械详情，再进记组页时组已清空
    await tester.tap(find.text('返回').first);
    await settle(tester);
    await tester.tap(find.text('返回').last);
    await settle(tester);
    expect(find.byType(EquipmentDetail), findsOneWidget);
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    final field = tester.widget<EditableText>(input('重量'));
    expect(field.controller.text, isEmpty);
  });

  testWidgets('a preset exercise has no previous layer: top-left stays 取消', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openTrain(tester, preset: {'part': '胸', 'exercise': '卧推'});
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('返回'), findsNothing);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(find.byType(TrainSheet), findsNothing);
  });

  testWidgets('equipment page autoplays the demo and switches exercise chips', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openEquipmentPage(tester, 'pec-deck');
    expect(find.byType(ExerciseDemo), findsOneWidget);
    expect(
      tester.widget<ExerciseDemo>(find.byType(ExerciseDemo)).autoplay,
      isTrue,
    );
    expect(
      tester.widget<ExerciseDemo>(find.byType(ExerciseDemo)).ex['name'],
      '蝴蝶机夹胸',
    );
    expect(find.textContaining('主练：'), findsOneWidget);
    expect(find.text('练哪里'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('equipment-exercise-反向蝴蝶机')));
    await settle(tester);
    expect(
      tester.widget<ExerciseDemo>(find.byType(ExerciseDemo)).ex['name'],
      '反向蝴蝶机',
    );
    expect(find.textContaining('主练：肩膀后面'), findsOneWidget);
    // 记录的是当前选中的动作
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    expect(find.text('反向蝴蝶机'), findsWidgets);
    // 返回器械详情后还停在刚才选的动作
    await tester.tap(find.text('返回'));
    await settle(tester);
    expect(
      tester.widget<ExerciseDemo>(find.byType(ExerciseDemo)).ex['name'],
      '反向蝴蝶机',
    );
  });

  testWidgets('exercise without a demo shows a placeholder', (tester) async {
    final e = equipmentList.firstWhere(
      (e) =>
          e.exercises.any((n) => guideFor({'name': n}) == null) &&
          e.exercises.any((n) => musclesOf(n) != null),
      orElse: () => equipmentList.first,
    );
    final name = e.exercises.firstWhere(
      (n) => guideFor({'name': n}) == null,
      orElse: () => '',
    );
    if (name.isEmpty) return; // 全部动作都有示范就没有占位可测
    await Harness.pump(tester);
    await openEquipmentPage(tester, e.id);
    if (e.exercises.length > 1) {
      await tester.tap(find.byKey(ValueKey('equipment-exercise-$name')));
      await settle(tester);
    }
    expect(find.byType(ExerciseDemo), findsNothing);
    expect(find.text('示范制作中'), findsOneWidget);
  });

  testWidgets('equipment cards say which muscle groups they train', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openTrain(tester);
    await tester.tap(find.text('按器械'));
    await settle(tester);
    expect(equipmentTrains(equipmentById['pec-deck']!), contains('胸'));
    expect(find.textContaining('练：胸'), findsWidgets);
  });

  for (final size in const [Size(393, 852), Size(820, 1180), Size(320, 640)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      await Harness.pump(tester, size: size);
      await openTrain(tester);
      await tester.tap(find.text('按器械'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('equipment-pec-deck')));
      await settle(tester);
      expect(find.byType(EquipmentDetail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('反向蝴蝶机'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('记录这个动作').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('更换'));
      await settle(tester);
      await tester.enterText(input('搜索或输入动作'), '推');
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(input('搜索或输入动作'), '');
      await tester.tap(find.text('按部位'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
