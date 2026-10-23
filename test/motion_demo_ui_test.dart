import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/ui/kit/guide_demo.dart';
import 'package:leandaily/ui/kit/guide_image.dart';
import 'package:leandaily/ui/kit/motion_demo.dart';
import 'package:leandaily/domain/guide.dart';

import 'support/harness.dart';

Widget host(Widget child, {bool reduce = false, bool dark = false}) =>
    PaletteScope(
      palette: dark ? AppPalette.dark : AppPalette.light,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SizedBox(width: 360, child: child)),
        ),
      ),
    );

void main() {
  setUpAll(Harness.setUpAll);
  const pushup = {'name': '标准俯卧撑', 'part': '胸'};

  testWidgets('有矢量示范的动作播动画，点击暂停与继续', (t) async {
    await t.pumpWidget(host(const ExerciseDemo(ex: pushup)));
    expect(find.byType(MotionDemo), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-frame-0')), findsNothing);
    expect(t.widget<MotionDemo>(find.byType(MotionDemo)).paused, isFalse);
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byType(ExerciseDemo));
    await t.pump();
    expect(t.widget<MotionDemo>(find.byType(MotionDemo)).paused, isTrue);
    expect(find.text('▶'), findsOneWidget);
    await t.tap(find.byType(ExerciseDemo));
    await t.pump();
    expect(t.widget<MotionDemo>(find.byType(MotionDemo)).paused, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('减少动态效果：停在发力姿势，不显示播放键', (t) async {
    await t.pumpWidget(host(const ExerciseDemo(ex: pushup), reduce: true));
    final demo = t.widget<MotionDemo>(find.byType(MotionDemo));
    expect(demo.still, isTrue);
    expect(find.text('▶'), findsNothing);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('没有矢量示范的动作照旧两张照片', (t) async {
    await t.pumpWidget(
      host(const ExerciseDemo(ex: {'name': '哑铃地板卧推', 'part': '胸'})),
    );
    expect(find.byType(MotionDemo), findsNothing);
    expect(find.byKey(const ValueKey('demo-frame-0')), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('动作要点：默认动画、可切到真人照片再切回 dark=$dark', (t) async {
      final g = guideFor({'name': '侧平举'})!;
      await t.pumpWidget(
        host(GuideDemo(guide: g, frame: 0, paused: false), dark: dark),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(MotionDemo), findsOneWidget);
      expect(find.text('发力'), findsOneWidget);
      await t.tap(find.text('真人照片'));
      await t.pump();
      expect(find.byType(MotionDemo), findsNothing);
      expect(find.byType(GuideImage), findsOneWidget);
      await t.tap(find.text('动画示范'));
      await t.pump();
      expect(find.byType(MotionDemo), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
