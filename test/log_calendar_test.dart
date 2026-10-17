import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/log/record_calendar.dart';
import 'package:leandaily/theme/tokens.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  for (final dark in [false, true]) {
    for (final height in [568.0, 640.0]) {
      for (final locale in [
        const Locale('zh', 'CN'),
        const Locale('zh', 'TW'),
        const Locale('en'),
      ]) {
        testWidgets('短屏大字体月历保留列表和切换入口 $dark/$height/$locale', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final h = await Harness.pump(
            tester,
            tab: 1,
            dark: dark,
            locale: locale,
            size: Size(320, height),
          );
          final cal = tester.widget<RecordCalendar>(
            find.byType(RecordCalendar),
          );
          cal.onToggle();
          await tester.pumpAndSettle();
          expect(cal.progress.value, 1);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const ValueKey('day-pager'))).height,
            greaterThanOrEqualTo(Metrics.dockHeight + Metrics.touchTarget),
          );
          expect(
            find.byKey(const ValueKey('day-section-switch')).hitTestable(),
            findsOneWidget,
          );
          final header = find.byKey(const ValueKey('record-header-scroll'));
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: header, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          expect(position.maxScrollExtent, greaterThan(0));
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(cal.progress.value, 0);
          await tester.tap(find.byKey(const ValueKey('date-2026-10-13')));
          await tester.pumpAndSettle();
          expect(h.controller.date, '2026-10-13');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('月历原位展开，返回键先收起，日期和列表同步', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final row = find.byKey(const ValueKey('day-section-switch'));
    final start = tester.getTopLeft(row).dy;
    final day = find.byKey(const ValueKey('date-2026-10-16'));
    expect(tester.getSize(day), const Size(36, 36));
    final dayY = tester.getCenter(day).dy;
    await tester.tap(find.bySemanticsLabel('展开月历'));
    await tester.pump();
    expect(tester.getCenter(day).dy, closeTo(dayY, 1));
    await tester.pump(const Duration(milliseconds: 70));
    final progress = tester
        .widget<RecordCalendar>(find.byType(RecordCalendar))
        .progress
        .value;
    expect(tester.getCenter(day).dy, closeTo(dayY + 104 * progress, 1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(row).dy - start, closeTo(260, 1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('展开月历'), findsOneWidget);
    expect(h.controller.tab, 1);
    expect(tester.getTopLeft(row).dy, closeTo(start, 1));
  });

  testWidgets('拖动日历展开收起，列表的纵向滑动不会误展开，轻点仍有效', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    RecordCalendar cal() =>
        tester.widget<RecordCalendar>(find.byType(RecordCalendar));
    // 列表自己的滑动不影响日历。
    await tester.drag(
      find.byKey(const ValueKey('day-pager')),
      const Offset(12, 210),
    );
    await tester.pumpAndSettle();
    expect(cal().progress.value, 0);
    // 在日期行上往下拖：跟手展开，松手后吸附到月历。
    final rows = find.byKey(const ValueKey('week-pages'));
    final gesture = await tester.startGesture(tester.getCenter(rows));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 26));
    await tester.pump();
    // 越过触摸阈值之后的位移才算数，进度跟手。
    expect(cal().progress.value, closeTo(26 / 260, .03));
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(cal().progress.value, 1);
    expect(find.bySemanticsLabel('收起月历'), findsOneWidget);
    // 拖动小横条往上扫：收回周历。
    await tester.fling(
      find.byKey(const ValueKey('month-pages')),
      const Offset(0, -150),
      900,
    );
    await tester.pumpAndSettle();
    expect(cal().progress.value, 0);
    expect(find.bySemanticsLabel('展开月历'), findsOneWidget);
    // 拖得不够远就弹回周历。
    final short = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('week-pages'))),
    );
    await short.moveBy(const Offset(0, 30));
    await tester.pump();
    await short.up();
    await tester.pumpAndSettle();
    expect(cal().progress.value, 0);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-13')));
    await tester.pumpAndSettle();
    expect(h.controller.date, '2026-10-13');
  });

  testWidgets('翻月只浏览，点选日期后收起，未来日期不可选', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    await tester.tap(find.bySemanticsLabel('展开月历'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('date-2026-10-20')));
    await tester.pumpAndSettle();
    expect(h.controller.date, h.controller.today);
    await tester.tap(find.bySemanticsLabel('上个月'));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);
    expect(h.controller.date, h.controller.today);
    await tester.tap(find.byKey(const ValueKey('date-2026-09-15')));
    await tester.pumpAndSettle();
    expect(h.controller.date, '2026-09-15');
    expect(find.bySemanticsLabel('展开月历'), findsOneWidget);
    expect(find.text('2026年9月'), findsOneWidget);
  });

  testWidgets('快速反向点击不会留下半展开状态', (tester) async {
    await Harness.pump(tester, tab: 1);
    await tester.tap(find.bySemanticsLabel('展开月历'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(find.bySemanticsLabel('收起月历'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RecordCalendar>(find.byType(RecordCalendar)).progress.value,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('短拖回到原周，快扫吸附一周且不修改选中日期', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final pages = find.byKey(const ValueKey('week-pages'));
    final gesture = await tester.startGesture(tester.getCenter(pages));
    await gesture.moveBy(const Offset(35, 2));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('date-2026-10-16')), findsOneWidget);
    await tester.fling(pages, const Offset(240, 8), 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('date-2026-10-09')), findsOneWidget);
    expect(h.controller.date, h.controller.today);
  });

  testWidgets('内屏常驻月历，折回手机恢复周历', (tester) async {
    await Harness.pump(tester, tab: 1, size: const Size(852, 850));
    expect(tester.getSize(find.byType(RecordCalendar)).width, 360);
    expect(find.bySemanticsLabel('展开月历'), findsNothing);
    tester.view.physicalSize = const Size(786, 1700);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('展开月历'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
