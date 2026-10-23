import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/guide_image.dart';
import 'package:leandaily/ui/kit/motion3d_demo.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/guide_content.dart';
import 'package:leandaily/ui/today/guide_body.dart';
import 'package:leandaily/ui/today/today_page.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  // 这里测的是照片示范（反向划船、硬拉、引体向上现在都有 3D）：声明“没有 3D 片段”走照片路径。
  setUp(() => Motion3dLibrary.debugOverride({}));
  tearDown(() => Motion3dLibrary.debugOverride(null));
  for (final wide in [false, true]) {
    for (final locale in AppMessages.locales) {
      testWidgets('template demos play and switch wide=$wide $locale', (
        t,
      ) async {
        final h = await Harness.pump(
          t,
          dark: wide,
          locale: locale,
          size: const Size(393, 852),
        );
        final context = t.element(find.byType(TodayPage));
        final name = ValueNotifier('反向划船');
        addTearDown(name.dispose);
        for (final n in ['反向划船', '硬拉', '引体向上']) {
          final frames = (guideFor({'name': n})!['frames'] as List)
              .cast<String>();
          await t.runAsync(() async {
            for (final path in frames) {
              await precacheImage(AssetImage(path), context);
            }
          });
        }
        showAppSheet<void>(
          context,
          (_) => AppSheet(
            title: '动作',
            child: ValueListenableBuilder<String>(
              valueListenable: name,
              builder: (_, n, _) {
                final e = <String, dynamic>{
                  'name': n,
                  'sets': 2,
                  'min': 8,
                  'max': 12,
                };
                return wide
                    ? GuideBody(exercise: e, iso: h.controller.today)
                    : SheetGuideBody(exercise: e, iso: h.controller.today);
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        final demo = find.byType(GuideImage);
        final messages = AppMessages(locale);
        final note = guideFor({'name': '反向划船'})!['demoNote'] as String;
        expect(find.text(messages.text(note)), findsOneWidget);
        final reserved = t.getSize(demo);
        for (final n in ['反向划船', '硬拉', '引体向上']) {
          name.value = n;
          await t.pumpAndSettle();
          expect(
            t.widget<GuideImage>(demo).frames,
            guideFor({'name': n})!['frames'],
          );
          if (n != '反向划船') expect(t.widget<GuideImage>(demo).frame, 0);
          final initialFrame = t.widget<GuideImage>(demo).frame;
          final raw = find.descendant(
            of: demo,
            matching: find.byType(RawImage),
          );
          final first = t.widget<RawImage>(raw).image;
          expect(first, isNotNull);
          await t.pump(const Duration(milliseconds: 1100));
          await t.pump();
          expect(t.widget<GuideImage>(demo).frame, 1 - initialFrame);
          expect(t.widget<RawImage>(raw).image, isNot(same(first)));
          expect(t.getSize(demo), reserved);
          await t.tap(demo);
          await t.pumpAndSettle();
          final pausedFrame = t.widget<GuideImage>(demo).frame;
          await t.pump(const Duration(milliseconds: 2200));
          expect(t.widget<GuideImage>(demo).frame, pausedFrame);
          if (n == '反向划船') {
            await h.shot(
              t,
              'template-guide-${wide ? 'wide' : 'sheet'}-${messages.code}',
            );
          } else {
            expect(find.text(messages.text(note)), findsNothing);
          }
          await t.tap(demo);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
