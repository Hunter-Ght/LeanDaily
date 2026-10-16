import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'profile_sheet_test.dart' show profile, reveal;
import 'settings_goals_test.dart' show SettingsHarness, settle;

void main() {
  setUpAll(SettingsHarness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('profile venue labels and inline save $dark', (t) async {
      final h = await profile(t, dark: dark);
      final row = find.bySemanticsLabel(RegExp('^编辑场地')).first;
      await reveal(t, row);
      await t.tap(row);
      await settle(t);
      for (final label in ['在家 · 无哑铃', '在家 · 有哑铃', '健身房', '两边都会去']) {
        expect(find.text(label), findsWidgets);
      }
      await t.tap(find.bySemanticsLabel('在家 · 无哑铃'));
      await settle(t);
      await h.shot(t, 'r-venue-profile-${dark ? 'dark' : 'light'}');
      await reveal(t, find.text('保存').first);
      await t.tap(find.text('保存').first);
      await settle(t);
      expect(
        jsonDecode(h.native.docs['fw-profile-v1']!)['venue'],
        'bodyweight',
      );
    });
  }
}
