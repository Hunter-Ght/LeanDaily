import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/ui/kit/guide_image.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/guide_sheet.dart';
import 'package:leandaily/ui/today/guide_body.dart';
import 'package:leandaily/ui/today/today_page.dart';

import 'support/harness.dart';

/// Real image bytes, but independently gated reads: no warm-cache shortcuts.
class _DelayedFrames extends CachingAssetBundle {
  _DelayedFrames(List<String> frames)
    : gates = {for (final path in frames) path: Completer<void>()};
  final Map<String, Completer<void>> gates;
  final requested = <String>{};
  @override
  Future<ByteData> load(String key) async {
    if (gates.containsKey(key)) {
      requested.add(key);
      await gates[key]!.future;
    }
    return rootBundle.load(key);
  }
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final wideBody in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          'cold guide keeps layout and visible frame $platform wide=$wideBody dark=$dark',
          (t) async {
            final h = await Harness.pump(t, dark: dark);
            final context = t.element(find.byType(TodayPage));
            final frames = (guideFor({'name': '高位俯卧撑'})!['frames'] as List)
                .cast<String>();
            final bundle = _DelayedFrames(frames);
            const rootKey = ValueKey('cold-guide-under-test');
            showAppSheet<void>(
              context,
              (_) => DefaultAssetBundle(
                key: rootKey,
                bundle: bundle,
                child: wideBody
                    ? AppSheet(
                        title: '动作',
                        child: GuideBody(
                          exercise: {
                            'name': '高位俯卧撑',
                            'part': '胸',
                            'sets': 2,
                            'min': 8,
                            'max': 12,
                          },
                          iso: h.controller.today,
                        ),
                      )
                    : const GuideSheet(exercise: '高位俯卧撑'),
              ),
            );
            await t.pump();
            await t.pump(const Duration(milliseconds: 200));
            final root = find.byKey(rootKey);
            final image = find.descendant(
              of: root,
              matching: find.byType(GuideImage),
            );
            final raw = find.descendant(
              of: image,
              matching: find.byType(RawImage),
            );
            final heading = find.descendant(
              of: root,
              matching: find.text('怎么做'),
            );
            final reserved = t.getSize(image);
            // Compare within the moving sheet, not against the screen: its
            // entrance translation must not count as an image layout jump.
            double headingOffset() =>
                t.getTopLeft(heading).dy - t.getTopLeft(image).dy;
            final headingBefore = headingOffset();
            expect(reserved.height, greaterThan(100));
            // Both frames begin loading before playback reaches frame two.
            expect(bundle.requested, containsAll(frames));
            expect(t.widget<RawImage>(raw).image, isNull);

            bundle.gates[frames[0]]!.complete();
            await t.runAsync(
              () =>
                  precacheImage(AssetImage(frames[0], bundle: bundle), context),
            );
            await t.pump();
            await t.pump(const Duration(milliseconds: 250));
            final first = t.widget<RawImage>(raw).image;
            expect(first, isNotNull);
            expect(t.getSize(image), reserved);

            final headingLoaded = headingOffset();
            expect(headingLoaded, closeTo(headingBefore, 0.1));
            await t.pump(const Duration(milliseconds: 1200));
            expect(
              find.descendant(of: root, matching: find.text('发力')),
              findsOneWidget,
            );
            expect(t.getSize(image), reserved);
            expect(headingOffset(), closeTo(headingLoaded, 0.1));
            expect(t.widget<RawImage>(raw).image, same(first));
            final opacity = t.renderObject<RenderAnimatedOpacity>(
              find.descendant(
                of: image,
                matching: find.byType(AnimatedOpacity),
              ),
            );
            expect(
              opacity.opacity.value,
              1,
              reason: 'Do not fade out the retained frame',
            );

            bundle.gates[frames[1]]!.complete();
            await t.runAsync(
              () =>
                  precacheImage(AssetImage(frames[1], bundle: bundle), context),
            );
            await t.pump();
            expect(t.widget<RawImage>(raw).image, isNot(same(first)));
            expect(t.getSize(image), reserved);
            expect(headingOffset(), closeTo(headingLoaded, 0.1));
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }
}
