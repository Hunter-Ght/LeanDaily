import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/sheets/train_sheet.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets(
    'edit validates, steps across 20kg, persists and preserves rpe and flag',
    (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 1,
        seed: (native) {
          final state = jsonDecode(native.docs['android-state']!) as Map;
          for (final row in (state['sets'] as Map).values) {
            (row as Map)['flag'] = 'pain';
            row['rpe'] = 8;
          }
          native.docs['android-state'] = jsonEncode(state);
        },
      );
      final set = Map<String, dynamic>.from(
        (h.controller.day['sets'] as List).first as Map,
      );
      openEditSet(tester.element(find.byKey(const ValueKey('day-pager'))), set);
      await settle(tester);
      await tester.enterText(find.byType(EditableText).first, '20');
      await tester.enterText(find.byType(EditableText).last, '1.5');
      await tester.tap(find.text('保存'));
      await settle(tester);
      expect(find.text('重量或次数不对'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('增加重量'));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        '22.5',
      );
      await tester.enterText(find.byType(EditableText).last, '11');
      await tester.tap(find.text('递减'));
      await tester.tap(find.text('保存'));
      await settle(tester);
      final doc = jsonDecode(h.native.docs['android-state']!) as Map;
      final saved = doc['sets'][set['id']] as Map;
      expect(saved['w'], 22.5);
      expect(saved['reps'], 11);
      expect(saved['type'], '递减');
      expect(saved['rpe'], set['rpe']);
      expect(saved['flag'], set['flag']);
      await h.controller.repo.load();
      expect((h.controller.day['sets'] as List).first['w'], 22.5);
      await h.controller.repo.flush();
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = true;
    },
  );
  testWidgets('delete set requires confirmation and persists a tombstone', (
    tester,
  ) async {
    final h = await Harness.pump(tester, tab: 1);
    final sets = h.controller.day['sets'] as List;
    final id = sets.first['id'];
    final count = sets.length;
    await tester.tap(find.bySemanticsLabel('这组的更多操作').first);
    await settle(tester);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect((h.controller.day['sets'] as List).length, count);
    await tester.tap(find.bySemanticsLabel('这组的更多操作').first);
    await settle(tester);
    await tester.tap(find.text('删除', skipOffstage: false));
    await settle(tester);
    expect((h.controller.day['sets'] as List).length, count - 1);
    expect(
      jsonDecode(h.native.docs['android-state']!)['sets'][id]['deleted'],
      true,
    );
    await h.controller.repo.flush();
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  });
  testWidgets('删除后撤销恢复原 ID 和记录内容，不新增同步任务', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final row = Map<String, dynamic>.from(
      (h.controller.day['sets'] as List).first as Map,
    );
    await tester.tap(find.bySemanticsLabel('这组的更多操作').first);
    await settle(tester);
    await tester.tap(find.text('删除'));
    await settle(tester);
    expect(
      (h.controller.repo.state['sets'] as Map)[row['id']]['deleted'],
      true,
    );
    await tester.tap(find.text('撤销').hitTestable().first);
    await settle(tester);
    final restored = (h.controller.repo.state['sets'] as Map)[row['id']];
    expect(restored['deleted'], false);
    expect(restored['w'], row['w']);
    expect(restored['reps'], row['reps']);
    expect(
      (h.controller.day['sets'] as List).any((s) => s['id'] == row['id']),
      true,
    );
    expect(h.controller.repo.state['tasks'], isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('again passes the shared preset shape', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final sets = h.controller.day['sets'] as List;
    await tester.tap(find.text('再记一组').hitTestable().first);
    await settle(tester);
    final preset = tester.widget<TrainSheet>(find.byType(TrainSheet)).preset!;
    expect(preset.keys.toSet(), {'part', 'exercise', 'uni', 'rows'});
    expect(preset['exercise'], sets.first['ex']);
    expect((preset['rows'] as List).first['weight'], sets.last['w']);
    await h.controller.repo.flush();
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  });
  testWidgets('meal opens with editId and deletion persists', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final meal = (h.controller.meals['meals'] as List).first as Map;
    final edit = find.bySemanticsLabel('编辑${meal['meal']}');
    await tester.scrollUntilVisible(
      edit,
      200,
      scrollable: find.descendant(
        of: find.byKey(ValueKey('log-list-${h.controller.date}')),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
    await tester.tap(edit);
    await settle(tester);
    expect(
      tester.widget<MealSheet>(find.byType(MealSheet)).preset!['editId'],
      meal['record_id'],
    );
    await tester.tap(find.text('取消'));
    await settle(tester);
    await tester.ensureVisible(find.bySemanticsLabel('删除这条饮食').first);
    await tester.tap(find.bySemanticsLabel('删除这条饮食').first);
    await settle(tester);
    await tester.tap(find.text('删除'));
    await settle(tester);
    expect(
      jsonDecode(
        h.native.docs['android-state']!,
      )['meals'][meal['record_id']]['deleted'],
      true,
    );
    await h.controller.repo.flush();
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  });
  testWidgets('save banner undo uses stored ids', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final ids = await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '俯卧撑',
      rows: [
        {'weight': 0, 'reps': 8, 'type': '正式'},
      ],
    );
    await settle(tester);
    expect(find.text('已保存 俯卧撑 1 组'), findsOneWidget);
    await tester.tap(find.text('撤销').last);
    await settle(tester);
    await tester.tap(find.text('撤销').last);
    await settle(tester);
    expect(
      jsonDecode(h.native.docs['android-state']!)['sets'][ids.first]['deleted'],
      true,
    );
    await h.controller.repo.flush();
    await tester.pump(const Duration(seconds: 7));
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  });
}
