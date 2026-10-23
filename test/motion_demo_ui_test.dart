import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/exercise_demo.dart';
import 'package:leandaily/ui/kit/motion_demo.dart';
import 'package:leandaily/domain/motion_library.dart';

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
  // 三个原型动作都已有 3D 示范；矢量版留作后备，这里直接测组件本身。
  testWidgets('矢量示范：播放、暂停与阶段标签', (t) async {
    await t.pumpWidget(
      host(
        const AspectRatio(
          aspectRatio: 1.5,
          child: MotionDemo(spec: lateralRaiseMotion, showPhase: true),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('发力'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pumpWidget(
      host(
        const AspectRatio(
          aspectRatio: 1.5,
          child: MotionDemo(
            spec: lateralRaiseMotion,
            showPhase: true,
            paused: true,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('发力 · 已暂停'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('矢量示范：减少动态效果时停在发力姿势、不调度动画', (t) async {
    await t.pumpWidget(
      host(
        const AspectRatio(
          aspectRatio: 1.5,
          child: MotionDemo(spec: pushupMotion, still: true, showPhase: true),
        ),
      ),
    );
    await t.pump();
    expect(find.text('发力'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('没有矢量示范的动作照旧两张照片', (t) async {
    await t.pumpWidget(
      host(const ExerciseDemo(ex: {'name': '哑铃地板卧推', 'part': '胸'})),
    );
    expect(find.byType(MotionDemo), findsNothing);
    expect(find.byKey(const ValueKey('demo-frame-0')), findsOneWidget);
  });
}
