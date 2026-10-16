import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/ui/kit/grouped.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';
import 'package:leandaily/ui/sheets/edit_set_sheet.dart';
import 'package:leandaily/ui/sheets/food/nutrition_summary.dart';
import 'package:leandaily/ui/sheets/guide_sheet.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';
import 'package:leandaily/ui/sheets/quick_food_sheet.dart';
import 'package:leandaily/ui/sheets/train_sheet.dart';

import 'support/harness.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    for (final sheet in [
      'quickfood',
      'meal',
      'train',
      'editset',
      'plan',
      'advanced',
      'guide',
    ]) {
      testWidgets('sheet $sheet $scheme at 393×852', (tester) async {
        final h = await Harness.pump(
          tester,
          dark: dark,
          size: const Size(393, 852),
        );
        final context = tester.element(find.byType(Navigator).first);
        h.controller.foods = Foods.parse(
          File('assets/foods.json').readAsStringSync(),
        );
        Widget content;
        switch (sheet) {
          case 'quickfood':
            content = const QuickFoodSheet();
          case 'meal':
            content = const MealSheet(
              preset: {
                'meal': '午餐',
                'time': '12:10',
                'items': [
                  {
                    'name': '鸡肉饭',
                    'portion': '一份',
                    'kcal': 520,
                    'protein': 38,
                    'carbs': 60,
                    'fat': 14,
                  },
                ],
              },
            );
          case 'train':
            content = const TrainSheet(
              preset: {
                'part': '胸',
                'exercise': '弹力带胸推',
                'rows': [
                  {'weight': 0, 'reps': 12, 'rpe': 8, 'type': '正式'},
                ],
              },
            );
          case 'editset':
            content = EditSetSheet(
              set: {'ex': '高位俯卧撑', 'no': 2, 'w': 0, 'reps': 12, 'rpe': 8},
            );
          case 'plan':
            content = const PlanEditorSheet();
          case 'advanced':
            content = const AndroidSettingsSheet();
          default:
            final guide = guideFor({'name': '高位俯卧撑'})!;
            await tester.runAsync(() async {
              for (final path in guide['frames'] as List) {
                await precacheImage(AssetImage('$path'), context);
              }
            });
            content = const GuideSheet(exercise: '高位俯卧撑');
        }
        showAppSheet<void>(context, (_) => content);
        await settle(tester);
        if (sheet == 'quickfood') {
          final food = h.controller.foods!.proteinRanking().first;
          await tester.tap(find.bySemanticsLabel('选择 ${food['name']}').first);
          await settle(tester);
          await tester.tap(find.text('加入'));
          await settle(tester);
          expect(find.byType(NutritionSummary), findsOneWidget);
          final summaryContext = tester.element(find.byType(NutritionSummary));
          final value = tester.widget<Text>(find.textContaining(' 千卡').last);
          expect(value.style!.color, summaryContext.pal.text);
        }
        if (sheet == 'train') {
          expect(find.text('吃力程度 1–10'), findsOneWidget);
          expect(find.text('努力值'), findsNothing);
        }
        if (sheet == 'editset') {
          expect(find.text('附加负重 kg（0 = 只用自重）'), findsOneWidget);
          expect(
            tester.getSize(find.bySemanticsLabel('增加重量')).height,
            greaterThanOrEqualTo(44),
          );
        }
        if (sheet == 'advanced' || sheet == 'plan') {
          expect(find.byType(GroupCard), findsWidgets);
          expect(find.byType(GroupRow), findsWidgets);
        }
        expect(tester.takeException(), isNull);
        await h.shot(tester, 'r-sheet-$sheet-$scheme');
        await tester.pumpWidget(const SizedBox());
        debugDisableShadows = true;
      });
    }
  }

  testWidgets('edit set label and save preserve effort and record identity', (
    tester,
  ) async {
    final h = await Harness.pump(tester);
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '卧推',
      rows: [
        {'weight': 20, 'reps': 8, 'rpe': 7.5, 'type': '正式'},
      ],
    );
    final sets = h.controller.repo.day(h.controller.today)['sets'] as List;
    final original = Map<String, dynamic>.from(sets.last as Map);
    showAppSheet<void>(
      tester.element(find.byType(Navigator).first),
      (_) => EditSetSheet(set: original),
    );
    await settle(tester);
    expect(find.text('重量 kg（自重动作填 0）'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('增加重量'));
    await tester.tap(find.text('保存'));
    await settle(tester);
    final updated = (h.controller.repo.day(h.controller.today)['sets'] as List)
        .cast<Map>()
        .firstWhere((s) => s['id'] == original['id']);
    expect(updated['w'], 22.5);
    expect(updated['rpe'], 7.5);
    expect(updated['reps'], 8);
    expect(updated['type'], '正式');
    await tester.pump(const Duration(seconds: 3));
  });
}
