import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/log/record_calendar.dart';
import 'package:leandaily/ui/log/day_timeline.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('list scrolls only; browsing weeks does not select a day', (
    tester,
  ) async {
    final h = await Harness.pump(tester, tab: 1);
    await tester.fling(
      find.byKey(const ValueKey('day-pager')),
      const Offset(240, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(h.controller.date, h.controller.today);
    await tester.fling(
      find.byKey(const ValueKey('week-pages')),
      const Offset(260, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(h.controller.date, h.controller.today);
    await tester.tap(find.byKey(const ValueKey('date-2026-10-09')));
    await tester.pumpAndSettle();
    expect(h.controller.date, '2026-10-09');
    await tester.tap(find.text('回到今天'));
    await tester.pumpAndSettle();
    expect(h.controller.date, h.controller.today);
    await tester.fling(
      find.byKey(const ValueKey('week-pages')),
      const Offset(-260, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('date-2026-10-16')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty day reacts to repository changes', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    expect(find.text('今天练了吗？记一组或记一餐').hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('修改 俯卧撑 第 1 组'), findsNothing);
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '俯卧撑',
      rows: [
        {'weight': 0, 'reps': 8, 'type': '正式'},
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('今天练了吗？记一组或记一餐'), findsNothing);
    expect(find.bySemanticsLabel('修改 俯卧撑 第 1 组'), findsOneWidget);
    expect(
      tester
          .widget<RecordCalendar>(find.byType(RecordCalendar))
          .marks(h.controller.today)
          .train,
      isTrue,
    );
    await h.controller.repo.flush();
    await tester.pump(const Duration(seconds: 3));
    debugDisableShadows = true;
  });
  testWidgets('empty day guides by date: today and past', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    expect(find.text('记一组').hitTestable(), findsOneWidget);
    expect(find.text('记饮食').hitTestable(), findsOneWidget);
    h.controller.setDate('2026-10-09');
    await tester.pumpAndSettle();
    expect(find.text('这天没有记录，可以补记').hitTestable(), findsOneWidget);
    expect(find.text('记一组').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rest bar adds 72 pixels of scroll clearance', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    double padding() => tester
        .widgetList<DayTimeline>(find.byType(DayTimeline))
        .first
        .bottomPadding;
    final normal = padding();
    h.controller.startRest();
    await tester.pump();
    expect(padding(), normal + 72);
    h.controller.rest.clear();
    await tester.pump();
    expect(padding(), normal);
    debugDisableShadows = true;
  });

  testWidgets('饮食和训练合并在一条时间线上，按时间排序，当天小结显示三项', (tester) async {
    await Harness.pump(tester, tab: 1);
    // 参考数据：08:10 早餐在 08:42 训练之前。
    final meal = tester.getTopLeft(find.bySemanticsLabel('编辑早餐')).dy;
    final train = tester
        .getTopLeft(find.byKey(const ValueKey('training-card')))
        .dy;
    expect(meal, lessThan(train));
    expect(find.byKey(const ValueKey('day-summary-row')), findsOneWidget);
    expect(find.text('组 · 训练'), findsOneWidget);
  });

  testWidgets('右下角加号列出全部新增入口', (tester) async {
    await Harness.pump(tester, tab: 1, empty: true);
    await tester.tap(find.byKey(const ValueKey('log-add')));
    await tester.pumpAndSettle();
    for (final label in ['记一组', '拍照记饮食', '加蛋白粉', '加蛋白粉并调整份量', '搜索 / 手动记饮食']) {
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
  });
}
