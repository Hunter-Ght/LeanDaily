import 'package:flutter/widgets.dart';
import 'package:leandaily/app/shell.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    testWidgets('shell + dock $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        tab: 0,
        size: const Size(393, 852),
      );
      await h.shot(tester, 'r-shell-$scheme');
    });
    testWidgets('add menu sheet $scheme', (tester) async {
      final h = await Harness.pump(tester, dark: dark, tab: 1);
      await tester.tap(find.bySemanticsLabel('记一笔'));
      await tester.pumpAndSettle();
      expect(find.text('记一组训练'), findsOneWidget);
      await h.shot(tester, 'menu-add-$scheme');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('记一组训练'), findsNothing);
    });
  }

  testWidgets('sheet drag to dismiss', (tester) async {
    await Harness.pump(tester, tab: 1);
    await tester.tap(find.bySemanticsLabel('记一笔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记一组训练'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
    await tester.fling(find.text('记一组'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsNothing);
  });

  testWidgets('four dock tabs and wide rail', (tester) async {
    final h = await Harness.pump(tester);
    expect(find.bySemanticsLabel('更多'), findsNothing);
    for (final (label, index) in [('记录', 1), ('进度', 2), ('我的', 3), ('今日', 0)]) {
      await tester.tap(
        find.descendant(of: find.byType(Dock), matching: find.text(label)),
      );
      await tester.pumpAndSettle();
      expect(h.controller.tab, index);
    }
    tester.view.physicalSize = const Size(2000, 2000);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dock), matching: find.text('我的')),
    );
    await tester.pumpAndSettle();
    expect(h.controller.tab, 3);
    expect(tester.takeException(), isNull);
  });
}
