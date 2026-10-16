// 生成 README 用的界面截图：
//   LEANDAILY_TEST_FONT="/System/Library/Fonts/Hiragino Sans GB.ttc" TZ=Asia/Shanghai \
//     flutter test tool/readme_shots/readme_shots_test.dart
// 输出到 out/shots/readme-*.png，再由 tool/readme_shots/compose.mjs 排版成展示图。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leandaily/ui/stats/stats_page.dart';

import '../../test/support/harness.dart';
import '../../test/today_sheets_test.dart' show loadExerciseImages;

Map<String, dynamic> _profile() => {
  'sex': 'male',
  'age': 28,
  'heightCm': 175,
  'weightKg': 74,
  'bodyFatMethod': 'manual',
  'bodyFatPct': 19,
  'activity': 'light',
  'venue': 'both',
  'daysPerWeek': 3,
  'experience': 'new',
  'limits': <String>[],
};

String _body() {
  final entries = <Map<String, dynamic>>[];
  var w = 76.2;
  for (var i = 0; i < 70; i += 2) {
    final d = DateTime(2026, 10, 15).subtract(Duration(days: 70 - i));
    w -= .06 + (i % 6 == 0 ? .08 : 0);
    entries.add({
      'date':
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'weightKg': double.parse(w.toStringAsFixed(1)),
    });
  }
  return jsonEncode({'v': 1, 'entries': entries});
}

// 肌肉卡依赖异步读取的人体图资源；同一进程里连续跑两个场景时第二个读不到，
// 所以按配色分两次运行：README_SCHEME=light / dark（不设置则两种都跑）。
final _only = Platform.environment['README_SCHEME'];
Iterable<bool> get _schemes => [
  if (_only != 'dark') false,
  if (_only != 'light') true,
];

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in _schemes) {
    final scheme = dark ? 'dark' : 'light';
    testWidgets('readme muscle $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        tab: 2,
        size: const Size(393, 852),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode(_profile());
          n.docs['fw-body-v1'] = _body();
        },
      );
      await tester.pumpAndSettle();
      // 人体图路径是异步读资源文件的：给真实 IO 一点时间，肌肉卡才会出现。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      // 卡片是惰性构建的：先滚到可见，再把标题对齐到屏幕上部。
      for (var i = 0; i < 30 && find.text('肌肉状态').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(StatsPage), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await Scrollable.ensureVisible(
        tester.element(find.text('肌肉状态').first),
        alignment: 0.075,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await h.shot(tester, 'readme-muscle-$scheme');
    });
  }
  for (final dark in _schemes) {
    final scheme = dark ? 'dark' : 'light';
    testWidgets('readme today $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        size: const Size(393, 852),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode(_profile());
          n.docs['fw-body-v1'] = _body();
        },
      );
      await tester.pumpAndSettle();
      await loadExerciseImages(tester);
      await h.shot(tester, 'readme-today-$scheme');
    });
  }
  // 折叠屏内屏（约 7.8 英寸、接近方形）：825×887dp，会进入侧边导航 + 双栏布局。
  for (final tab in [0, 1]) {
    testWidgets('readme fold light tab$tab', (tester) async {
      if (_only == 'dark') return;
      final h = await Harness.pump(
        tester,
        tab: tab,
        size: const Size(825, 887),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode(_profile());
          n.docs['fw-body-v1'] = _body();
        },
      );
      // 内屏的状态栏比直板机矮，手势条也更细。
      const inset = FakeViewPadding(top: 56, bottom: 24);
      tester.view.padding = inset;
      tester.view.viewPadding = inset;
      await tester.pumpAndSettle();
      if (tab == 0) await loadExerciseImages(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      await h.shot(tester, 'readme-fold-${tab == 0 ? 'today' : 'log'}-light');
    });
  }
}
