import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/state_doc.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/ui/stats/weekly_review_card.dart';
import 'package:leandaily/ui/today/today_nutrition_strip.dart';
import 'package:leandaily/ui/today/today_tip_card.dart';

import 'support/harness.dart';

void seedReview(FakeNative n, {String stage = 'cut', bool weights = true}) {
  n.docs['fw-profile-v1'] = jsonEncode({
    ...profileDefaults,
    'age': stage == 'youth' ? 16 : 30,
    'heightCm': 180,
    'weightKg': stage == 'bulk' ? 60 : 80,
    'bodyFatMethod': 'manual',
    'bodyFatPct': stage == 'bulk' ? 10 : 28,
  });
  n.docs['fw-targets-v1'] = jsonEncode({
    'kcalOverride': 2400,
    'proteinOverride': 130,
  });
  final state = emptyState();
  for (var i = 0; i < 5; i++) {
    final date = '2026-10-${(5 + i).toString().padLeft(2, '0')}';
    state['meals']['m$i'] = {
      'id': 'm$i',
      'kcal': 2400,
      'protein': 125,
      'carbs': 260,
      'fat': 70,
      'date': date,
      'meal': '午餐',
      'time': '12:00',
      'photo_ids': [],
      'items': [
        {'name': '家常餐', 'kcal': 2400, 'protein': 125},
      ],
      'source': '手动填写',
      'note': '',
    };
  }
  for (var i = 0; i < 3; i++) {
    state['sets']['s$i'] = {
      'id': 's$i',
      'date': '2026-10-0${5 + i * 2}',
      'ts': 0,
      'ex': '俯卧撑',
      'part': '胸',
      'no': 1,
      'w': 0,
      'reps': 12,
      'type': '正式',
      'rpe': '',
      'notes': '',
    };
  }
  n.docs['android-state'] = jsonEncode(state);
  if (weights) {
    final kg = stage == 'bulk' ? 60.0 : 80.0;
    n.docs['fw-body-v1'] = jsonEncode({
      'v': 1,
      'entries': [
        {'date': '2026-09-28', 'weightKg': kg},
        {'date': '2026-10-01', 'weightKg': kg},
        {'date': '2026-10-05', 'weightKg': kg},
        {'date': '2026-10-08', 'weightKg': kg},
      ],
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets(
    'apply changes kcal, persists review and removes card on both pages',
    (tester) async {
      final h = await Harness.pump(
        tester,
        at: '2026-10-12T09:00:00',
        tab: 2,
        seed: seedReview,
      );
      expect(h.controller.targets?['stage'], 'cut');
      final original = h.controller.kcalGoal;
      expect(find.byType(WeeklyReviewCard), findsOneWidget);
      await tester.tap(find.text('应用：每日少 100 千卡'));
      await settle(tester);
      expect(h.controller.kcalGoal, original - 100);
      expect(h.controller.reviewDone, '2026-10-05');
      expect(jsonDecode(h.native.docs['fw-review-v1']!)['done'], '2026-10-05');
      expect(
        jsonDecode(h.native.docs['fw-targets-v1']!)['kcalOverride'],
        original - 100,
      );
      expect(find.byType(WeeklyReviewCard), findsNothing);
      expect(find.text('已调整：每日 2300 千卡'), findsOneWidget);
      h.controller.setTab(0);
      await settle(tester);
      expect(find.byType(WeeklyReviewCard), findsNothing);
    },
  );
  testWidgets('skip persists dismissal without kcal adjustment', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      at: '2026-10-12T09:00:00',
      tab: 2,
      seed: seedReview,
    );
    await tester.tap(find.text('先不调'));
    await settle(tester);
    expect(h.controller.kcalGoal, 2400);
    expect(jsonDecode(h.native.docs['fw-review-v1']!)['done'], '2026-10-05');
    expect(find.byType(WeeklyReviewCard), findsNothing);
  });
  testWidgets('no weights offers acknowledge and persists it', (tester) async {
    final h = await Harness.pump(
      tester,
      at: '2026-10-12T09:00:00',
      tab: 2,
      seed: (n) => seedReview(n, weights: false),
    );
    expect(find.textContaining('记体重能让回顾更准'), findsOneWidget);
    expect(find.text('先不调'), findsNothing);
    await tester.tap(find.text('知道了'));
    await settle(tester);
    expect(h.controller.reviewDone, '2026-10-05');
    expect(find.byType(WeeklyReviewCard), findsNothing);
  });
  testWidgets(
    'today safety and tired tips precede review, review precedes other tips',
    (tester) async {
      final h = await Harness.pump(
        tester,
        at: '2026-10-12T09:00:00',
        size: const Size(393, 1800),
        seed: seedReview,
      );
      expect(find.byType(WeeklyReviewCard), findsOneWidget);
      expect(
        tester.widget<TodayTipCard>(find.byType(TodayTipCard)).heading,
        '上周回顾',
      );
      for (final ready in ['tired', 'bad']) {
        await h.controller.patchDayState(h.controller.today, {'ready': ready});
        await settle(tester);
        expect(find.byType(WeeklyReviewCard), findsNothing);
        expect(
          tester.widget<TodayTipCard>(find.byType(TodayTipCard)).priority,
          ready == 'bad' ? 0 : 1,
        );
      }
      await h.controller.patchDayState(h.controller.today, {'ready': null});
      await settle(tester);
      expect(find.byType(WeeklyReviewCard), findsOneWidget);
    },
  );
  for (final stage in ['cut', 'trim', 'recomp', 'refine', 'bulk', 'youth']) {
    testWidgets('compact nutrition without duplicate route rows $stage', (
      tester,
    ) async {
      final h = await Harness.pump(
        tester,
        empty: true,
        size: const Size(393, 1800),
        seed: (n) => seedReview(n, stage: stage),
      );
      // Exercise the presentation contract independently of stage classification.
      h.controller.targets!['stage'] = stage;
      await h.controller.patchDayState(h.controller.today, {'warm': true});
      await settle(tester);
      final card = find.byType(TodayNutritionStrip);
      expect(card, findsOneWidget);
      expect(find.text('蛋白'), findsWidgets);
      expect(find.text('热量'), findsWidgets);
      expect(find.textContaining('每日约'), findsNothing);
      expect(find.textContaining('缺口'), findsNothing);
    });
  }
  for (final dark in [false, true]) {
    for (final mode in ['today', 'progress', 'bulk', 'nodata']) {
      testWidgets('review screenshot $mode $dark', (tester) async {
        final h = await Harness.pump(
          tester,
          at: '2026-10-12T09:00:00',
          tab: mode == 'today' ? 0 : 2,
          dark: dark,
          size: const Size(393, 852),
          seed: (n) => seedReview(
            n,
            stage: mode == 'bulk' ? 'bulk' : 'cut',
            weights: mode != 'nodata',
          ),
        );
        if (mode == 'today') {
          await Scrollable.ensureVisible(
            tester.element(find.byType(WeeklyReviewCard)),
            alignment: .55,
          );
          await settle(tester);
        }
        expect(find.byType(WeeklyReviewCard), findsOneWidget);
        await h.shot(tester, 'r-review-$mode-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
