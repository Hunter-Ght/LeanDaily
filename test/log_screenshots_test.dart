import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';

import 'support/harness.dart';

/// 人体图数据和动作缩略图是异步加载的，截图前先备好。
Future<void> warmImages(WidgetTester tester) async {
  final images = find.descendant(
    of: find.byKey(const ValueKey('day-pager')),
    matching: find.byType(Image),
  );
  final provs = [for (final w in tester.widgetList<Image>(images)) w.image];
  final context = tester.element(find.byKey(const ValueKey('day-pager')));
  await tester.runAsync(() async {
    // 人体图数据已经在请求中，给真实 IO 一点时间。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final p in provs) {
      await precacheImage(p, context).timeout(const Duration(seconds: 3));
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

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
    await tester.pumpAndSettle();
    await h.shot(tester, 'log-long-light');
    final list = find.byKey(ValueKey('log-list-${h.controller.date}'));
    // 训练很长也能滑到底，最后一餐在训练块之后（按时间排序）。
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('编辑早餐'),
      600,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
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
                ? 820
                : 393,
            narrow
                ? 640
                : mode == 'log-inner'
                ? 1180
                : 852,
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
        await warmImages(tester);
        expect(tester.takeException(), isNull);
        await h.shot(tester, '$mode-${dark ? 'dark' : 'light'}');
        debugDisableShadows = true;
      });
    }
  }
}
