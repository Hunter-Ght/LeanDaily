import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/main.dart' as app;

void main() {
  // 普通 test 保留未初始化的进程；testWidgets 会提前初始化 binding，掩盖启动顺序问题。
  test('冷启动入口先初始化 Flutter，再注册原生通道', () async {
    expect(BindingBase.debugBindingType(), isNull);
    await app.main();
    expect(WidgetsBinding.instance, isA<WidgetsFlutterBinding>());

    // 在首帧前卸下启动组件；本测试只验证真实入口的初始化顺序。
    runApp(const SizedBox.shrink());
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  });
}
