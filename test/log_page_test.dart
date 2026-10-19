import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/log/record_calendar.dart';
import 'package:leandaily/ui/log/day_cards.dart';

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
  testWidgets('empty day and weekly goal react to repository and preferences', (
    tester,
  ) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    expect(find.text('这天还没练').hitTestable(), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('day-section-switch')),
        matching: find.text('饮食'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('这天还没记饮食').hitTestable(), findsOneWidget);
    expect(find.text('本周 0/3 天'), findsOneWidget);
    await h.controller.saveGoals({...h.controller.goals, 'weekDays': 5});
    await tester.pumpAndSettle();
    expect(find.text('本周 0/5 天'), findsOneWidget);
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '俯卧撑',
      rows: [
        {'weight': 0, 'reps': 8, 'type': '正式'},
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('本周 1/5 天'), findsOneWidget);
    expect(find.text('这天还没练').hitTestable(), findsNothing);
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
  testWidgets('rest bar adds 72 pixels of scroll clearance', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    double padding() =>
        tester.widgetList<DayCards>(find.byType(DayCards)).first.bottomPadding;
    final normal = padding();
    h.controller.startRest();
    await tester.pump();
    expect(padding(), normal + 72);
    h.controller.rest.clear();
    await tester.pump();
    expect(padding(), normal);
    debugDisableShadows = true;
  });

  testWidgets('竖屏训练和饮食用切换条分开看，刚记的那一块自动显示', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    Finder switchLabel(String text) => find.descendant(
      of: find.byKey(const ValueKey('day-section-switch')),
      matching: find.text(text),
    );
    // 空白一天默认先看训练；两块都在条上，饮食不用往下滑。
    expect(switchLabel('训练'), findsOneWidget);
    expect(switchLabel('饮食'), findsOneWidget);
    expect(find.text('这天还没练').hitTestable(), findsOneWidget);
    expect(find.text('这天还没记饮食'), findsNothing);
    // 记了一餐 → 自动切到饮食，并在条上显示数量。
    await h.controller.repo.saveMeal(
      date: h.controller.today,
      meal: '午餐',
      items: [
        {'name': '米饭', 'portion': '1碗', 'kcal': 174, 'protein': 4.5},
      ],
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('编辑午餐').hitTestable(), findsOneWidget);
    expect(find.text('这天还没练'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('day-section-switch')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    // 手动切回训练。
    await tester.tap(switchLabel('训练'));
    await tester.pumpAndSettle();
    expect(find.text('这天还没练').hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('编辑午餐'), findsNothing);
  });

  testWidgets('训练 | 饮食切换有触感，点已选中的那一项不震', (tester) async {
    final effects = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            effects.add('${call.arguments}');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await Harness.pump(tester, tab: 1, empty: true);
    Finder label(String text) => find.descendant(
      of: find.byKey(const ValueKey('day-section-switch')),
      matching: find.text(text),
    );
    await tester.tap(label('训练'));
    await tester.pumpAndSettle();
    expect(effects.where((e) => e.endsWith('selectionClick')), isEmpty);
    await tester.tap(label('饮食'));
    await tester.pumpAndSettle();
    expect(effects.where((e) => e.endsWith('selectionClick')), hasLength(1));
  });
}
