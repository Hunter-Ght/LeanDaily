import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
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
    expect(find.byType(EquipmentSheet), findsOneWidget);
    expect(find.text('上器械前先调好'), findsOneWidget);
    expect(find.text('脚踩踏板中部，与肩同宽'), findsOneWidget);
    expect(find.text('腿举'), findsWidgets);
    expect(find.textContaining(tag), findsOneWidget);
    await tester.tap(find.text('记录这个动作'));
    await settle(tester);
    expect(find.byType(EquipmentSheet), findsNothing);
    expect(find.byType(TrainSheet), findsOneWidget);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('腿举'), findsOneWidget);
    expect(find.text('看示范'), findsOneWidget);
    expect(find.text('股四头肌、臀大肌'), findsOneWidget);
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
      expect(find.byType(EquipmentSheet), findsOneWidget);
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
