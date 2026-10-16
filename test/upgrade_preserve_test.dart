import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// 升级保全：老用户的计划原样保留，不被引导/模板覆盖。
void main() {
  setUpAll(Harness.setUpAll);

  Map<String, String> legacy() => (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map).cast<String, String>();

  testWidgets('legacy user keeps plan byte-for-byte, library holds it as 我的原始方案', (tester) async {
    final docs = legacy();
    final before = jsonDecode(docs['fw-plan-v1']!);
    final h = await Harness.pump(tester, newUser: true, seed: (n) => n.docs.addAll(docs));
    final app = h.controller;
    expect(app.booted, isTrue, reason: app.bootError);
    expect(app.needsOnboarding, isFalse);
    expect(app.showUpgradePrompt, isTrue);
    expect(app.plans.single['name'], '我的原始方案');
    expect(app.plans.single['source'], 'legacy');
    expect(app.plan, before);
    expect(jsonDecode(h.native.docs['fw-plan-v1']!), before);
    expect(h.native.docs.containsKey('fw-plan-legacy-v1'), isTrue);
  });

  testWidgets('adding a template does not replace the active plan; switching works and restore returns', (tester) async {
    final docs = legacy();
    final before = jsonDecode(docs['fw-plan-v1']!);
    final h = await Harness.pump(tester, newUser: true, seed: (n) => n.docs.addAll(docs));
    final app = h.controller;
    final id = await app.addTemplatePlan('bochi-ppl-3');
    expect(app.plans.length, 2);
    expect(app.plan, before);
    await app.usePlan(id);
    expect(app.plan, isNot(before));
    expect(jsonDecode(h.native.docs['fw-plan-v1']!), app.plan);
    await app.restoreLegacy();
    expect(app.plan, before);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('new user needs onboarding; completing creates the template plan', (tester) async {
    final h = await Harness.pump(tester, newUser: true);
    final app = h.controller;
    expect(app.needsOnboarding, isTrue);
    expect(app.plan, isNotEmpty);
    await app.completeOnboarding(profile: {'sex': 'male', 'age': 25, 'heightCm': 175, 'weightKg': 75, 'bodyFatPct': 20, 'bodyFatMethod': 'manual', 'venue': 'gym', 'daysPerWeek': 3, 'experience': 'new', 'activity': 'light'}, templateId: 'bochi-ppl-3');
    expect(app.needsOnboarding, isFalse);
    expect(app.plans.single['templateId'], 'bochi-ppl-3');
    expect(app.targets, isNotNull);
    expect(app.proteinGoal, greaterThan(100));
    expect((app.plan['protein'] as Map)['goal'], app.proteinGoal);
    await tester.pump(const Duration(seconds: 1));
  });
}
