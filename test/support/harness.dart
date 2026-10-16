import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/ui/kit/app_icon.dart';

import 'fonts.dart';

/// 截图测试用的整套 App：FakeNative + 参考数据（fixtures/full_state.json，与 Web 参考截图同一份）。
class Harness {
  Harness._(this.native, this.controller, this.shotKey);

  final FakeNative native;
  final AppController controller;
  final GlobalKey shotKey;

  static const refTime = '2026-10-16T09:00:00';

  static Future<void> setUpAll() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestFonts();
    await AppIcon.load();
  }

  /// 把 App 画出来。[at] 是“现在”，[dark] 深色模式，[tab] 打开哪个标签（0 今日 1 记录 2 进度 3 我的）。
  /// [empty] 为 true 时不放参考记录（老用户、没有记录）；[newUser] 为 true 时什么都不放（全新安装，会进入引导）。
  static Future<Harness> pump(
    WidgetTester tester, {
    Size size = const Size(393, 850),
    bool dark = false,
    int tab = 0,
    String at = refTime,
    bool empty = false,
    bool newUser = false,
    void Function(FakeNative native)? seed,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    tester.platformDispatcher.platformBrightnessTestValue = dark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final now = DateTime.parse(at);
    final native = FakeNative(now: now);
    if (!newUser) {
      // 模拟一位已在用的老用户：有计划、已处理过引导，页面直接进主界面。
      final legacy = (jsonDecode(
        File('test/fixtures/legacy_store.json').readAsStringSync(),
      ) as Map).cast<String, String>();
      native.docs['fw-plan-v1'] = legacy['fw-plan-v1']!;
      native.docs['fw-onboarded-v1'] = '1';
      if (!empty) {
        final doc = jsonDecode(
          File('test/fixtures/full_state.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        native.docs['android-state'] = jsonEncode(doc['state']);
      }
    }
    seed?.call(native);
    final controller = AppController(native: native, clock: () => now);
    final key = GlobalKey();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: LeanDailyApp(
          controller: controller,
          fontFamily: testFontFamily,
          fontFamilyFallback: testFontFallback,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (tab != 0) {
      controller.setTab(tab);
      await tester.pumpAndSettle();
    }
    return Harness._(native, controller, key);
  }

  /// 写出 out/shots/NAME.png（2 倍图）。
  Future<void> shot(WidgetTester tester, String name) async {
    debugDisableShadows = false;
    await tester.pump();
    final boundary =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('out/shots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    debugDisableShadows = true;
  }
}
