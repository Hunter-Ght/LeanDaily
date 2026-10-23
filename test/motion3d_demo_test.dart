import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/ui/kit/guide_demo.dart';
import 'package:leandaily/ui/kit/guide_image.dart';
import 'package:leandaily/ui/kit/motion3d_demo.dart';

import 'motion_demo_ui_test.dart' show host;
import 'support/harness.dart';

// 给真实的资源读取、引擎解码留出时间；循环动画不能用 pumpAndSettle。
Future<void> decode(WidgetTester tester, [int milliseconds = 150]) async {
  await tester.runAsync(
    () => Future<void>.delayed(Duration(milliseconds: milliseconds)),
  );
  await tester.pump();
}

void main() {
  setUpAll(Harness.setUpAll);
  // 这里测真实的 3D 片段库。
  setUpAll(() => Motion3dLibrary.debugOverride(null));
  const squat = {'name': '深蹲', 'part': '腿'};
  Motion3dDemoState state(WidgetTester t) =>
      t.state<Motion3dDemoState>(find.byType(Motion3dDemo));

  testWidgets('3D 示范点击暂停、继续', (t) async {
    await t.pumpWidget(host(const ExerciseDemo(ex: squat)));
    await decode(t);
    await decode(t);
    expect(find.byType(Motion3dDemo), findsOneWidget);
    await t.pump(const Duration(milliseconds: 100));
    await decode(t);
    expect(state(t).debugFrame, greaterThan(0));
    await t.tap(find.byType(ExerciseDemo));
    await t.pump();
    final frozen = state(t).debugFrame;
    await t.pump(const Duration(seconds: 1));
    await decode(t);
    expect(state(t).debugFrame, frozen);
    expect(find.text('▶'), findsOneWidget);
    await t.tap(find.byType(ExerciseDemo));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await decode(t);
    expect(state(t).debugFrame, isNot(frozen));
    await t.pumpWidget(const SizedBox());
    await decode(t);
  });

  testWidgets('减少动态效果只显示峰值帧且不调度动画', (t) async {
    await t.pumpWidget(host(const ExerciseDemo(ex: squat), reduce: true));
    await decode(t);
    await decode(t, 1000);
    final clip = t.widget<Motion3dDemo>(find.byType(Motion3dDemo)).clip;
    // 停在峰值时刻所在的那一帧（停顿处的相同帧在文件里合并过，所以按时间比）。
    final shown = state(t).debugTime;
    expect(shown, lessThanOrEqualTo(clip.peakMs));
    expect(clip.phaseAt(shown), clip.phaseAt(clip.peakMs));
    expect(find.text('▶'), findsNothing);
    await t.pump(const Duration(seconds: 1));
    expect(state(t).debugTime, shown);
    expect(t.binding.hasScheduledFrame, isFalse);
    await t.pumpWidget(const SizedBox());
    await decode(t);
  });

  testWidgets('动作要点显示阶段，可切照片再切回 3D', (t) async {
    await t.pumpWidget(
      host(GuideDemo(guide: guideFor(squat)!, frame: 0, paused: true)),
    );
    await decode(t);
    await decode(t);
    expect(find.byType(Motion3dDemo), findsOneWidget);
    expect(find.text('起始 · 已暂停'), findsOneWidget);
    await t.tap(find.text('真人照片'));
    await t.pump();
    expect(find.byType(GuideImage), findsOneWidget);
    expect(find.byType(Motion3dDemo), findsNothing);
    await t.tap(find.text('动画示范'));
    await t.pump();
    await decode(t);
    expect(find.byType(Motion3dDemo), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await decode(t);
  });
}
