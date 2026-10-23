import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/badge.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/ui/kit/motion3d_demo.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  // 这里测的是照片示范：声明“没有 3D 片段”，走照片路径（3D 路径见 motion3d_demo_test）。
  setUp(() => Motion3dLibrary.debugOverride({}));
  tearDown(() => Motion3dLibrary.debugOverride(null));
  const exercise = {'name': '哑铃地板卧推', 'part': '胸'};
  int frame(WidgetTester t) =>
      t
              .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('demo-frame-0')),
              )
              .opacity ==
          1
      ? 0
      : 1;
  Widget host({
    bool reduce = false,
    bool ticker = true,
    bool visible = true,
    double size = 200,
    Map<String, dynamic> ex = exercise,
  }) => PaletteScope(
    palette: AppPalette.light,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: ticker,
          child: Visibility.maintain(
            visible: visible,
            child: Center(
              child: ExerciseDemo(ex: ex, size: size),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('1100ms 自动交替、450ms 淡入和点击暂停继续', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(host());
    expect(frame(t), 0);
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(t), 1);
    expect(
      t
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('demo-frame-1')))
          .duration,
      const Duration(milliseconds: 450),
    );
    await t.tap(find.byType(ExerciseDemo));
    await t.pump(const Duration(seconds: 4));
    expect(frame(t), 1);
    expect(find.bySemanticsLabel('继续播放示范'), findsOneWidget);
    await t.tap(find.byType(ExerciseDemo));
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(t), 0);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('反馈缩图不重置帧与1100ms播放节奏', (t) async {
    await t.pumpWidget(host());
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpWidget(host(size: 120));
    await t.pump(const Duration(milliseconds: 600));
    expect(frame(t), 1);
    await t.pumpWidget(host(size: 200));
    expect(frame(t), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('减少动态效果仅第一帧、仍能点按换帧、无示范回退', (t) async {
    await t.pumpWidget(host(reduce: true));
    await t.pump(const Duration(seconds: 4));
    expect(frame(t), 0);
    await t.tap(find.byType(ExerciseDemo));
    await t.pump();
    expect(frame(t), 1);
    await t.pump(const Duration(seconds: 4));
    expect(frame(t), 1);
    await t.pumpWidget(host(ex: const {'name': '没有示范的动作', 'part': '胸'}));
    expect(find.byType(ToneBadge), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('TickerMode、Visibility、后台暂停，恢复后重新计时', (t) async {
    await t.pumpWidget(host());
    await t.pumpWidget(host(ticker: false));
    await t.pump(const Duration(seconds: 4));
    expect(frame(t), 0);
    await t.pumpWidget(host(visible: false));
    await t.pump(const Duration(seconds: 4));
    expect(
      t
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('demo-frame-0'), skipOffstage: false),
          )
          .opacity,
      1,
    );
    await t.pumpWidget(host());
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(t), 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 4));
    expect(frame(t), 1);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump(const Duration(milliseconds: 1100));
    expect(frame(t), 0);
    await t.pumpWidget(const SizedBox());
  });
}
