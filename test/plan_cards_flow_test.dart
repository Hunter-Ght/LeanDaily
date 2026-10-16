import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/onboarding/plan_step.dart';
import 'package:leandaily/ui/sheets/template_browser_sheet.dart';
import 'package:leandaily/ui/sheets/settings/plan_library_section.dart';

import 'support/harness.dart';
import 'onboarding_test.dart' show next, settle;

Finder cards(PlanCardSize size) =>
    find.byWidgetPredicate((w) => w is PlanCard && w.size == size);
void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });
  for (final dark in [false, true]) {
    final tone = dark ? 'dark' : 'light';
    testWidgets('recommendation swap and saved choice $tone', (t) async {
      final h = await Harness.pump(
        t,
        newUser: true,
        dark: dark,
        size: const Size(393, 852),
      );
      for (var i = 0; i < 3; i++) {
        await next(t);
      }
      await t.tap(find.bySemanticsLabel('两边都会去'));
      await settle(t);
      final main = cards(PlanCardSize.large);
      await t.ensureVisible(main);
      await settle(t);
      await h.shot(t, 'r-plan-onb-$tone');
      final comparison = find.descendant(
        of: find.byType(PlanStep),
        matching: find.byType(PageView),
      );
      await t.ensureVisible(comparison);
      await t.drag(comparison, const Offset(-260, 0));
      await settle(t);
      expect(t.widget<PageView>(comparison).controller!.page, closeTo(1, .01));
      await t.drag(comparison, const Offset(260, 0));
      await settle(t);
      expect(t.widget<PageView>(comparison).controller!.page, closeTo(0, .01));
      final small = cards(PlanCardSize.small).first;
      await t.ensureVisible(small);
      await settle(t);
      final chosen = t.widget<PlanCard>(small).name;
      await t.tap(small);
      await settle(t);
      expect(t.widget<PlanCard>(main).name, chosen);
      await t.ensureVisible(main);
      await settle(t);
      await h.shot(t, 'r-plan-onb-swap-$tone');
      expect(find.byType(PlanStep), findsOneWidget);
      await t.tap(find.bySemanticsLabel('开始'));
      await settle(t);
      expect(h.controller.plans.single['name'], chosen);
    });
    testWidgets(
      'library, catalog, preview screenshots and compact week $tone',
      (t) async {
        final h = await Harness.pump(
          t,
          dark: dark,
          size: const Size(393, 852),
          tab: 3,
        );
        await h.controller.addTemplatePlan('full-2');
        await h.controller.addTemplatePlan('lean-female-3');
        await settle(t);
        showAppSheet<void>(
          t.element(find.byType(Navigator)),
          (_) => AppSheet(
            title: '我的计划',
            child: PlanLibrarySection(
              beforeChange: () async => true,
              onPlanChanged: () {},
            ),
          ),
        );
        await settle(t);
        expect(
          find.byWidgetPredicate(
            (w) => w is WeekDots && w.diameter == 18 && !w.showWeekdays,
          ),
          findsNWidgets(3),
        );
        await h.shot(t, 'r-plan-library-$tone');
        await t.tap(find.text('＋ 从模板添加'));
        await settle(t);
        expect(find.byType(TemplateBrowserSheet), findsOneWidget);
        await h.shot(t, 'r-plan-browser-$tone');
        final first = cards(PlanCardSize.medium).first;
        await t.tap(first);
        await settle(t);
        expect(find.byType(PlanPreview), findsOneWidget);
        expect(find.text('每天练什么'), findsOneWidget);
        await h.shot(t, 'r-plan-preview-$tone');
        expect(t.takeException(), isNull);
      },
    );
  }
}
