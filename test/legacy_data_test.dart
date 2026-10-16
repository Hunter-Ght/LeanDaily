import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// 用 1.6.0（Web 版）真实写出的存储内容启动，三个标签页都不能出错。
void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('boots from legacy 1.6.0 documents and renders every tab', (tester) async {
    final legacy = (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map).cast<String, String>();
    final h = await Harness.pump(tester, empty: true, seed: (n) => n.docs.addAll(legacy));
    expect(h.controller.booted, isTrue, reason: h.controller.bootError);
    for (final tab in [1, 2, 0]) {
      h.controller.setTab(tab);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  // 折叠屏：外屏、内屏展开、窄屏小手机、横屏，所有标签都要能画出来。
  for (final size in const [Size(393, 850), Size(360, 640), Size(852, 850), Size(1180, 800), Size(2000, 900), Size(412, 915)]) {
    for (final empty in [false, true]) {
      testWidgets('renders all tabs at $size ${empty ? 'empty' : 'with data'}', (tester) async {
        final legacy = (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map).cast<String, String>();
        final h = await Harness.pump(tester, size: size, empty: true, seed: empty ? null : (n) => n.docs.addAll(legacy));
        expect(h.controller.booted, isTrue, reason: h.controller.bootError);
        for (final tab in [1, 2, 0]) {
          h.controller.setTab(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
        }
      });
    }
  }
}
