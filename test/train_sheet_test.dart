import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/ui/kit/number_field.dart';
import 'package:leandaily/ui/sheets/train/controls.dart';
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
void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('train screenshots ${dark ? 'dark' : 'light'}', (tester) async {
      final h = await Harness.pump(tester, dark: dark);
      await openTrain(tester);
      final scheme = dark ? 'dark' : 'light';
      await h.shot(tester, 'sheet-train-$scheme');
      await tester.tap(find.text('弹力带胸推').first);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await h.shot(tester, 'sheet-train-log-$scheme');
      await tester.enterText(input('重量'), '0');
      await tester.enterText(input('次数'), '12');
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await h.shot(tester, 'sheet-train-filled-$scheme');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byType(TrainSheet), findsNothing);
      final state = jsonDecode(h.native.docs['android-state']!) as Map;
      expect(
        (state['sets'] as Map).values.any(
          (s) =>
              s['w'] == 0 &&
              s['reps'] == 12 &&
              s['ex'] == '弹力带胸推' &&
              s['date'] == h.controller.date,
        ),
        isTrue,
      );
      h.controller.rest.clear();
      await tester.pump(const Duration(seconds: 3));
      debugDisableShadows = true;
    });
  }
  testWidgets('training validation, replacement and dirty close', (
    tester,
  ) async {
    await Harness.pump(tester);
    await openTrain(tester, preset: {'part': '胸', 'exercise': '测试动作'});
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('至少填一组'), findsOneWidget);
    await tester.enterText(input('次数'), '1.5');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 组的重量或次数不对'), findsOneWidget);
    await tester.enterText(input('次数'), '8');
    await tester.tap(find.text('更换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('卧推').first);
    await tester.pumpAndSettle();
    expect(find.text('换动作会清掉已填的组'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.text('搜索或输入动作'), findsOneWidget);
    await tester.tap(find.text('取消').first);
    await tester.pumpAndSettle();
    expect(find.text('放弃这次记录？'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byType(TrainSheet), findsNothing);
    debugDisableShadows = true;
  });
  testWidgets('reuse, copy, add, RPE, type and failed write', (tester) async {
    final h = await Harness.pump(tester);
    final count =
        (h.controller.repo.day(h.controller.date)['sets'] as List).length;
    await openTrain(tester, preset: {'part': '胸', 'exercise': '弹力带胸推'});
    await tester.tap(find.text('套用上次'));
    await tester.pumpAndSettle();
    expect(input('重量'), findsNWidgets(2));
    await tester.enterText(input('重量').first, '12.5');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('增加重量').first);
    await tester.tap(find.bySemanticsLabel('增加重量').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(input('重量').first).controller.text,
      '15',
    );
    await tester.ensureVisible(find.byType(EffortControl).first);
    final slider = tester.getRect(find.byType(EffortControl).first);
    await tester.tapAt(
      Offset(slider.left + slider.width * 0.8, slider.center.dy),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('热身').first);
    await tester.tap(find.text('热身').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('复制上一组'));
    await tester.tap(find.text('复制上一组'));
    await tester.pumpAndSettle();
    expect(input('重量'), findsNWidgets(3));
    await tester.ensureVisible(find.text('加一组'));
    await tester.tap(find.text('加一组'));
    await tester.pumpAndSettle();
    expect(input('重量'), findsNWidgets(4));
    // A second add focuses the blank row instead of appending another one.
    await tester.ensureVisible(find.text('加一组'));
    await tester.tap(find.text('加一组'));
    await tester.pumpAndSettle();
    expect(input('重量'), findsNWidgets(4));
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.bySemanticsLabel('删除这组').last);
    await tester.tap(find.bySemanticsLabel('删除这组').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(input('当天备注'));
    await tester.enterText(input('当天备注'), '状态很好');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    h.native.failNextPut = const NativeError('保存失败');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainSheet), findsOneWidget);
    expect(h.controller.repo.day(h.controller.date)['sets'], hasLength(count));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    final state = jsonDecode(h.native.docs['android-state']!) as Map;
    final sets = (state['sets'] as Map).values
        .where((s) => s['date'] == h.controller.date && s['ex'] == '弹力带胸推')
        .toList();
    expect(sets, hasLength(3));
    expect(sets.first['w'], 15);
    expect(sets.first['rpe'], 8);
    expect(sets.first['type'], '热身');
    expect(h.controller.rest.active, isTrue);
    h.controller.rest.clear();
    await tester.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
  });
  testWidgets('keyboard keeps training note and save reachable', (
    tester,
  ) async {
    await Harness.pump(tester, empty: true);
    await openTrain(tester, preset: {'part': '胸', 'exercise': '卧推'});
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(input('当天备注'));
    await tester.enterText(input('当天备注'), '键盘下填写');
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(input('当天备注')).dy, lessThanOrEqualTo(550));
    expect(find.text('保存').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  });
}
