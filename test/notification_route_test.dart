import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('cold notification consumes launch payload and opens today', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      seed: (native) {
        native.launchPayload = const NotificationTap(plan: true);
      },
    );
    expect(h.native.launchPayload, isNull);
    expect(h.controller.tab, 0);
    expect(h.controller.date, h.controller.today);
  });
  testWidgets('warm notification returns from history to today', (
    tester,
  ) async {
    final h = await Harness.pump(tester, tab: 3);
    h.controller.setDate('2026-10-01');
    h.native.tapNotification(plan: false);
    await tester.pumpAndSettle();
    expect(h.controller.tab, 0);
    expect(h.controller.date, h.controller.today);
  });
}
