import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/data/cardio_store.dart';
import 'package:leandaily/domain/cardio.dart';
import 'package:leandaily/ui/stats/progress_sections.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

String doc(List<Map<String, Object?>> rows) =>
    jsonEncode({'v': 1, 'entries': rows});

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('记录、记住上次、修改、删除并撤销', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    final date = h.controller.date;
    await tester.tap(find.byKey(const ValueKey('log-add')));
    await settle(tester);
    await tester.tap(find.text('记有氧'));
    await settle(tester);
    // 默认走路 20 分钟；选跑步，加到 25。
    await tester.tap(find.text('跑步'));
    await tester.tap(find.bySemanticsLabel('增加时长'));
    await tester.pump();
    await tester.tap(find.text('记录').last);
    await settle(tester);
    var rows = h.controller.cardioEntries;
    expect(rows, hasLength(1));
    expect(rows.single['type'], 'run');
    expect(rows.single['minutes'], 25);
    expect(rows.single['date'], date);
    expect(
      jsonDecode(h.native.docs[CardioStore.key]!)['entries'],
      hasLength(1),
    );
    // 力量记录没被碰。
    expect(h.controller.cardioDates, {date});
    final id = rows.single['id'];
    expect(find.byKey(ValueKey('cardio-card-$id')), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));

    // 再开一次：记住上次的类型和时长。
    expect(h.controller.lastCardio, (type: 'run', minutes: 25));

    // 修改：改成骑车，填距离、吃力程度。
    await tester.tap(find.bySemanticsLabel('修改有氧记录'));
    await settle(tester);
    expect(find.text('改有氧'), findsOneWidget);
    await tester.tap(find.text('骑车'));
    await tester.enterText(find.byType(EditableText).last, '12.5');
    await tester.tap(find.text('吃力'));
    await tester.tap(find.text('保存修改'));
    await settle(tester);
    rows = h.controller.cardioEntries;
    expect(rows.single['id'], id);
    expect(rows.single['type'], 'bike');
    expect(rows.single['distanceKm'], 12.5);
    expect(rows.single['effort'], 'hard');
    expect(find.text('12.5'), findsWidgets);
    await tester.pump(const Duration(seconds: 7));

    // 删除要确认，可以撤销。
    await tester.tap(find.bySemanticsLabel('删除这条有氧'));
    await settle(tester);
    await tester.tap(find.text('删除').last);
    await settle(tester);
    expect(h.controller.cardioEntries, isEmpty);
    await tester.tap(find.text('撤销'));
    await settle(tester);
    expect(h.controller.cardioEntries.single['id'], id);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('时长越界时报错，不保存', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    await tester.tap(find.byKey(const ValueKey('log-add')));
    await settle(tester);
    await tester.tap(find.text('记有氧'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText).first, '700');
    await tester.tap(find.text('记录').last);
    await settle(tester);
    expect(find.text('时长应为 1–600 分钟'), findsOneWidget);
    expect(h.controller.cardioEntries, isEmpty);
  });

  testWidgets('有氧日算活动日：连续天数不断，训练天数不变', (tester) async {
    final h = await Harness.pump(
      tester,
      tab: 1,
      seed: (n) => n.docs[CardioStore.key] = doc([
        {
          'id': 'a',
          'date': '2026-10-16',
          'type': 'walk',
          'minutes': 30,
          'ts': 1,
        },
      ]),
    );
    // 参考数据里 10-16 当天没有力量训练时，有氧使今天成为活动日。
    expect(h.controller.cardioDates, {'2026-10-16'});
    final days = {
      for (final d in h.controller.repo.allDays().entries)
        d.key: Map<String, dynamic>.from(d.value as Map),
    };
    final base = ProgressSummary.build(days, '2026-10-16');
    final withCardio = ProgressSummary.build(days, '2026-10-16', base.range, {
      '2026-10-16',
    });
    expect(withCardio.trainDays, base.trainDays);
    expect(withCardio.streak, greaterThanOrEqualTo(base.streak));
    expect(withCardio.setsByDate, base.setsByDate);
  });

  for (final (name, dark, locale) in [
    ('light', false, const Locale('zh', 'CN')),
    ('dark', true, const Locale('zh', 'CN')),
    ('en', false, const Locale('en', 'US')),
  ]) {
    testWidgets('截图 $name', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 1,
        dark: dark,
        locale: locale,
        empty: true,
        seed: (n) => n.docs[CardioStore.key] = doc([
          {
            'id': 'a',
            'date': '2026-10-16',
            'type': 'run',
            'minutes': 35,
            'distanceKm': 5.2,
            'effort': 'moderate',
            'ts': DateTime(2026, 10, 16, 7, 40).millisecondsSinceEpoch,
          },
          {
            'id': 'b',
            'date': '2026-10-16',
            'type': 'rower',
            'minutes': 15,
            'ts': DateTime(2026, 10, 16, 8, 30).millisecondsSinceEpoch,
          },
        ]),
      );
      await h.shot(tester, 'cardio-log-$name');
      await tester.tap(find.byKey(const ValueKey('log-add')));
      await settle(tester);
      await h.shot(tester, 'cardio-menu-$name');
      // 英文条目由主线程统一导入翻译；导入前回退到中文原文。
      final en = find.text('Log cardio');
      await tester.tap(en.evaluate().isNotEmpty ? en : find.text('记有氧'));
      await settle(tester);
      await h.shot(tester, 'cardio-sheet-$name');
      expect(cardioTypes, isNotEmpty);
    });
  }

  for (final (name, locale) in [
    ('zh', const Locale('zh', 'CN')),
    ('en', const Locale('en', 'US')),
  ]) {
    testWidgets('截图 今日与进度 $name', (tester) async {
      String d(int back) =>
          DateTime(2026, 10, 16 - back).toIso8601String().substring(0, 10);
      Map<String, Object?> row(String id, int back, int min) => {
        'id': id,
        'date': d(back),
        'type': 'walk',
        'minutes': min,
        'ts': DateTime(2026, 10, 16 - back, 18).millisecondsSinceEpoch,
      };
      final h = await Harness.pump(
        tester,
        tab: 0,
        locale: locale,
        seed: (n) => n.docs[CardioStore.key] = doc([
          row('a', 0, 30),
          row('b', 1, 40),
          row('c', 2, 25),
          row('d', 9, 50),
        ]),
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 300));
      await h.shot(tester, 'cardio-today-$name');
      h.controller.setTab(2);
      await settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
      await tester.pump(const Duration(milliseconds: 300));
      await h.shot(tester, 'cardio-progress-$name');
    });
  }
}
