import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/domain/plan_recipe.dart';
import 'package:leandaily/l10n/localized_text.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/onboarding/plan_step.dart';
import 'package:leandaily/ui/plan/your_plan.dart';
import 'package:leandaily/ui/sheets/my_plan_sheet.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';

import 'support/harness.dart';
import 'onboarding_test.dart' show next, settle;

/// 把「你的方案」放进弹层，配方由这里持有，方便断言每次改动后的配方。
class _Host extends StatefulWidget {
  const _Host({required this.start, this.build = buildRecipePlan});
  final Map<String, dynamic> start;
  final Map<String, dynamic> Function(Map<String, dynamic>) build;
  static late Map<String, dynamic> recipe;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Map<String, dynamic> _recipe = widget.start;
  @override
  Widget build(BuildContext context) {
    _Host.recipe = _recipe;
    return YourPlan(
      recipe: _recipe,
      build: widget.build,
      onChanged: (r) => setState(() => _recipe = r),
    );
  }
}

Future<Harness> openHost(
  WidgetTester t, {
  Map<String, dynamic>? start,
  Map<String, dynamic> Function(Map<String, dynamic>) build = buildRecipePlan,
}) async {
  final h = await Harness.pump(t, empty: true, size: const Size(393, 852));
  showAppSheet<void>(
    t.element(find.byType(Navigator)),
    (_) => AppSheet(
      title: '你的方案',
      padding: const EdgeInsets.all(20),
      child: _Host(
        start: start ?? defaultRecipe({'venue': 'dumbbell'}),
        build: build,
      ),
    ),
  );
  await settle(t);
  return h;
}

/// 点一下；[quick] 时只走很短的时间，用来在轻提示消失前断言它。
Future<void> tapKey(WidgetTester t, String key, {bool quick = false}) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await settle(t);
  await t.tap(f);
  if (quick) {
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  } else {
    await settle(t);
  }
}

List<int> days() => (_Host.recipe['weekdays'] as List).cast<int>();

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });

  testWidgets('week dots toggle days within 2 to 5 and sync days/weekdays', (
    t,
  ) async {
    final h = await openHost(t);
    expect(days(), [1, 3, 5]);
    await tapKey(t, 'plan-day-2');
    expect(days(), [1, 2, 3, 5]);
    expect(_Host.recipe['days'], 4);
    await tapKey(t, 'plan-day-6');
    expect(days(), [1, 2, 3, 5, 6]);
    expect(_Host.recipe['days'], 5);
    // 到上限：再点一个休息日给提示，不改动
    await tapKey(t, 'plan-day-0', quick: true);
    expect(days(), [1, 2, 3, 5, 6]);
    expect(h.controller.toast.text, '每周最多练 5 天');
    for (final d in [6, 5, 3]) {
      await tapKey(t, 'plan-day-$d');
    }
    expect(days(), [1, 2]);
    expect(_Host.recipe['days'], 2);
    // 到下限：再点训练日给提示，不改动
    await tapKey(t, 'plan-day-1', quick: true);
    expect(days(), [1, 2]);
    expect(h.controller.toast.text, '每周至少练 2 天');
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });

  testWidgets('minutes and focus change the recipe and the headline', (
    t,
  ) async {
    await openHost(t);
    final head = find.byKey(const ValueKey('plan-headline'));
    expect(t.widget<LText>(head).data, contains('35'));
    await t.ensureVisible(find.text('50 分钟'));
    await settle(t);
    await t.tap(find.text('50 分钟'));
    await settle(t);
    expect(_Host.recipe['minutes'], 50);
    expect(t.widget<LText>(head).data, contains('50'));
    // 均衡时没有「多练」，选了腹部后只有腹部有
    expect(find.text('多练'), findsNothing);
    await tapKey(t, 'plan-focus-core');
    expect(_Host.recipe['focus'], 'core');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('volume-abs')),
        matching: find.text('多练'),
      ),
      findsOneWidget,
    );
    expect(find.text('多练'), findsOneWidget);
    await tapKey(t, 'plan-focus-glutes_legs');
    expect(_Host.recipe['focus'], 'glutes_legs');
    expect(find.text('多练'), findsNWidgets(3));
    expect(t.takeException(), isNull);
  });

  testWidgets('alternate split toggles back and forth', (t) async {
    await openHost(t);
    expect(_Host.recipe['split'], 'full');
    await tapKey(t, 'plan-alt');
    expect(_Host.recipe['split'], 'ppl');
    expect(find.text('换成：每次全身都练'), findsOneWidget);
    await tapKey(t, 'plan-alt');
    expect(_Host.recipe['split'], 'full');
    expect(find.text('换成：每天只练一个方向（推、拉、腿）'), findsOneWidget);
  });

  testWidgets('day tabs list exercises and open the demo', (t) async {
    await openHost(t);
    await tapKey(t, 'plan-tab-3');
    expect(find.byKey(const ValueKey('plan-ex-3-0')), findsOneWidget);
    await tapKey(t, 'plan-ex-3-0');
    expect(find.byType(AppSheet), findsNWidgets(2));
  });

  testWidgets('recipeNotes and cardio show only when the plan has them', (
    t,
  ) async {
    await openHost(t);
    expect(find.byKey(const ValueKey('plan-cardio')), findsNothing);
    expect(find.text('补充说明'), findsNothing);
  });

  testWidgets('recipeNotes and cardio are shown', (t) async {
    await openHost(
      t,
      build: (r) => {
        ...buildRecipePlan(r),
        'recipeNotes': ['膝盖不方便：深蹲类换成了臀桥和腿弯举。'],
        'cardio': {'perWeek': 2, 'minutes': 20},
      },
    );
    await t.ensureVisible(find.byKey(const ValueKey('plan-cardio')));
    expect(find.text('补充说明'), findsOneWidget);
    expect(find.text('膝盖不方便：深蹲类换成了臀桥和腿弯举。'), findsOneWidget);
    expect(find.text('休息日加 2 次 20 分钟的快走或有氧'), findsOneWidget);
  });

  testWidgets('no overflow at 360x640 with long content', (t) async {
    final h = await Harness.pump(t, empty: true, size: const Size(360, 640));
    showAppSheet<void>(
      t.element(find.byType(Navigator)),
      (_) => AppSheet(
        title: '你的方案',
        padding: const EdgeInsets.all(20),
        child: _Host(start: defaultRecipe({'venue': 'both'})),
      ),
    );
    await settle(t);
    expect(h.controller.plans, isNotEmpty);
    expect(t.takeException(), isNull);
  });

  group('onboarding', () {
    testWidgets('finishing saves the chosen recipe and syncs days', (t) async {
      final h = await Harness.pump(
        t,
        newUser: true,
        size: const Size(393, 852),
      );
      for (var i = 0; i < 3; i++) {
        await next(t);
      }
      expect(find.text('每周几天'), findsNothing);
      // 改条件（场地）会更新默认配方，已经选的时长、重点、训练日保留
      await t.tap(find.bySemanticsLabel('健身房'));
      await settle(t);
      await tapKey(t, 'plan-day-2');
      await tapKey(t, 'plan-focus-core');
      await t.ensureVisible(find.text('50 分钟'));
      await settle(t);
      await t.tap(find.text('50 分钟'));
      await settle(t);
      await tapKey(t, 'plan-day-6');
      await tapKey(t, 'plan-day-6');
      // 回到顶部再改不方便的部位：时长、重点、训练日仍然保留
      await t.drag(
        find
            .descendant(
              of: find.byType(PlanStep),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, 4000),
      );
      await settle(t);
      await t.tap(find.bySemanticsLabel('膝'));
      await settle(t);
      expect(
        t.widget<LText>(find.byKey(const ValueKey('plan-headline'))).data,
        contains('50'),
      );
      await t.tap(find.bySemanticsLabel('开始'));
      await settle(t);
      final r = h.controller.activeRecipe!;
      expect(r['days'], 4);
      expect(r['weekdays'], [1, 2, 3, 5]);
      expect(r['minutes'], 50);
      expect(r['focus'], 'core');
      expect(r['venue'], 'gym');
      expect(r['limits'], ['膝']);
      expect(h.controller.profile!['daysPerWeek'], 4);
      expect(h.controller.library.items, hasLength(1));
      expect(h.controller.library.items.single['source'], 'generated');
    });

    testWidgets('upgrade keeps the current plan by default', (t) async {
      final h = await Harness.pump(t, size: const Size(393, 852));
      final before = h.native.docs['fw-plan-v1'];
      final count = h.controller.library.items.length;
      openOnboarding(t.element(find.byType(Navigator)), upgrade: true);
      await settle(t);
      await next(t);
      await next(t);
      expect(find.bySemanticsLabel('保留我现有的计划'), findsOneWidget);
      // 默认保留：不展示方案视图，也不会建新方案
      expect(find.byKey(const ValueKey('plan-headline')), findsNothing);
      expect(find.byType(PlanStep), findsOneWidget);
      await t.tap(find.bySemanticsLabel('保留计划，完成评估'));
      await settle(t);
      expect(h.native.docs['fw-plan-v1'], before);
      expect(h.controller.library.items, hasLength(count));
    });

    testWidgets('upgrade can generate a new plan that is only added', (
      t,
    ) async {
      final h = await Harness.pump(t, size: const Size(393, 852));
      final active = h.controller.library.activeId;
      final count = h.controller.library.items.length;
      openOnboarding(t.element(find.byType(Navigator)), upgrade: true);
      await settle(t);
      await next(t);
      await next(t);
      await t.ensureVisible(find.bySemanticsLabel('按现在的情况生成新方案'));
      await t.tap(find.bySemanticsLabel('按现在的情况生成新方案'));
      await settle(t);
      expect(find.byKey(const ValueKey('plan-headline')), findsOneWidget);
      await tapKey(t, 'plan-focus-shoulders_back');
      await t.tap(find.bySemanticsLabel('另外添加，完成评估'));
      await settle(t);
      expect(h.controller.library.items, hasLength(count + 1));
      expect(h.controller.library.activeId, active);
      expect(
        h.controller.library.items.last['plan']['recipe']['focus'],
        'shoulders_back',
      );
    });
  });

  group('my plan sheet', () {
    testWidgets('recipe plan updates in place', (t) async {
      final h = await Harness.pump(t, empty: true, size: const Size(393, 852));
      await h.controller.addRecipePlan(defaultRecipe({'venue': 'dumbbell'}));
      final count = h.controller.library.items.length;
      final id = h.controller.library.activeId;
      openMyPlan(t.element(find.byType(Navigator)));
      await settle(t);
      expect(find.byType(MyPlanSheet), findsOneWidget);
      expect(find.text('更新方案'), findsNothing);
      await tapKey(t, 'plan-focus-glutes_legs');
      expect(find.text('更新方案'), findsOneWidget);
      expect(find.text('训练记录不受影响，今天之后按新方案安排。'), findsOneWidget);
      await t.tap(find.text('更新方案'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(h.controller.toast.text, '方案已更新');
      await settle(t);
      expect(h.controller.library.items, hasLength(count));
      expect(h.controller.library.activeId, id);
      expect(h.controller.activeRecipe!['focus'], 'glutes_legs');
      expect(find.byType(MyPlanSheet), findsNothing);
    });

    testWidgets('changing back to the saved recipe hides the button', (
      t,
    ) async {
      final h = await Harness.pump(t, empty: true, size: const Size(393, 852));
      await h.controller.addRecipePlan(defaultRecipe({'venue': 'dumbbell'}));
      openMyPlan(t.element(find.byType(Navigator)));
      await settle(t);
      await tapKey(t, 'plan-focus-core');
      expect(find.text('更新方案'), findsOneWidget);
      await tapKey(t, 'plan-focus-balanced');
      expect(find.text('更新方案'), findsNothing);
    });

    testWidgets('legacy plan can be regenerated and is added to the library', (
      t,
    ) async {
      final h = await Harness.pump(t, empty: true, size: const Size(393, 852));
      expect(h.controller.activeRecipe, isNull);
      final count = h.controller.library.items.length;
      final before = h.controller.library.activeId;
      openMyPlan(t.element(find.byType(Navigator)));
      await settle(t);
      expect(find.byType(PlanPreview), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-headline')), findsNothing);
      expect(find.text('使用这个方案'), findsNothing);
      await t.tap(find.text('按我的情况重新生成'));
      await settle(t);
      expect(find.byKey(const ValueKey('plan-headline')), findsOneWidget);
      expect(find.text('原来的方案会留在方案库里，随时可以换回去。'), findsOneWidget);
      await t.tap(find.text('使用这个方案'));
      await settle(t);
      expect(h.controller.library.items, hasLength(count + 1));
      expect(h.controller.library.activeId, isNot(before));
      expect(h.controller.activeRecipe, isNotNull);
      expect(h.controller.library.items.any((i) => i['id'] == before), isTrue);
    });

    testWidgets('the plan library row opens the existing library', (t) async {
      await Harness.pump(t, empty: true, size: const Size(393, 852));
      openMyPlan(t.element(find.byType(Navigator)));
      await settle(t);
      await tapKey(t, 'my-plan-library');
      expect(find.byType(PlanEditorSheet), findsOneWidget);
    });

    testWidgets('me row shows the current plan name', (t) async {
      final h = await Harness.pump(t, tab: 3, size: const Size(393, 852));
      expect(find.text('我的方案'), findsOneWidget);
      final name = h.controller.plans.firstWhere(
        (e) => e['id'] == h.controller.activePlanId,
      )['name'];
      expect(find.text('$name'), findsWidgets);
      expect(jsonEncode(name), isNotEmpty);
    });
  });
}
