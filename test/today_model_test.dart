import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan.dart' as plan;
import 'package:leandaily/ui/today/today_model.dart';

void main() {
  test('今日快照保持领域目标、已做组数和场地覆盖', () async {
    final now = DateTime.parse('2026-10-16T09:00:00');
    final n = FakeNative(now: now);
    n.docs['android-state'] = jsonEncode(
      jsonDecode(
        File('test/fixtures/full_state.json').readAsStringSync(),
      )['state'],
    );
    n.docs['fw-plan-v1'] = (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map)['fw-plan-v1'] as String;
    final app = AppController(native: n, clock: () => now);
    addTearDown(app.dispose);
    await app.boot();
    var m = TodayModel(app);
    expect(m.train, isTrue);
    expect(m.started, isTrue);
    expect(m.prog['doneSets'], 2);
    expect(m.recovery, isNotEmpty);
    expect(m.firstOpen, 'e12');
    await app.patchDayState(app.today, {'venue': 'gym', 'lite': true});
    m = TodayModel(app);
    expect(m.workout['venue'], 'gym');
    expect(
      m.items.every(
        (i) => jsTruthy(i['ex']['core']) && !jsTruthy(i['ex']['optional']),
      ),
      isTrue,
    );
    expect(
      m.all.map((e) => e['name']),
      plan.exercisesFor(app.plan, m.workout, m.iso).map((e) => e['name']),
    );
    await app.patchDayState(app.today, {'override': 'rest'});
    m = TodayModel(app);
    expect(m.train, isFalse);
    expect(m.next, isNotNull);
    expect(m.items, isEmpty);
  });
}
