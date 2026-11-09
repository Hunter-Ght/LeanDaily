import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:leandaily/ui/kit/body_figure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/stats/progress_sections.dart';
import 'package:leandaily/ui/stats/streak_section.dart';
import 'package:leandaily/ui/stats/strength_section.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await rootBundle.loadString('assets/muscle_map.json');
    await BodyFigure.load();
  });
  const sizes = {
    'phone': Size(393, 1900),
    'tablet': Size(820, 1180),
    'small': Size(320, 2200),
  };
  for (final dark in [false, true]) {
    for (final e in sizes.entries) {
      testWidgets('progress redesign ${e.key} ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        final h = await Harness.pump(tester, tab: 2, dark: dark, size: e.value);
        debugDisableShadows = true;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HeatHero), findsOneWidget);
        expect(find.byType(StreakSection), findsOneWidget);
        expect(find.byType(StrengthSection), findsOneWidget);
        expect(find.byType(SuggestionStrip), findsOneWidget);
        await h.shot(tester, 'progress-${e.key}-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
