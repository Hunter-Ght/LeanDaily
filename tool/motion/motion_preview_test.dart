// 矢量动作示范预览：逐帧渲染成 PNG，再用 ffmpeg 拼成视频或联系表。
//   LEANDAILY_MOTION_DIR=out/motion TZ=Asia/Shanghai flutter test tool/motion/motion_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/motion_library.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/motion_demo.dart';

void main() {
  final dir = Platform.environment['LEANDAILY_MOTION_DIR'] ?? 'out/motion';
  final fps = int.parse(Platform.environment['LEANDAILY_MOTION_FPS'] ?? '30');
  testWidgets('render motion frames', (t) async {
    await t.runAsync(() async {
      for (final MapEntry(:key, value: spec) in motionLibrary.entries) {
        for (final (mode, palette) in [
          ('light', AppPalette.light),
          ('dark', AppPalette.dark),
        ]) {
          final out = Directory('$dir/$key-$mode')..createSync(recursive: true);
          final frames = (spec.period * fps).round();
          for (var i = 0; i < frames; i++) {
            final img = await renderMotionFrame(
              spec,
              i / fps,
              palette,
              const Size(360, 240),
              pixelRatio: 2,
            );
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/${i.toString().padLeft(4, '0')}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            img.dispose();
          }
        }
      }
    });
  });
}
