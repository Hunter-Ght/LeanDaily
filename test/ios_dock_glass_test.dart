import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/shell.dart';
import 'package:leandaily/ui/kit/glass.dart';
import 'package:leandaily/ui/kit/app_icon.dart';
import 'package:leandaily/ui/kit/ios_dock_glass.dart';
import 'package:leandaily/ui/kit/sheet.dart' show sheetDepth;

import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    // Rasterization runs on the real engine before widget fake-async zones.
    await AppIcon.navigationImages();
  });
  const channel = MethodChannel('leandaily/dock-glass');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform fallback keeps all four tabs working', (t) async {
      var queries = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            queries++;
            return false; // iOS 15–25 capability response.
          });
      final h = await Harness.pump(t);
      final dock = find.byType(Dock);
      expect(
        find.descendant(of: dock, matching: find.byType(GlassSurface)),
        findsOneWidget,
      );
      expect(find.byType(UiKitView), findsNothing);
      expect(queries, platform == TargetPlatform.iOS ? 1 : 0);
      for (final entry in [('记录', 1), ('进度', 2), ('我的', 3), ('今日', 0)]) {
        await t.tap(find.descendant(of: dock, matching: find.text(entry.$1)));
        await t.pumpAndSettle();
        expect(h.controller.tab, entry.$2);
      }
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final locale in const [
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
  ]) {
    testWidgets(
      'iOS 26 native selection synchronizes and disappears in wide rail $locale',
      (t) async {
        final created = <Object?>[];
        final updates = <Object?>[];
        final channels = <MethodChannel>[];
        addTearDown(() {
          for (final channel in channels) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null);
          }
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => true);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform_views, (
              call,
            ) async {
              if (call.method == 'create') {
                created.add(call.arguments);
                final id = (call.arguments as Map)['id'];
                final channel = MethodChannel('leandaily/dock-glass/$id');
                channels.add(channel);
                TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger
                    .setMockMethodCallHandler(channel, (call) async {
                      if (call.method == 'update') updates.add(call.arguments);
                      return null;
                    });
              }
              return null;
            });
        final h = await Harness.pump(t, locale: locale);
        expect(find.byType(IosDockGlass), findsOneWidget);
        expect(find.byType(UiKitView), findsOneWidget);
        expect(created, hasLength(1));
        final initial = (created.single as Map)['params'] as Uint8List;
        final config = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(initial),
        ) as Map;
        expect((updates.last as Map)['labels'], [
          for (final label in ['今日', '记录', '进度', '我的'])
            h.controller.messages.text(label),
        ]);
        expect(config['selected'], 0);
        final icons = config['icons'] as List;
        final sharedIcons = await AppIcon.navigationImages();
        expect(icons, hasLength(8));
        for (var i = 0; i < 8; i++) {
          expect(icons[i], orderedEquals(sharedIcons[i]));
        }
        // Progress has the shared concentric rings, including its selected form.
        expect(icons[4], isNot(orderedEquals(icons[5] as Uint8List)));
        final id = ((created.single as Map)['id'] as int);
        final nativeChannel = MethodChannel('leandaily/dock-glass/$id');
        // Native callbacks switch real pages; no duplicate Flutter tab buttons.
        expect(
          find.descendant(of: find.byType(Dock), matching: find.text('今日')),
          findsNothing,
        );
        for (final tab in [1, 2, 3, 0]) {
          await TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                nativeChannel.name,
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall('select', tab),
                ),
                (_) {},
              );
          await t.pumpAndSettle();
          expect(h.controller.tab, tab);
          expect((updates.last as Map)['selected'], tab);
        }
        h.controller.setTab(2);
        await t.pumpAndSettle();
        expect((updates.last as Map)['selected'], 2);
        // Tab rebuilds must not recreate the platform view.
        expect(created, hasLength(1));
        // Sheets use Flutter backdrop blur. Remove the native material for the
        // complete overlay animation, then restore it when the scene settles.
        sheetDepth.value = 0.5;
        await t.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        expect(
          find.descendant(
            of: find.byType(Dock),
            matching: find.byType(GlassSurface),
          ),
          findsOneWidget,
        );
        sheetDepth.value = 0;
        await t.pumpAndSettle();
        expect(find.byType(UiKitView), findsOneWidget);
        expect(created, hasLength(2));
        t.view.physicalSize = const Size(2000, 2000);
        await t.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets('missing iOS bridge safely keeps current glass', (t) async {
    await Harness.pump(t);
    expect(find.byType(UiKitView), findsNothing);
    expect(
      find.descendant(
        of: find.byType(Dock),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
