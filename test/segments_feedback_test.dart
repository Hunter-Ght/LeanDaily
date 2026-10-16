import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/haptics.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/prefs.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/segments.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> effects;
  late bool enabled;
  late AppHaptics haptics;
  setUp(() {
    enabled = true;
    effects = [];
    haptics = AppHaptics(isEnabled: () => enabled);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            effects.add(call.arguments as String);
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pumpSegments(
    WidgetTester tester,
    ValueChanged<int> changed,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(393, 850)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HapticScope(
            haptics: haptics,
            child: PaletteScope(
              palette: AppPalette.light,
              child: Center(
                child: SizedBox(
                  width: 330,
                  child: StatefulBuilder(
                    builder: (context, setState) => AppSegments(
                      labels: const ['正常', '有点累', '不舒服'],
                      selected: selected,
                      onChanged: (i) {
                        changed(i);
                        setState(() => selected = i);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('同项点击不震，新选项只震一次，关闭反馈后仍能选择', (tester) async {
    final values = <int>[];
    await pumpSegments(tester, values.add);
    await tester.tap(find.text('正常'));
    await tester.pumpAndSettle();
    expect(effects, isEmpty);
    expect(values, isEmpty);
    await tester.tap(find.text('有点累'));
    await tester.pumpAndSettle();
    expect(effects, ['HapticFeedbackType.selectionClick']);
    expect(values, [1]);
    enabled = false;
    await tester.tap(find.text('不舒服'));
    await tester.pumpAndSettle();
    expect(values, [1, 2]);
    expect(effects, hasLength(1));
  });

  testWidgets('拖动跨档有反馈，松手才提交一次，纵向操作不改值', (tester) async {
    final values = <int>[];
    await pumpSegments(tester, values.add);
    final control = find.byType(AppSegments);
    final left = tester.getTopLeft(control);
    final y = tester.getCenter(control).dy;
    final gesture = await tester.startGesture(Offset(left.dx + 45, y));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveTo(Offset(left.dx + 165, y));
    await tester.pump();
    await gesture.moveTo(Offset(left.dx + 275, y));
    await tester.pump();
    expect(values, isEmpty);
    expect(effects, hasLength(2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(values, [2]);
    await tester.drag(control, const Offset(3, 90));
    await tester.pumpAndSettle();
    expect(values, [2]);
    expect(effects, hasLength(2));
  });

  testWidgets('系统取消拖动会还原预览，不提交训练状态', (tester) async {
    final values = <int>[];
    await pumpSegments(tester, values.add);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('正常')),
    );
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(values, isEmpty);
    expect(tester.widget<AppSegments>(find.byType(AppSegments)).selected, 0);
  });

  test('触感偏好默认开启，保存后可跨启动读取', () async {
    final native = FakeNative();
    final settings = Settings(native);
    expect((await settings.load())['haptics'], true);
    await settings.save({...settings.value, 'haptics': false});
    expect((await Settings(native).load())['haptics'], false);
    enabled = false;
    haptics.saved();
    haptics.completed();
    await Future<void>.delayed(Duration.zero);
    expect(effects, isEmpty);
  });
}
