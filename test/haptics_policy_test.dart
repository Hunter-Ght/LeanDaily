import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHaptics haptics;
  late List<String> effects;
  late bool enabled;
  setUp(() {
    effects = [];
    enabled = true;
    haptics = AppHaptics(isEnabled: () => enabled);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            effects.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(() {
    haptics.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('训练达标为轻中双震，休息到点为轻轻双震', (tester) async {
    haptics.completed();
    await tester.pump();
    expect(effects, ['HapticFeedbackType.lightImpact']);
    await tester.pump(const Duration(milliseconds: 130));
    expect(effects, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
    effects.clear();
    haptics.restEnded();
    await tester.pump(const Duration(milliseconds: 130));
    expect(effects, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);
  });

  testWidgets('关闭触感立即取消后半次，重新打开不补震', (tester) async {
    haptics.completed();
    await tester.pump();
    haptics.enabledOverride = false;
    haptics.selection();
    haptics.saved();
    haptics.enabledOverride = true;
    await tester.pump(const Duration(milliseconds: 200));
    expect(effects, ['HapticFeedbackType.lightImpact']);
    enabled = false;
    haptics.enabledOverride = null;
    haptics.completed();
    await tester.pump(const Duration(milliseconds: 200));
    expect(effects, hasLength(1));
  });

  testWidgets('连续刻度节流，完成双震期间不叠加刻度', (tester) async {
    for (var i = 0; i < 20; i++) {
      haptics.tick();
    }
    await tester.pump();
    expect(effects, ['HapticFeedbackType.selectionClick']);
    effects.clear();
    haptics.completed();
    haptics.selection();
    haptics.tick();
    await tester.pump(const Duration(milliseconds: 130));
    expect(effects, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('进入后台取消后半次，后台不播放界面触感', (tester) async {
    haptics.completed();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    haptics.saved();
    haptics.restEnded();
    await tester.pump(const Duration(milliseconds: 200));
    expect(effects, ['HapticFeedbackType.lightImpact']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('计时器自然到点提醒一次，手动跳过不提醒', (tester) async {
    var done = 0;
    final rest = RestTimer((_, _) {}, () {
      done++;
      haptics.restEnded();
    });
    rest.start(30);
    rest.clear();
    await tester.pump(const Duration(seconds: 31));
    expect(done, 0);
    expect(effects, isEmpty);
    rest.start(30);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 130));
    expect(done, 1);
    expect(effects, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);
    rest.dispose();
  });
}
