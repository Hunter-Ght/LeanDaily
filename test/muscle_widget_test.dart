import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fixture_store.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/stats/muscle/body_map.dart';
import 'package:leandaily/ui/stats/muscle/muscle_card.dart';

AppData fixture() => AppData.parse(
  File('assets/state.json').readAsStringSync(),
  File('assets/body_paths.json').readAsStringSync(),
);
Widget host(Widget child, {AppPalette palette = AppPalette.light}) =>
    MediaQuery(
      data: const MediaQueryData(size: Size(393, 1600)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PaletteScope(
          palette: palette,
          child: DefaultTextStyle(style: AppText.body(palette), child: child),
        ),
      ),
    );
void main() {
  test('SVG paths, mirror hit testing, full paths and neutral areas', () {
    final geometry = BodyGeometry(
      jsonDecode(File('assets/body_paths.json').readAsStringSync()),
    );
    final painter = BodyPainter(
      geometry: geometry,
      back: false,
      colors: {for (final m in MUSCLES) m['id']!: AppPalette.light.fill},
      palette: AppPalette.light,
      selected: '',
    );
    expect(
      painter.muscleAt(const Offset(50, 65), const Size(120, 280)),
      'chest',
    );
    expect(
      painter.muscleAt(const Offset(70, 65), const Size(120, 280)),
      'chest',
    );
    expect(
      painter.muscleAt(const Offset(60, 100), const Size(120, 280)),
      'abs',
    );
    expect(painter.muscleAt(const Offset(60, 15), const Size(120, 280)), null);
    expect(painter.muscleAt(const Offset(100, 15), const Size(120, 280)), null);
    // Same location after SVG preserveAspectRatio letterboxing.
    expect(
      painter.muscleAt(const Offset(130, 130), const Size(300, 560)),
      'chest',
    );
  });
  for (final width in [320.0, 780.0, 850.0, 1000.0]) {
    testWidgets('muscle modes fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = fixture();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 2000)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PaletteScope(
              palette: AppPalette.light,
              child: DefaultTextStyle(
                style: AppText.body(AppPalette.light),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: width >= 640 ? 108 : 16,
                    right: 16,
                  ),
                  child: MuscleCard(
                    days: data.days,
                    nowMs: data.now.millisecondsSinceEpoch,
                    bodyPaths: data.bodyPaths,
                    onOpen: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final mode in MuscleMode.values) {
        await tester.tap(find.byKey(ValueKey('mode-${mode.name}')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'modes, row selection, mirrored body taps and interrupted transition',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? opened;
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.topLeft,
            child: MuscleCard(
              days: fixture().days,
              nowMs: fixture().now.millisecondsSinceEpoch,
              bodyPaths: fixture().bodyPaths,
              onOpen: (id) => opened = id,
            ),
          ),
        ),
      );
      expect(find.text('臀大肌'), findsNWidgets(2));
      expect(
        tester.getSize(find.byKey(const ValueKey('muscle-row-glutes'))).height,
        44,
      );
      await tester.tap(find.byKey(const ValueKey('mode-volume')));
      await tester.pumpAndSettle();
      expect(find.text('中下胸'), findsNWidgets(2));
      expect(find.text('4.9 组'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('muscle-row-biceps')));
      await tester.pumpAndSettle();
      expect(find.text('肱二头肌'), findsNWidgets(2));
      final body = find.byKey(const ValueKey('body-front'));
      final top = tester.getTopLeft(body), size = tester.getSize(body);
      final scale = size.height / 280;
      await tester.tapAt(top + Offset(size.width / 2 + 10 * scale, 65 * scale));
      await tester.pumpAndSettle();
      expect(find.text('中下胸'), findsNWidgets(2));
      await tester.tap(find.text('看怎么练、加入计划'));
      await tester.pumpAndSettle();
      expect(opened, 'chest');
      await tester.tap(find.byKey(const ValueKey('mode-detrain')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byKey(const ValueKey('mode-fatigue')));
      await tester.pumpAndSettle();
      expect(find.text('已恢复'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
