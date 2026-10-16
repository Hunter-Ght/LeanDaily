import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/transitions.dart';
import 'package:leandaily/app/boot_screen.dart';
import 'package:leandaily/theme/tokens.dart';

void main() {
  for (final reduced in [false, true]) {
    for (final kind in ['reveal', 'push', 'fade']) {
      testWidgets(
        '$kind intermediate frame and interruption reduced=$reduced',
        (tester) async {
          var next = false;
          late StateSetter update;
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: Center(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      final child = SizedBox(
                        key: ValueKey(next),
                        width: 100,
                        height: next ? 180 : 80,
                        child: Text(next ? 'new' : 'old'),
                      );
                      return switch (kind) {
                        'reveal' => Reveal(
                          visible: !next,
                          child: const SizedBox(
                            width: 100,
                            height: 180,
                            child: Text('old'),
                          ),
                        ),
                        'push' => PushSwitcher(
                          direction: next ? 1 : -1,
                          child: child,
                        ),
                        _ => FadeSwitcher(child: child),
                      };
                    },
                  ),
                ),
              ),
            ),
          );
          update(() => next = true);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          if (reduced) {
            expect(find.text('old'), findsNothing);
          } else {
            expect(find.text('old'), findsOneWidget);
            if (kind != 'reveal') expect(find.text('new'), findsOneWidget);
            expect(
              tester
                      .widgetList<Opacity>(find.byType(Opacity))
                      .any((w) => w.opacity > 0 && w.opacity < 1) ||
                  tester
                      .widgetList<FadeTransition>(find.byType(FadeTransition))
                      .any((w) => w.opacity.value > 0 && w.opacity.value < 1),
              isTrue,
            );
          }
          await tester.pumpAndSettle();
          expect(find.text('old'), findsNothing);
          update(() => next = false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          update(() => next = true);
          await tester.pumpAndSettle();
          expect(find.text('old'), findsNothing);
        },
      );
    }
  }
  for (final axis in Axis.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        'keyed rows insert/remove, image decode axis=$axis reduced=$reduced',
        (tester) async {
          var rows = ['a'];
          var ready = false;
          late StateSetter update;
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Column(
                      children: [
                        MotionList(
                          axis: axis,
                          children: [
                            for (final row in rows)
                              SizedBox(
                                key: ValueKey(row),
                                height: 80,
                                child: Text(row),
                              ),
                          ],
                        ),
                        revealImageFrame(
                          context,
                          const SizedBox(height: 20),
                          ready ? 0 : null,
                          false,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          update(() {
            rows = ['a', 'b'];
            ready = true;
          });
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(find.text('b'), findsOneWidget);
          final imageOpacity = tester
              .widget<FadeTransition>(
                find.descendant(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(FadeTransition),
                ),
              )
              .opacity
              .value;
          expect(imageOpacity, reduced ? 1 : inExclusiveRange(0, 1));
          await tester.pumpAndSettle();
          update(() => rows = ['b']);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(find.text('a'), reduced ? findsNothing : findsOneWidget);
          if (!reduced) {
            expect(
              tester
                  .widgetList<SizeTransition>(find.byType(SizeTransition))
                  .any((w) => w.sizeFactor.value > 0 && w.sizeFactor.value < 1),
              isTrue,
            );
          }
          await tester.pumpAndSettle();
          expect(find.text('a'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'native bootstrap works without PaletteScope and slow hint fades',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(platformBrightness: Brightness.dark),
            child: BootScreen(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester
            .widgetList<FadeTransition>(find.byType(FadeTransition))
            .any((w) => w.opacity.value > 0 && w.opacity.value < 1),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('启动步骤'), findsOneWidget);
    },
  );
  testWidgets('pre-WidgetsApp first frame follows native dark theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: BootScreen(),
      ),
    );
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox).first).color,
      AppPalette.dark.bg,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
