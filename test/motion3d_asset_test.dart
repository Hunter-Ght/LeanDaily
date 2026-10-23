import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/motion3d_demo.dart';

void main() {
  testWidgets('3D 清单与 WebP 尺寸、帧数一致', (tester) async {
    await tester.runAsync(() async {
      final clips = await Motion3dLibrary.load();
      expect(clips, isNotEmpty);
      expect(identical(await Motion3dLibrary.load(), clips), isTrue);
      expect(identical(Motion3dLibrary.loaded, clips), isTrue);
      for (final clip in clips.values) {
        expect(File(clip.file).existsSync(), isTrue);
        expect(clip.frames, greaterThan(0));
        expect(clip.periodMs, greaterThan(0));
        expect(clip.peakMs, inInclusiveRange(0, clip.periodMs - 1));
        expect(clip.phases, isNotEmpty);
        expect(clip.phases.first.$1, 0);
        // 阶段名写在清单里，提取工具扫不到：这里确认三种语言都有。
        for (final (_, name) in clip.phases) {
          for (final lang in ['en', 'zh_Hant']) {
            final catalog = jsonDecode(
              File('assets/l10n/$lang.json').readAsStringSync(),
            ) as Map;
            expect(catalog.containsKey(name), isTrue, reason: '$lang: $name');
          }
        }
        var previous = -1;
        for (final phase in clip.phases) {
          expect(phase.$1, greaterThan(previous));
          expect(phase.$1, lessThan(clip.periodMs));
          previous = phase.$1;
        }
        final bytes = await rootBundle.load(clip.file);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          expect(codec.frameCount, clip.frames);
          // 各帧时长加起来就是一个循环：清单里的毫秒时刻才能和画面对上。
          var total = 0;
          for (var i = 0; i < codec.frameCount; i++) {
            final frame = await codec.getNextFrame();
            try {
              expect(frame.image.width, 448);
              expect(frame.image.height, 448);
              total += frame.duration.inMilliseconds;
            } finally {
              frame.image.dispose();
            }
          }
          expect(total, closeTo(clip.periodMs, 60), reason: clip.file);
        } finally {
          codec.dispose();
        }
      }
    });
  });
}
