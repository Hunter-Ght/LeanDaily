import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/template_browser_sheet.dart';
import 'package:leandaily/ui/sheets/settings/plan_library_section.dart';

import 'support/harness.dart';
import 'onboarding_test.dart' show settle;

Finder cards(PlanCardSize size) =>
    find.byWidgetPredicate((w) => w is PlanCard && w.size == size);
void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });
  for (final dark in [false, true]) {
    final tone = dark ? 'dark' : 'light';
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
