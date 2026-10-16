import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/state_doc.dart' show emptyState;
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/ui/today/today_model.dart';

import 'support/harness.dart';
import 'today_page_test.dart' show tapVisible;
import 'today_sheets_test.dart' show loadExerciseImages;

void seedDeload(FakeNative native) {
  final state = emptyState();
  final sets = <String, dynamic>{};
  for (var week = 0; week < 8; week++) {
    final date = shiftDate('2026-08-24', 7 * week);
    for (var set = 1; set <= 2; set++) {
      final id = '$week-$set';
      sets[id] = {
        'id': id,
        'date': date,
        'ts': DateTime.parse('${date}T09:00:00').millisecondsSinceEpoch,
        'ex': '哑铃卧推',
        'part': '胸',
        'no': set,
        'w': 20,
        'reps': 10,
        'type': '正式',
        'rpe': 8,
      };
    }
  }
  state['sets'] = sets;
  native.docs['android-state'] = jsonEncode(state);
  native.docs['fw-plan-day-v1'] = jsonEncode({
    for (final date in ['2026-10-06', '2026-10-08', '2026-10-10'])
      date: {'ready': 'tired'},
  });
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets(
      'deload ${dark ? 'dark' : 'light'} proposal, acceptance and persistence',
      (tester) async {
        final h = await Harness.pump(tester, dark: dark, seed: seedDeload);
        final app = h.controller;
        expect(app.progressOptions.level, 'some');
        expect(app.progressOptions.stage, isNull);
        expect(app.progressOptions.deloadActive, false);
        final model = TodayModel(app);
        final proposal = model.suggestions.firstWhere(
          (s) => s['kind'] == 'deload',
        );
        final load = model.suggestions.indexWhere((s) => s['kind'] == 'load');
        if (load >= 0) {
          expect(model.suggestions.indexOf(proposal), lessThan(load));
        }
        // Deload is the first non-safety tip for this representative history.
        if (find.text('这周可以减量一周').evaluate().isEmpty) {
          await tapVisible(tester, find.textContaining('条提示 ›'));
        }
        await Scrollable.ensureVisible(
          tester.element(find.text('这周可以减量一周')),
          alignment: .15,
        );
        await loadExerciseImages(tester);
        await tester.pumpAndSettle();
        await h.shot(tester, 'deload-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
        final ordinary = TodayModel(app).before;
        await tapVisible(tester, find.text('这周减量'));
        expect(app.progressOptions.deloadActive, true);
        expect(find.text('本周已减量，下周自动恢复'), findsOneWidget);
        expect(
          TodayModel(app).suggestions.where((s) => s['kind'] == 'deload'),
          isEmpty,
        );
        for (final entry in TodayModel(app).before.entries) {
          expect(
            entry.value['sets'],
            (jsNumber(ordinary[entry.key]!['sets']) - 1).clamp(1, 99),
          );
        }
        final saved = jsonMap(jsonDecode(h.native.docs['fw-progress-v1']!));
        expect(jsonMap(saved['deload']), {
          'week': '2026-10-12',
          'last': '2026-10-16',
        });
        final restart = AppController(
          native: h.native,
          clock: () => DateTime.parse(Harness.refTime),
        );
        await restart.boot();
        expect(restart.progressOptions.deloadActive, true);
        expect(restart.deloadState, app.deloadState);
        restart.dispose();
        final nextNative = FakeNative(
          now: DateTime.parse('2026-10-19T09:00:00'),
        )..docs.addAll(h.native.docs);
        final nextWeek = AppController(
          native: nextNative,
          clock: () => DateTime.parse('2026-10-19T09:00:00'),
        );
        await nextWeek.boot();
        expect(nextWeek.progressOptions.deloadActive, false);
        nextWeek.dispose();
        await tester.pump(const Duration(seconds: 4));
      },
    );
  }

  testWidgets(
    'deload decline records 14 day cooldown without changing targets',
    (tester) async {
      final h = await Harness.pump(tester, seed: seedDeload);
      final app = h.controller;
      final original = TodayModel(app).before;
      if (find.text('先不').evaluate().isEmpty) {
        await tapVisible(tester, find.textContaining('条提示 ›'));
      }
      await tapVisible(tester, find.text('先不'));
      expect(jsonMap(app.progress['declined'])['deload'], '2026-10-16');
      expect(app.progressOptions.deloadActive, false);
      expect(TodayModel(app).before, original);
      expect(
        TodayModel(app).suggestions.where((s) => s['kind'] == 'deload'),
        isEmpty,
      );
      expect(p.emptyProgress()['deload'], isNull);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  test('controller options reflect experience route age venue', () {
    final app = AppController(
      native: FakeNative(),
      clock: () => DateTime(2026, 10, 16),
    );
    addTearDown(app.dispose);
    app.profile = {'experience': 'trained', 'age': 17, 'venue': 'gym'};
    app.targets = {'stage': 'youth'};
    expect(app.progressOptions.level, 'trained');
    expect(app.progressOptions.youth, true);
    expect(app.progressOptions.age, 17);
    expect(app.progressOptions.venue, 'gym');
  });
}
