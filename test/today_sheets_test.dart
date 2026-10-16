import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/today/today_page.dart';

import 'support/harness.dart';

Future<void> loadExerciseImages(WidgetTester tester) async {
  final context = tester.element(find.byType(TodayPage));
  await tester.runAsync(() async {
    for (final file
        in Directory('assets/exercises')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))) {
      await precacheImage(AssetImage(file.path), context);
      // ExerciseThumb uses decoded thumbnails rather than the full-size key.
      for (final size in [48, 56]) {
        await precacheImage(
          ResizeImage(AssetImage(file.path), width: size * 2),
          context,
        );
      }
    }
  });
  await tester.pumpAndSettle();
}

void todayTest(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    try {
      await callback(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    todayTest('预览与示范 $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        size: const Size(393, 1500),
      );
      await loadExerciseImages(tester);
      final context = tester.element(find.byType(TodayPage));
      openDayPreview(context, '2026-10-14');
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.textContaining('精简版只做：'), findsOneWidget);
      // 预览参考的视口为 850。
      tester.view.physicalSize = const Size(786, 1700);
      await tester.pumpAndSettle();
      await h.shot(tester, 'sheet-preview-$scheme');
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(786, 3000);
      await tester.pumpAndSettle();
      openGuide(context, '高位俯卧撑', iso: h.controller.today);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('怎么做'), findsOneWidget);
      if (find.text('发力').evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 1100));
      }
      await h.shot(tester, 'sheet-guide-$scheme');
      await tester.tap(find.bySemanticsLabel(RegExp('暂停示范')));
      await tester.pumpAndSettle();
      expect(find.textContaining('已暂停'), findsOneWidget);
      final frame = tester.widget<Text>(find.textContaining('已暂停')).data;
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.widget<Text>(find.textContaining('已暂停')).data, frame);
      await tester.ensureVisible(find.text('搜示范视频'));
      await tester.tap(find.text('搜示范视频'));
      await tester.pumpAndSettle();
      expect(h.native.opened.single, contains('search.bilibili.com'));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
