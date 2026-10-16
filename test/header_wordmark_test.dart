import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/wordmark.dart';
import 'package:leandaily/ui/today/today_hero.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/workout_title.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  test('workoutTitle changes only spaced separators for display', () {
    expect(workoutTitle('胸 + 背 + 腹'), '胸 · 背 · 腹');
    expect(workoutTitle('胸+背'), '胸+背');
    expect(workoutTitle('腿 · 肩'), '腿 · 肩');
    expect(workoutTitle(''), '');
  });

  for (final dark in [false, true]) {
    testWidgets('wordmark header and workout card, dark=$dark', (t) async {
      final semantics = t.ensureSemantics();
      final h = await Harness.pump(t, dark: dark);
      final m = TodayModel(h.controller);
      final title = find.text(workoutTitle('${m.workout['name']}'));
      expect(title, findsOneWidget);
      expect(
        find.descendant(of: find.byType(TodayHero), matching: title),
        findsOneWidget,
      );
      expect(t.widget<Text>(title).style!.fontSize, 26);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == '${m.workout['name']}' &&
              w.style?.fontSize == 34,
        ),
        findsNothing,
      );
      final wordmark = find.byType(Wordmark);
      expect(wordmark, findsOneWidget);
      expect(t.getSemantics(wordmark).label, '薄肌日课');
      expect(t.getSemantics(wordmark).flagsCollection.isHeader, isTrue);
      expect(t.getSemantics(wordmark).flagsCollection.isButton, isFalse);
      expect(t.getTopLeft(wordmark).dy, lessThan(t.getTopLeft(title).dy));
      expect(
        t.getSize(find.bySemanticsLabel('计划与提醒设置')).height,
        greaterThanOrEqualTo(44),
      );
      expect(m.workout['name'], contains(' + '));
      semantics.dispose();
      await t.pump(const Duration(seconds: 4));
    });
  }
}
