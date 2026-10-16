import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/stats/stats_page.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('weight sheet remains usable across folded/expanded resize', (
    tester,
  ) async {
    final h = await Harness.pump(tester, tab: 2, size: const Size(393, 852));
    openBodyLog(tester.element(find.byType(StatsPage)));
    await tester.pump();
    await tester.pump(); // Establish the spring ticker's initial timestamp.
    await tester.pump(const Duration(milliseconds: 80));
    expect(sheetDepth.value, inExclusiveRange(0, 1));
    // Expand mid-animation. Flutter receives new logical constraints from Android.
    tester.view.physicalSize = const Size(850, 800) * 2;
    await tester.pumpAndSettle();
    final title = find.descendant(
      of: find.byType(AppSheet),
      matching: find.text('记体重'),
    );
    expect(title, findsOneWidget);
    expect(tester.getSize(find.byType(AppSheet)).width, 600);
    await tester.tap(find.text('同时记腰围'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 560);
    await tester.pumpAndSettle();
    expect(find.text('保存').hitTestable(), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await h.shot(tester, 'performance-weight-expanded');
    tester.view.physicalSize = const Size(393, 852) * 2;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppSheet)).width, 393);
    await tester.fling(title, const Offset(0, 600), 1800);
    await tester.pumpAndSettle();
    expect(find.text('记体重'), findsOneWidget); // progress-page entry remains
    expect(find.byType(AppSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
