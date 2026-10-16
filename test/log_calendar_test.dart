import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/log/record_calendar.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('月历原位展开，返回键先收起，日期和列表同步', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    final row = find.byKey(const ValueKey('section-2026-10-16-训练'));
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

  testWidgets('列表和日历的纵向操作不会误展开，轻点仍有效', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    await tester.drag(
      find.byKey(const ValueKey('day-pager')),
      const Offset(12, 210),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('week-pages')),
      const Offset(8, 80),
    );
    await tester.pumpAndSettle();
    final cal = tester.widget<RecordCalendar>(find.byType(RecordCalendar));
    expect(cal.progress.value, 0);
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
