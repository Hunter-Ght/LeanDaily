
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/plan_recipe.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/onboarding/plan_step.dart';

import 'support/harness.dart';
import 'onboarding_test.dart' show settle;

/// 截图：引导最后一步、「我的方案」两种状态。浅色 / 深色 / 英文，393×852 与 360×640。
void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });
  final variants = [
    ('light', false, const Locale('zh', 'CN')),
    ('dark', true, const Locale('zh', 'CN')),
    ('en', false, const Locale('en')),
    ('en-dark', true, const Locale('en')),
  ];
  for (final size in [const Size(393, 852), const Size(360, 640)]) {
    final dim = '${size.width.toInt()}x${size.height.toInt()}';
    for (final (name, dark, locale) in variants) {
      testWidgets('onboarding plan step $dim $name', (t) async {
        final h = await Harness.pump(
          t,
          newUser: true,
          dark: dark,
          size: size,
          locale: locale,
        );
        for (var i = 0; i < 3; i++) {
          await t.tap(
            find.bySemanticsLabel(
              locale.languageCode == 'en' ? 'Continue' : '继续',
            ),
          );
          await settle(t);
        }
        await h.shot(t, 'onb-plan-$dim-$name-1');
        final scroll = find
            .descendant(
              of: find.byType(PlanStep),
              matching: find.byType(Scrollable),
            )
            .first;
        for (var i = 2; i <= 6; i++) {
          await t.drag(scroll, Offset(0, -(size.height - 260)));
          await settle(t);
          await h.shot(t, 'onb-plan-$dim-$name-$i');
        }
        expect(t.takeException(), isNull);
      });
      testWidgets('my plan sheet $dim $name', (t) async {
        final h = await Harness.pump(
          t,
          empty: true,
          dark: dark,
          size: size,
          locale: locale,
        );
        // 老用户的模板方案
        openMyPlan(t.element(find.byType(Navigator)));
        await settle(t);
        await h.shot(t, 'myplan-legacy-$dim-$name');
        final regen = find.text(
          locale.languageCode == 'en' ? 'Build a new plan for me' : '按我的情况重新生成',
        );
        await t.ensureVisible(regen);
        await t.tap(regen);
        await settle(t);
        await h.shot(t, 'myplan-regen-$dim-$name-1');
        final sheetScroll = find.byType(Scrollable).last;
        for (var i = 2; i <= 6; i++) {
          await t.drag(sheetScroll, Offset(0, -(size.height - 260)));
          await settle(t);
          await h.shot(t, 'myplan-regen-$dim-$name-$i');
        }
      });
      testWidgets('my plan sheet with recipe $dim $name', (t) async {
        final h = await Harness.pump(
          t,
          empty: true,
          dark: dark,
          size: size,
          locale: locale,
        );
        await h.controller.addRecipePlan({
          ...defaultRecipe({'venue': 'both', 'daysPerWeek': 4}),
          'focus': 'glutes_legs',
        });
        await settle(t);
        openMyPlan(t.element(find.byType(Navigator)));
        await settle(t);
        await h.shot(t, 'myplan-recipe-$dim-$name-1');
        await t.tap(find.byKey(const ValueKey('plan-focus-core')));
        await settle(t);
        await h.shot(t, 'myplan-recipe-$dim-$name-2');
        final sheetScroll = find.byType(Scrollable).last;
        for (var i = 3; i <= 6; i++) {
          await t.drag(sheetScroll, Offset(0, -(size.height - 260)));
          await settle(t);
          await h.shot(t, 'myplan-recipe-$dim-$name-$i');
        }
      });
    }
  }
}
