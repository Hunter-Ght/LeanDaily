import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/data/ai_consent.dart';
import 'package:leandaily/data/prefs.dart';
import 'package:leandaily/data/vision.dart';
import 'package:leandaily/core/native.dart';

import 'support/harness.dart';
import 'meal_sheet_test.dart' show jpeg;

void main() {
  setUpAll(Harness.setUpAll);
  test('device locale resolution and explicit overrides', () {
    expect(
      AppMessages.resolve('system', [const Locale('fr')]),
      const Locale('en'),
    );
    for (final region in ['TW', 'HK', 'MO']) {
      expect(
        AppMessages(AppMessages.resolve('system', [Locale('zh', region)])).code,
        'zh_Hant',
      );
    }
    expect(
      AppMessages(
        AppMessages.resolve('system', [
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'HK',
          ),
        ]),
      ).code,
      'zh_Hans',
    );
    expect(
      AppMessages(AppMessages.resolve('en', [const Locale('zh')])).code,
      'en',
    );
    expect(
      AppMessages(AppMessages.resolve('zh_Hant', [const Locale('en')])).code,
      'zh_Hant',
    );
  });
  test(
    'catalogs cover the source inventory and retain placeholder contracts',
    () {
      final sources = (jsonDecode(
        File('tool/l10n/source.json').readAsStringSync(),
      ) as List).cast<String>();
      final pattern = RegExp(r'\{p\d+\}');
      for (final code in ['en', 'zh_Hant']) {
        final catalog = (jsonDecode(
          File('assets/l10n/$code.json').readAsStringSync(),
        ) as Map).cast<String, String>();
        expect(
          sources.where((s) => !catalog.containsKey(s)),
          isEmpty,
          reason: '$code missing messages',
        );
        for (final source in sources) {
          final placeholders =
              pattern.allMatches(source).map((m) => m[0]).toList()..sort();
          final actual =
              pattern.allMatches(catalog[source]!).map((m) => m[0]).toList()
                ..sort();
          expect(actual, placeholders, reason: '$code: $source');
          expect(catalog[source]!.trim(), isNotEmpty, reason: '$code: $source');
        }
      }
    },
  );
  test('dynamic counts and food search preserve canonical food values', () {
    final en = AppMessages(const Locale('en'));
    expect(en.text('12 组'), '12 sets');
    expect(en.text('午餐'), 'Lunch');
    final foods = Foods.parse(File('assets/foods.json').readAsStringSync());
    final before = jsonEncode(foods.items);
    final rice = en.foodSearch(foods.items, 'rice');
    expect(rice, isNotEmpty);
    expect(rice.any((f) => '${f['name']}'.contains('米饭')), isTrue);
    final trad = AppMessages(AppMessages.locales[2]);
    expect(trad.foodSearch(foods.items, '雞'), isNotEmpty);
    expect(jsonEncode(foods.items), before);
  });
  test(
    'AI never sends before consent; endpoint/protocol changes require consent',
    () async {
      final n = FakeNative();
      n.docs['android-settings'] = jsonEncode({
        ...defaults,
        'baseUrl': 'https://example.test/v1',
        'model': 'vision',
      });
      n.secrets = const Secrets(modelKey: 'test');
      final v = Vision(n);
      addTearDown(v.dispose);
      var sent = 0;
      n.onHttp = (_) {
        sent++;
        return const HttpReply(
          200,
          '{"choices":[{"message":{"content":"{\\"items\\":[]}"}}]}',
        );
      };
      await expectLater(
        v.analyze(['photo-not-even-readable']),
        throwsA(isA<Exception>()),
      );
      expect(sent, 0);
      final settings = await Settings(n).load();
      final consent = AiConsent(n);
      await consent.grant(settings);
      expect(await consent.granted(settings), isTrue);
      expect(
        await consent.granted({
          ...settings,
          'baseUrl': 'https://another.test/v1',
        }),
        isFalse,
      );
      expect(
        await consent.granted({...settings, 'protocol': 'responses'}),
        isFalse,
      );
      await consent.revoke();
      expect(await consent.granted(settings), isFalse);
    },
  );
  testWidgets('language changes persist without rewriting existing records', (
    t,
  ) async {
    final h = await Harness.pump(
      t,
      locale: null,
      tab: 3,
      seed: (n) => n.docs['leandaily-language-v1'] = 'en',
    );
    expect(find.text('Language'), findsOneWidget);
    expect(
      t
          .widgetList<Semantics>(find.byType(Semantics))
          .any((w) => w.properties.label == 'Language English'),
      isTrue,
    );
    final record = h.native.docs['android-state'];
    final plan = h.native.docs['fw-plan-v1'];
    await h.controller.setLanguage('zh_Hant');
    await t.pumpAndSettle();
    expect(find.text('語言'), findsOneWidget);
    expect(h.native.docs['leandaily-language-v1'], 'zh_Hant');
    expect(h.native.docs['android-state'], record);
    expect(h.native.docs['fw-plan-v1'], plan);
  });
  for (final code in ['en', 'zh_Hant']) {
    for (final width in [320.0, 393.0]) {
      testWidgets('$code all tabs at width $width', (t) async {
        final h = await Harness.pump(
          t,
          locale: code == 'en'
              ? AppMessages.locales[0]
              : AppMessages.locales[2],
          size: Size(width, 850),
        );
        for (var tab = 0; tab < 4; tab++) {
          h.controller.setTab(tab);
          await t.pumpAndSettle();

          if (width == 393) await h.shot(t, '$code-tab-$tab');
        }
      });
    }
  }
  testWidgets(
    'AI consent dialog shows destination and declining prevents sending',
    (t) async {
      var sent = 0;
      final h = await Harness.pump(
        t,
        empty: true,
        updateUrl: '',
        seed: (n) {
          n.docs['android-settings'] = jsonEncode({
            ...defaults,
            'baseUrl': 'https://example.test/v1',
            'model': 'vision',
          });
          n.secrets = const Secrets(modelKey: 'test');
          n.pickResult = [jpeg];
          n.onHttp = (_) {
            sent++;
            return const HttpReply(500, '');
          };
        },
      );
      openMealSheet(t.element(find.byType(Navigator).first));
      await t.pumpAndSettle();
      await t.tap(find.text('相册').first);
      await t.pumpAndSettle();
      await t.tap(find.text('识别营养'));
      await t.pumpAndSettle();
      expect(find.text('发送照片给 AI 服务？'), findsOneWidget);
      expect(find.textContaining('https://example.test/v1'), findsOneWidget);
      expect(sent, 0);
      await t.tap(find.text('取消').last);
      await t.pumpAndSettle();
      expect(sent, 0);
      expect(
        await AiConsent(h.native).granted(h.controller.settings.value),
        isFalse,
      );
      expect(find.byType(MealSheet), findsOneWidget);
    },
  );
}
