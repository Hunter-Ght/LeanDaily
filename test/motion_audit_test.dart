import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/app/shell.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/domain/catalog.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/onboarding/diagnosis_step.dart';
import 'package:leandaily/ui/onboarding/profile_steps.dart';
import 'package:leandaily/ui/onboarding/plan_step.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

import 'support/harness.dart';

bool hasIntermediate(WidgetTester tester) =>
    tester
        .widgetList<FadeTransition>(find.byType(FadeTransition))
        .any((w) => w.opacity.value > 0 && w.opacity.value < 1) ||
    tester
        .widgetList<Opacity>(find.byType(Opacity))
        .any((w) => w.opacity > 0 && w.opacity < 1);

Future<void> tapMotion(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
  expect(hasIntermediate(tester), isTrue, reason: '$target 80ms 时内容应仍在过渡');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets(
      'muscle push, back, confirmation, highlight and screenshot $dark',
      (tester) async {
        final h = await Harness.pump(tester, tab: 2, dark: dark);
        openMuscleExercises(tester.element(find.byType(StatsPage)), 'chest');
        await tester.pumpAndSettle();
        final ex = exercisesForMuscle('chest', 'home').firstWhere(
          (e) => whereInPlan(
            h.controller.plan,
            e['name'] as String,
          ).where((w) => w['venue'] == 'home').isEmpty,
        );
        final name = ex['name'] as String;
        final add = find.bySemanticsLabel('把$name加入计划');
        await tapMotion(tester, add);
        expect(find.text('居家'), findsNothing);
        await h.shot(tester, 'motion-muscle-pick-${dark ? 'dark' : 'light'}');
        await tapMotion(tester, find.text('返回'));
        final scroll = tester
            .widget<SingleChildScrollView>(
              find
                  .descendant(
                    of: find.byType(AppSheet),
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            )
            .controller!;
        expect(scroll.offset, 0);
        await tapMotion(tester, add);
        final confirm = find.textContaining('加入「');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(hasIntermediate(tester), isTrue);
        final row = tester.widget<Container>(
          find.byKey(ValueKey('exercise-row-$name')).last,
        );
        final p = tester.element(find.byType(AppSheet)).pal;
        expect((row.decoration! as BoxDecoration).color, isNot(p.card));
        expect(
          whereInPlan(
            jsonMap(jsonDecode(h.native.docs['fw-plan-v1']!)),
            name,
          ).where((w) => w['venue'] == 'home'),
          isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text('返回'), findsNothing);
        expect(scroll.offset, 0);
        await h.shot(tester, 'motion-muscle-added-${dark ? 'dark' : 'light'}');
        expect(
          (tester
                      .widget<Container>(
                        find.byKey(ValueKey('exercise-row-$name')),
                      )
                      .decoration!
                  as BoxDecoration)
              .color,
          p.card,
        );
        h.controller.toast.dismiss();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('advanced validation reveal and screenshot $dark', (tester) async {
      final h = await Harness.pump(tester, dark: dark);
      openAndroidSettings(tester.element(find.byType(PageHost)));
      await tester.pumpAndSettle();
      await h.shot(tester, 'motion-advanced-${dark ? 'dark' : 'light'}');
      final address = find.descendant(
        of: find.byWidgetPredicate((w) => w is FormInput && w.label == '接口地址'),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(address);
      await tester.enterText(address, 'http://example.test');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tapMotion(tester, find.text('保存').first);
      expect(find.text('模型接口必须使用 HTTPS'), findsOneWidget);
    });
  }

  final routes = <String, (void Function(BuildContext), List<String>)>{
    'profile': (
      (c) {
        openProfile(c);
      },
      ['编辑性别', '自定义每日热量', '自定义每日蛋白'],
    ),
    'body-log': (
      (c) {
        openBodyLog(c);
      },
      ['同时记腰围'],
    ),
    'quick-food': (
      (c) {
        openQuickFood(c);
      },
      ['手动输入', '更多'],
    ),
  };
  for (final entry in routes.entries) {
    for (final dark in [false, true]) {
      testWidgets('${entry.key} intermediate frames and screenshot $dark', (
        tester,
      ) async {
        final h = await Harness.pump(
          tester,
          dark: dark,
          seed: (native) {
            native.docs['fw-profile-v1'] = jsonEncode(
              normalizeProfile(null)['profile'],
            );
          },
        );
        entry.value.$1(tester.element(find.byType(PageHost)));
        await tester.pumpAndSettle();
        for (final label in entry.value.$2) {
          final toggle = find.byWidgetPredicate(
            (w) => w is FormSwitch && w.label == label,
          );
          final target = toggle.evaluate().isNotEmpty
              ? toggle
              : find.bySemanticsLabel(label);
          await tapMotion(
            tester,
            target.evaluate().isNotEmpty
                ? target.first
                : find.text(label).first,
          );
        }
        await h.shot(tester, 'motion-${entry.key}-${dark ? 'dark' : 'light'}');
      });
    }
  }

  for (final kind in ['conditions', 'diagnosis', 'plan']) {
    testWidgets('onboarding $kind intermediate frames', (tester) async {
      await Harness.pump(tester);
      final profile = normalizeProfile(null)['profile'] as Map<String, dynamic>;
      showAppSheet<void>(
        tester.element(find.byType(PageHost)),
        (_) => AppSheet(
          title: kind,
          child: SizedBox(
            height: 650,
            child: switch (kind) {
              'conditions' => ConditionsStep(
                profile: profile,
                onChanged: (_, _) {},
              ),
              'diagnosis' => DiagnosisStep(
                profile: profile,
                onGoalChanged: (_) {},
              ),
              _ => PlanStep(
                profile: profile,
                upgrade: false,
                selected: null,
                onSelected: (_) {},
                onConfirm: () {},
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (kind == 'plan') {
        final preview = find.bySemanticsLabel('预览每天练什么');
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final intermediateY = tester.getTopLeft(find.byType(PlanPreview)).dy;
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(PlanPreview)).dy,
          lessThan(intermediateY), reason: '预览弹层在 80ms 后仍应继续进入');
      } else {
        await tapMotion(tester, find.bySemanticsLabel(
          kind == 'conditions' ? '更多设置 ›' : '调整目标体脂'));
      }
    });
  }

  testWidgets('tab fade retains IndexedStack state, rest enters and leaves', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    final state = tester.state(find.byType(PageHost));
    h.controller.setTab(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(hasIntermediate(tester), isTrue);
    expect(tester.state(find.byType(PageHost)), same(state));
    await tester.pumpAndSettle();
    showAppSheet<void>(
      tester.element(find.byType(PageHost)),
      (_) => AppSheet(
        title: 'rest',
        child: TrainingRest(app: h.controller),
      ),
    );
    await tester.pumpAndSettle();
    h.controller.startRest(90);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(hasIntermediate(tester), isTrue);
    await tester.pumpAndSettle();
    h.controller.rest.clear();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(hasIntermediate(tester), isTrue);
    await tester.pumpAndSettle();
    expect(find.textContaining('休息 1:'), findsNothing);
  });
  testWidgets(
    'stats expansions and chart replacement have intermediate frames',
    (tester) async {
      rootBundle.evict('assets/body_paths.json');
      await tester.runAsync(
        () => rootBundle.loadString('assets/body_paths.json'),
      );
      await Harness.pump(tester, tab: 2);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tapMotion(tester, find.text('展开全部肌肉'));
      await tapMotion(tester, find.textContaining('查看全部 ').first);
      await tapMotion(tester, find.text('估算依据'));
      if (find.text('查看全部').evaluate().isNotEmpty) {
        await tapMotion(tester, find.text('查看全部'));
      }
    },
  );

  testWidgets(
    'log row deletion and restoration animate without eager history layout',
    (tester) async {
      final h = await Harness.pump(tester, tab: 1);
      final rows = jsonRows(h.controller.day['sets']);
      final first = rows.first;
      await h.controller.repo.deleteSets(h.controller.date, ['${first['id']}']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(hasIntermediate(tester), isTrue);
      await tester.pumpAndSettle();
      await h.controller.repo.restoreSets(h.controller.date, [
        '${first['id']}',
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(hasIntermediate(tester), isTrue);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    },
  );
  testWidgets(
    'invalid training and edit-set errors reveal instead of jumping',
    (tester) async {
      final h = await Harness.pump(tester);
      openTrainSheet(
        tester.element(find.byType(PageHost)),
        preset: {'part': '胸', 'exercise': '卧推'},
      );
      await tester.pumpAndSettle();
      await tapMotion(tester, find.text('保存'));
      expect(find.text('至少填一组'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      final row = {...jsonRows(h.controller.day['sets']).first, 'w': -1};
      openEditSet(tester.element(find.byType(PageHost)), row);
      await tester.pumpAndSettle();
      await tapMotion(tester, find.text('保存'));
      expect(find.text('重量或次数不对'), findsOneWidget);
    },
  );
}
