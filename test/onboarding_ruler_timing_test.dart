import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/onboarding/ruler.dart';
import 'package:leandaily/ui/onboarding/diagnosis_step.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  for (final mode in ['none', 'resize', 'dependencies', 'bounds']) {
    testWidgets(
      'ruler settling while layout changes $mode',
      (tester) async {
        await Harness.pump(tester, newUser: true);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final r = find.byKey(const ValueKey('age'));
        final sc = find.descendant(
          of: r,
          matching: find.byType(SingleChildScrollView),
        );
        for (var i = 0; i < 12; i++) {
          await tester.fling(sc, Offset(i.isEven ? -90 : 90, 0), 600);
          await tester.pump(const Duration(milliseconds: 16));
          if (mode == 'resize') {
            tester.view.physicalSize = Size(
              (i.isEven ? 390 : 393) * tester.view.devicePixelRatio,
              850 * tester.view.devicePixelRatio,
            );
          }
          if (mode == 'dependencies') {
            tester.platformDispatcher.textScaleFactorTestValue = i.isEven
                ? 1.01
                : 1.0;
          }
          if (mode == 'bounds') {
            tester.view.physicalSize = Size(
              (i.isEven ? 320 : 393) * tester.view.devicePixelRatio,
              640 * tester.view.devicePixelRatio,
            );
          }
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: '$mode round $i');
          await tester.pumpAndSettle();
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
  for (final field in ['age', 'heightCm', 'weightKg']) {
    testWidgets(
      'fractional tick settling updates $field without reentry',
      (tester) async {
        await Harness.pump(tester, newUser: true);
        final ruler = find.byKey(ValueKey(field));
        final scroll = find.descendant(
          of: ruler,
          matching: find.byType(SingleChildScrollView),
        );
        final controller = tester
            .widget<SingleChildScrollView>(scroll)
            .controller!;
        for (final fraction in [.12, .25, .49, .6]) {
          final gesture = await tester.startGesture(tester.getCenter(scroll));
          await gesture.moveBy(const Offset(-30, 0));
          await tester.pump(const Duration(milliseconds: 16));
          final target = ((controller.offset / 10).round() + 3) * 10 + fraction;
          await gesture.moveBy(Offset(controller.offset - target, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(controller.offset, closeTo(target, .001));
          await gesture.up();
          await tester.pumpAndSettle(
            const Duration(milliseconds: 20),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 3),
          );
          expect(tester.takeException(), isNull);
          expect(controller.position.isScrollingNotifier.value, false);
          expect(
            controller.offset / 10,
            closeTo((controller.offset / 10).roundToDouble(), .01),
          );
          final widget = tester.widget<ProfileRuler>(ruler);
          final expected =
              widget.min + (controller.offset / 10).round() * widget.step;
          expect(widget.value, closeTo(expected, .001));
          expect(
            find.descendant(
              of: ruler,
              matching: find.text(
                '${widget.value.toStringAsFixed(widget.step < 1 ? 1 : 0)} ${widget.unit}',
              ),
            ),
            findsOneWidget,
          );
        }
        await tester.tap(find.bySemanticsLabel('继续'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('看图选'));
        await tester.pump(const Duration(milliseconds: 16));
        final tab = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == '看图选',
          ),
        );
        expect(tab.properties.selected, true);
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('继续'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.bySemanticsLabel('调整目标体脂'));
        await tester.tap(find.bySemanticsLabel('调整目标体脂'));
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(GoalBodyFatSlider), findsOneWidget);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
