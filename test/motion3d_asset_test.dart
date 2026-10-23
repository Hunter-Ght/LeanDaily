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
        expect(clip.period, greaterThan(0));
        expect(clip.peakFrame, inInclusiveRange(0, clip.frames - 1));
        expect(clip.phases, isNotEmpty);
        expect(clip.phases.first.$1, 0);
        var previous = -1;
        for (final phase in clip.phases) {
          expect(phase.$1, greaterThan(previous));
          expect(phase.$1, lessThan(clip.frames));
          previous = phase.$1;
        }
        final bytes = await rootBundle.load(clip.file);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        try {
          expect(codec.frameCount, clip.frames);
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, 256);
            expect(frame.image.height, 256);
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }
    });
  });
}
