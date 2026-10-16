import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/ui/stats/body_route_card.dart';

import 'support/harness.dart';

class _PaintCount extends CustomPainter {
  _PaintCount(this.delegate);
  final CustomPainter? delegate;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    delegate?.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PaintCount oldDelegate) => false;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('weight sheet does not repaint static progress chart each frame', (
    tester,
  ) async {
    await Harness.pump(
      tester,
      tab: 2,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode({'weightKg': 70});
        n.docs['fw-body-v1'] = jsonEncode({
          'v': 1,
          'entries': [
            {'date': '2026-10-14', 'weightKg': 70.5},
            {'date': '2026-10-15', 'weightKg': 70.2},
          ],
        });
      },
    );
    final chart = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BodyTrendLine,
    );
    expect(chart, findsOneWidget);
    final render = tester.renderObject<RenderCustomPaint>(chart);
    final counter = _PaintCount(render.painter);
    render.painter = counter;
    await tester.pump();
    counter.paints = 0;
    var ticks = 0;
    void tick() => ticks++;
    sheetDepth.addListener(tick);
    addTearDown(() => sheetDepth.removeListener(tick));
    openBodyLog(tester.element(find.byType(StatsPage)));
    await tester.pump();
    await _frames(tester);
    // Count paint calls, not elapsed widget-test time (which is not device FPS).
    // ignore: avoid_print
    print(
      'Weight sheet open / background chart paints: ${counter.paints}, ticks=$ticks, depth=${sheetDepth.value}, reduced=${MediaQuery.disableAnimationsOf(tester.element(find.byType(StatsPage)))}',
    );
    expect(counter.paints, lessThanOrEqualTo(2));
    await tester.pumpAndSettle();
    counter.paints = 0;
    await tester.tap(find.text('取消'));
    await tester.pump();
    await _frames(tester);
    // ignore: avoid_print
    print('Weight sheet close / background chart paints: ${counter.paints}');
    expect(counter.paints, lessThanOrEqualTo(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final tall in [true, false]) {
    testWidgets('static sheet content is retained while moving tall=$tall', (
      tester,
    ) async {
      await Harness.pump(tester, tab: 2);
      final counter = _PaintCount(null);
      final context = tester.element(find.byType(StatsPage));
      Widget builder(BuildContext _) => AppSheet(
        title: 'paint probe',
        child: SizedBox(height: 160, child: CustomPaint(painter: counter)),
      );
      if (tall) {
        showAppSheet<void>(context, builder);
      } else {
        showSheetPanel<void>(
          context,
          (ctx) => SizedBox(height: 300, child: builder(ctx)),
        );
      }
      await tester.pump();
      counter.paints = 0;
      await _frames(tester);
      // ignore: avoid_print
      print('Static sheet content paints tall=$tall: ${counter.paints}');
      expect(counter.paints, lessThanOrEqualTo(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
