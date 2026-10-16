import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/pressable.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/today_tip_card.dart';
import 'package:leandaily/ui/today/today_widgets.dart';

import 'support/harness.dart';

Map<String, dynamic> fourProfile() => {
  ...profileDefaults,
  'age': 30,
  'heightCm': 175,
  'weightKg': 75,
  'bodyFatMethod': 'manual',
  'bodyFatPct': 20,
};
Future<void> settleFour(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  testWidgets('无资料无近期饮食隐藏，近期饮食显示摄入值且没有进度条', (tester) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
    );
    expect(find.bySemanticsLabel(RegExp('展开营养条带')), findsNothing);
    await h.controller.repo.saveMeal(
      date: '2026-10-02',
      meal: '午餐',
      source: '手动填写',
      items: [
        {'name': '过期测试餐', 'kcal': 100, 'protein': 10},
      ],
    );
    await settleFour(tester);
    expect(find.bySemanticsLabel(RegExp('展开营养条带')), findsNothing);
    await h.controller.repo.saveMeal(
      date: h.controller.today,
      meal: '午餐',
      source: '手动填写',
      items: [
        {'name': '鸡蛋', 'kcal': 140, 'protein': 12},
      ],
    );
    await settleFour(tester);
    expect(find.text('已吃 140 千卡 · 蛋白 12 g'), findsOneWidget);
    expect(find.text('常吃'), findsNothing);
    await tester.tap(find.bySemanticsLabel(RegExp('展开营养条带')));
    await settleFour(tester);
    expect(find.text('常吃'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('收起营养条带')));
    await settleFour(tester);
    expect(find.text('常吃'), findsNothing);
  });
  testWidgets('有资料条带进度封顶，超出中性文案，每项首次达标反馈一次', (tester) async {
    final effects = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            effects.add('${call.arguments}');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode(fourProfile());
        n.docs['fw-targets-v1'] = jsonEncode({
          'kcalOverride': 1000,
          'proteinOverride': 100,
        });
      },
    );
    expect(find.text('0 / 100 g'), findsOneWidget);
    Future<String> add(num protein, num kcal) => h.controller.repo.saveMeal(
      date: h.controller.today,
      meal: '午餐',
      source: '手动填写',
      items: [
        {'name': '测试餐', 'kcal': kcal, 'protein': protein},
      ],
    );
    await add(100, 200);
    await settleFour(tester);
    expect(effects.where((e) => e.endsWith('lightImpact')), hasLength(1));
    await add(30, 920);
    await settleFour(tester);
    expect(effects.where((e) => e.endsWith('lightImpact')), hasLength(2));
    expect(find.text('超出 30'), findsOneWidget);
    expect(find.text('超出 120'), findsOneWidget);
    final bars = tester.widgetList<TodayBar>(find.byType(TodayBar)).toList();
    expect(bars.where((b) => b.value == 1).length, greaterThanOrEqualTo(2));
    final id = await add(1, 1);
    await settleFour(tester);
    await h.controller.repo.deleteMeal(h.controller.today, id);
    await settleFour(tester);
    expect(effects.where((e) => e.endsWith('lightImpact')), hasLength(2));
    await tester.pump(const Duration(seconds: 4));
  });
  testWidgets('体重提醒最低优先级，先不后当天消失且保存节流', (tester) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
      seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
    );
    expect(h.controller.shouldNudgeWeight, isTrue);
    await h.controller.patchDayState(h.controller.today, {'ready': 'tired'});
    await settleFour(tester);
    expect(
      tester.widget<TodayTipCard>(find.byType(TodayTipCard)).heading,
      '今天有点累',
    );
    expect(find.text('该称体重了'), findsNothing);
    await tester.tap(find.textContaining('条提示 ›'));
    await settleFour(tester);
    final tips = tester
        .widgetList<TodayTipCard>(find.byType(TodayTipCard))
        .toList();
    expect(tips.last.heading, '该称体重了');
    expect(tips.last.priority, 6);
    // 关闭（✕）是提醒行里的第二个可点元素。
    await tester.tap(
      find
          .descendant(
            of: find.byType(TodayNudgeRow),
            matching: find.byType(Pressable),
          )
          .last,
    );
    await settleFour(tester);
    expect(h.controller.shouldNudgeWeight, isFalse);
    expect(h.controller.weightNudgeUntil, '2026-10-19');
    expect(find.text('该称体重了'), findsNothing);
    expect(h.native.docs['fw-hints-v1'], contains('2026-10-19'));
  });
  testWidgets('本周标题与动作上次记录来自模型', (tester) async {
    final h = await Harness.pump(tester, size: const Size(393, 2300));
    expect(find.textContaining(RegExp(r'^本周 \d+/\d+ 天$')), findsOneWidget);
    final m = TodayModel(h.controller);
    for (final e in m.all) {
      final last = jsonMap(m.before['${e['id']}']?['last']);
      if (last.isEmpty) continue;
      final weight = jsNumber(last['weight']);
      expect(
        find.text(
          '上次 ${weight > 0 ? '${fmt(weight)} kg' : '自重'} × ${fmt(last['minReps'])}${e['unit'] == 'sec' ? ' 秒' : ''}',
        ),
        findsWidgets,
      );
    }
    expect(find.textContaining('每日约'), findsNothing);
    expect(find.textContaining('路线'), findsNothing);
  });
}
