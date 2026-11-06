import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/sheets/train_sheet.dart' show TrainSheet;

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('sheet content never overshoots its top edge on a fling back', (
    tester,
  ) async {
    await Harness.pump(tester, tab: 1);
    openTrainSheet(tester.element(find.byKey(const ValueKey('day-pager'))));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byType(TrainSheet),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final pos = tester.state<ScrollableState>(scrollable).position;
    // 先往下滑一段，再用力甩回顶部：内容不能越过顶边留出空白。
    await tester.fling(scrollable, const Offset(0, -500), 2500);
    await tester.pumpAndSettle();
    expect(pos.pixels, greaterThan(100));
    await tester.fling(scrollable, const Offset(0, 120), 4000);
    var minSeen = pos.pixels;
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (pos.pixels < minSeen) minSeen = pos.pixels;
    }
    await tester.pumpAndSettle();
    expect(minSeen, greaterThanOrEqualTo(pos.minScrollExtent - 0.5));
    expect(pos.pixels, pos.minScrollExtent);
    // 弹层仍然开着（惯性不会把它甩下去）。
    expect(find.byType(TrainSheet), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
