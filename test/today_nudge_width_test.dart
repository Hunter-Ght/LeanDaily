import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/pressable.dart';
import 'package:leandaily/ui/today/today_tip_card.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;

void main() {
  setUpAll(Harness.setUpAll);
  for (final (name, size) in [
    ('手机', const Size(393, 852)),
    ('折叠屏内屏', const Size(712, 820)),
    ('折叠屏外屏', const Size(360, 780)),
  ]) {
    testWidgets('体重提醒撑满整行且按钮热区够大：$name', (tester) async {
      await Harness.pump(
        tester,
        size: size,
        empty: true,
        seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
      );
      await tester.pumpAndSettle();
      final row = find.byType(TodayNudgeRow);
      expect(row, findsOneWidget);
      // 与训练主卡左右对齐：主按钮在卡内左右各留 16，所以提醒行宽 = 按钮宽 + 32。
      final button = tester.getRect(find.text('开始训练').first);
      expect(button.width, greaterThan(0));
      final heroButton = tester.getRect(
        find
            .ancestor(
              of: find.text('开始训练').first,
              matching: find.byType(Container),
            )
            .first,
      );
      final rowRect = tester.getRect(row);
      expect(rowRect.width, closeTo(heroButton.width + 32, 1));
      final targets = find.descendant(
        of: row,
        matching: find.byType(Pressable),
      );
      expect(targets, findsNWidgets(2));
      for (final target in targets.evaluate().map(
        (e) => tester.getRect(find.byWidget(e.widget)),
      )) {
        expect(target.height, greaterThanOrEqualTo(44));
        expect(target.width, greaterThanOrEqualTo(44));
      }
    });
  }
}
