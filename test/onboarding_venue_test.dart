import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/domain/templates.dart';
import 'package:leandaily/ui/kit/pressable.dart';

import 'support/harness.dart';
import 'onboarding_test.dart' show next, settle;

bool selected(WidgetTester t, String label) =>
    t
        .widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          ),
        )
        .properties
        .selected ==
    true;

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('venue cards are initially empty and exclusive $dark', (
      t,
    ) async {
      final h = await Harness.pump(
        t,
        newUser: true,
        dark: dark,
        size: const Size(393, 852),
      );
      for (var i = 0; i < 3; i++) {
        await next(t);
      }
      for (final label in ['在家 · 无哑铃', '在家 · 有哑铃', '健身房', '两边都会去']) {
        expect(selected(t, label), isFalse);
      }
      expect(
        t
            .widget<Pressable>(
              find.descendant(
                of: find.bySemanticsLabel('开始'),
                matching: find.byType(Pressable),
              ),
            )
            .onTap,
        isNotNull,
      );
      await h.shot(t, 'r-venue-onb-empty-${dark ? 'dark' : 'light'}');
      for (final label in ['在家 · 有哑铃', '健身房', '两边都会去', '在家 · 无哑铃']) {
        await t.tap(find.bySemanticsLabel(label));
        await settle(t);
        for (final other in ['在家 · 无哑铃', '在家 · 有哑铃', '健身房', '两边都会去']) {
          expect(selected(t, other), other == label);
        }
      }
      await h.shot(t, 'r-venue-onb-home-${dark ? 'dark' : 'light'}');
      await t.tap(find.bySemanticsLabel('开始'));
      await settle(t);
      expect(h.controller.profile!['venue'], 'bodyweight');
    });
  }
  testWidgets('empty venue starts with bodyweight recommendation', (t) async {
    final h = await Harness.pump(t, newUser: true);
    for (var i = 0; i < 3; i++) {
      await next(t);
    }
    await t.tap(find.bySemanticsLabel('开始'));
    await settle(t);
    final p = h.controller.profile!;
    expect(p['venue'], 'bodyweight');
    final id = recommend(p, buildTargets(p)).first['templateId'];
    expect(h.controller.library.items.single['templateId'], id);
  });
  for (final venue in ['bodyweight', 'dumbbell', 'gym', 'both']) {
    testWidgets('reassessment preselects $venue', (t) async {
      await Harness.pump(
        t,
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode({
            ...profileDefaults,
            'venue': venue,
          });
        },
      );
      openOnboarding(t.element(find.byType(Navigator)), upgrade: true);
      await settle(t);
      await next(t);
      await next(t);
      expect(
        selected(
          t,
          {
            'bodyweight': '在家 · 无哑铃',
            'dumbbell': '在家 · 有哑铃',
            'gym': '健身房',
            'both': '两边都会去',
          }[venue]!,
        ),
        isTrue,
      );
    });
  }
}
