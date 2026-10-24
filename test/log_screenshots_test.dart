import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('long day lazy list reaches last meal without overflow', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      tab: 1,
      seed: (native) {
        final state =
            jsonDecode(native.docs['android-state']!) as Map<String, dynamic>;
        final sets = state['sets'] as Map;
        for (var ex = 0; ex < 24; ex++) {
          for (var row = 1; row <= 4; row++) {
            final id = 'long-$ex-$row';
            sets[id] = {
              'id': id,
              'date': '2026-10-16',
              'ts': ex * 100 + row,
              'part': '背',
              'ex': '长日动作$ex',
              'no': row,
              'w': 32.5,
              'reps': 12,
              'rpe': 8,
              'type': row == 1
                  ? '热身'
                  : row == 4
                  ? '递减'
                  : '正式',
              'flag': row == 3 ? 'pain' : 'form',
              'notes': '单边',
            };
          }
        }
        native.docs['android-state'] = jsonEncode(state);
      },
    );
    h.controller.showRecordSection('训练');
    await tester.pumpAndSettle();
    await h.shot(tester, 'log-long-light');
    final list = find.byKey(ValueKey('log-list-${h.controller.date}'));
    // 训练很长也没关系：切到饮食，第一餐直接就在眼前。
    await tester.scrollUntilVisible(
      find.text('记另一个动作'),
      600,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('day-section-switch')),
        matching: find.text('饮食'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('编辑早餐').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.shot(tester, 'log-long-bottom-light');
    debugDisableShadows = true;
  });
  for (final dark in [false, true]) {
    for (final mode in [
      'log',
      'log-yesterday',
      'log-month',
      'edit-set',
      'log-inner',
      'log-columns',
      'log-narrow-large',
      'log-narrow-en',
    ]) {
      testWidgets('$mode ${dark ? 'dark' : 'light'}', (tester) async {
        final narrow = mode.startsWith('log-narrow');
        if (narrow) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.4;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final h = await Harness.pump(
          tester,
          tab: 1,
          dark: dark,
          locale: mode == 'log-narrow-en'
              ? const Locale('en')
              : const Locale('zh', 'CN'),
          size: Size(
            narrow
                ? 320
                : mode == 'log-inner'
                ? 852
                : mode == 'log-columns'
                ? 1250
                : 393,
            850,
          ),
        );
        if (mode == 'log-yesterday') {
          h.controller.setDate('2026-10-15');
          await tester.pumpAndSettle();
        }
        if (mode == 'log-month') {
          await tester.tap(find.bySemanticsLabel('展开月历'));
          await tester.pumpAndSettle();
        }
        if (mode == 'edit-set') {
          final set =
              (h.controller.day['sets'] as List).first as Map<String, dynamic>;
          openEditSet(
            tester.element(find.byKey(const ValueKey('day-pager'))),
            set,
          );
          await tester.pumpAndSettle();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await h.shot(tester, '$mode-${dark ? 'dark' : 'light'}');
        debugDisableShadows = true;
      });
    }
  }
}
