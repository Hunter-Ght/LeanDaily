import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('切换日期后保留各日滚动位置', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(ValueKey('log-list-${h.controller.date}')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    position().jumpTo(100);
    await tester.pumpAndSettle();
    final offset = position().pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('date-2026-10-15')));
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-16')));
    await tester.pumpAndSettle();
    expect(position().pixels, offset);
  });

  testWidgets('开始训练会保存状态并打开训练模式', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await tester.tap(find.text('开始训练'));
    await tester.pumpAndSettle();
    expect(h.controller.dayStates[h.controller.today]['started'], true);
    expect(find.byType(TrainingMode), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The route now finishes in 260ms; allow the independent 600ms reminder
    // debounce to finish before disposing the controller.
    await tester.pump(const Duration(milliseconds: 600));
  });

  for (final dark in [false, true]) {
    testWidgets('首页和月历在窄屏与大字体下保持可用 ${dark ? 'dark' : 'light'}', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await Harness.pump(
        tester,
        dark: dark,
        size: const Size(320, 640),
      );
      expect(find.byType(TodayPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      h.controller.setTab(1);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('展开月历'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('date-2026-10-13')));
      await tester.pumpAndSettle();
      expect(h.controller.date, '2026-10-13');
    });

    testWidgets('交互迭代截图 ${dark ? 'dark' : 'light'}', (tester) async {
      final h = await Harness.pump(tester, dark: dark);
      await h.shot(tester, 'refined-today-${dark ? 'dark' : 'light'}');
      h.controller.setTab(1);
      await tester.pumpAndSettle();
      await h.shot(tester, 'refined-log-${dark ? 'dark' : 'light'}');
      await tester.tap(find.bySemanticsLabel('展开月历'));
      await tester.pumpAndSettle();
      await h.shot(tester, 'refined-calendar-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('关闭触感偏好后，选择日期不发原生震动', (tester) async {
    final h = await Harness.pump(
      tester,
      tab: 1,
      seed: (native) {
        native.docs['android-settings'] = jsonEncode({'haptics': false});
      },
    );
    expect(h.controller.settings.value['haptics'], false);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-13')));
    await tester.pumpAndSettle();
    expect(h.controller.date, '2026-10-13');
    expect(tester.takeException(), isNull);
  });
}
