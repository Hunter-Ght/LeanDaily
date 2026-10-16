import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fixture_store.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/stats/muscle/muscle_card.dart';

import 'package:leandaily/ui/kit/app_icon.dart';

import 'support/fonts.dart';
import 'muscle_fonts.dart';

void main() {
  setUpAll(() async {
    await loadMuscleTestFonts();
    await AppIcon.load();
  });
  for (final dark in [false, true]) {
    for (final mode in MuscleMode.values) {
      testWidgets('muscle ${mode.name} ${dark ? 'dark' : 'light'} screenshot', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(393, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = dark ? AppPalette.dark : AppPalette.light;
        final data = AppData.parse(
          File('assets/state.json').readAsStringSync(),
          File('assets/body_paths.json').readAsStringSync(),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(393, 1600)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: PaletteScope(
                palette: p,
                child: DefaultTextStyle(
                  style: AppText.body(p).copyWith(
                    fontFamily: testFontFamily,
                    fontFamilyFallback: muscleFontFallback,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: key,
                      child: ColoredBox(
                        color: p.bg,
                        child: MuscleCard(
                          days: data.days,
                          nowMs: data.now.millisecondsSinceEpoch,
                          bodyPaths: data.bodyPaths,
                          initialMode: mode,
                          onOpen: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'out/shots/muscle-${mode.name}-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
