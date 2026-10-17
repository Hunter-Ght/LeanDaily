import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/config/ai_provider.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/core/sha256.dart';
import 'package:leandaily/data/ai_consent.dart';
import 'package:leandaily/data/prefs.dart';
import 'package:leandaily/data/vision.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';
import 'package:leandaily/ui/sheets/ai_consent_sheet.dart';
import 'package:leandaily/app/routes.dart';

import 'support/harness.dart';
import 'meal_sheet_test.dart' show jpeg;

Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  test(
    'official provider identity cannot be spoofed with model or host text',
    () {
      expect(isOfficialOpenAi(openAiExample), isTrue);
      expect(
        isOfficialOpenAi({
          ...openAiExample,
          'baseUrl': 'https://api.openai.com/v1/',
        }),
        isTrue,
      );
      for (final url in [
        'http://api.openai.com/v1',
        'https://api.openai.com.example.test/v1',
        'https://api.openai.com@evil.test/v1',
        'https://example.test/v1',
        'https://api.openai.com:444/v1',
        'https://api.openai.com/v1?key=value',
      ]) {
        expect(
          isOfficialOpenAi({...openAiExample, 'baseUrl': url}),
          isFalse,
          reason: url,
        );
      }
      expect(defaults['baseUrl'], isEmpty);
      expect(openAiExample.containsKey('modelKey'), isFalse);
    },
  );
  test('updated disclosure invalidates the old consent fingerprint', () async {
    final n = FakeNative();
    n.docs[AiConsent.storageKey] = sha256(
      utf8.encode('1|${openAiExample['baseUrl']}|responses'),
    );
    expect(await AiConsent(n).granted(openAiExample), isFalse);
    await AiConsent(n).grant(openAiExample);
    expect(await AiConsent(n).granted(openAiExample), isTrue);
  });
  for (final protocol in ['responses', 'chat']) {
    test('official $protocol requests disable response storage after consent', () async {
      final n = FakeNative();
      final settings = {...defaults, ...openAiExample, 'protocol': protocol};
      n.docs['android-settings'] = jsonEncode(settings);
      n.secrets = const Secrets(modelKey: 'test-only-key');
      final p = await n.photoWrite(Uint8List.fromList([255, 216, 255]));
      var sent = 0;
      n.onHttp = (call) {
        sent++;
        final body = jsonDecode(call.body!) as Map;
        expect(body['store'], false);
        expect(body.containsKey('previous_response_id'), false);
        expect(body.containsKey('background'), false);
        expect(
          call.url,
          '${openAiExample['baseUrl']}/${protocol == 'responses' ? 'responses' : 'chat/completions'}',
        );
        const text =
            '{"items":[{"name":"Rice","kcal":174,"protein":4.5}],"summary":"Estimate only"}';
        return HttpReply(
          200,
          jsonEncode(
            protocol == 'responses'
                ? {'output_text': text}
                : {
                    'choices': [
                      {
                        'message': {'content': text},
                      },
                    ],
                  },
          ),
        );
      };
      final v = Vision(n);
      addTearDown(v.dispose);
      await expectLater(v.analyze([p]), throwsA(isA<Exception>()));
      expect(sent, 0);
      await AiConsent(n).grant(settings);
      await v.analyze([p]);
      expect(sent, 1);
    });
  }
  testWidgets(
    'example only changes draft and clears a different provider key after confirmation',
    (t) async {
      final h = await Harness.pump(
        t,
        empty: true,
        updateUrl: '',
        seed: (n) {
          n.docs['android-settings'] = jsonEncode({
            ...defaults,
            'baseUrl': 'https://example.test/v1',
            'model': 'old-model',
          });
          n.secrets = const Secrets(modelKey: 'old-test-key');
        },
      );
      final before = h.native.docs['android-settings'];
      showAppSheet<void>(
        t.element(find.byType(Navigator).first),
        (_) => const AndroidSettingsSheet(),
      );
      await settle(t);
      final example = find.text('填入 OpenAI 范例');
      await t.ensureVisible(example);
      await settle(t);
      await t.tap(example);
      await settle(t);
      expect(find.text('替换为 OpenAI 范例？'), findsOneWidget);
      await t.tap(find.text('使用范例'));
      await settle(t);
      final fields = t.widgetList<FormInput>(find.byType(FormInput));
      expect(
        fields.firstWhere((w) => w.label == '接口地址').value,
        openAiExample['baseUrl'],
      );
      expect(fields.firstWhere((w) => w.label == 'API Key').value, isEmpty);
      expect(h.native.docs['android-settings'], before);
      expect(h.native.secrets.modelKey, 'old-test-key');
      expect(await AiConsent(h.native).granted(openAiExample), isFalse);
      await t.tap(find.text('保存').first);
      await settle(t);
      expect(h.controller.settings.value['baseUrl'], openAiExample['baseUrl']);
      expect(h.controller.settings.value['protocol'], 'responses');
      expect(h.native.secrets.modelKey, isEmpty);
      await t.pump(const Duration(seconds: 4));
    },
  );
  testWidgets(
    'long disclosure stays scrollable with large text and fixed actions',
    (t) async {
      final h = await Harness.pump(
        t,
        locale: const Locale('en'),
        empty: true,
        updateUrl: '',
        size: const Size(320, 568),
      );
      showAppSheet<bool>(
        t.element(find.byType(Navigator).first),
        (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.7)),
          child: const AiConsentSheet(settings: openAiExample),
        ),
      );
      await settle(t);
      final agree = find.text('Agree & recognize');
      expect(agree.hitTestable(), findsOneWidget);
      expect(find.text('Cancel').last.hitTestable(), findsOneWidget);
      final policy = find.text('Read OpenAI data controls');
      await t.ensureVisible(policy);
      await settle(t);
      expect(policy.hitTestable(), findsOneWidget);
      expect(agree.hitTestable(), findsOneWidget);
      expect(find.text('Cancel').last.hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(await AiConsent(h.native).granted(openAiExample), isFalse);
      await h.shot(t, 'ai-provider-large-text-en');
    },
  );
  for (final locale in AppMessages.locales) {
    testWidgets(
      'provider disclosure fits and declining sends nothing: $locale',
      (t) async {
        var sent = 0;
        final h = await Harness.pump(
          t,
          locale: locale,
          empty: true,
          updateUrl: '',
          size: const Size(320, 740),
          seed: (n) {
            n.docs['android-settings'] = jsonEncode({
              ...defaults,
              ...openAiExample,
            });
            n.secrets = const Secrets(modelKey: 'test-only-key');
            n.pickResult = [jpeg];
            n.onHttp = (_) {
              sent++;
              return const HttpReply(500, '');
            };
          },
        );
        final m = AppMessages(locale);
        openMealSheet(t.element(find.byType(Navigator).first));
        await settle(t);
        await t.tap(find.text(m.text('相册')).first);
        await settle(t);
        final recognize = find.text(m.text('识别营养'));
        await t.ensureVisible(recognize);
        await settle(t);
        await t.tap(recognize);
        await settle(t);
        expect(find.textContaining('api.openai.com'), findsOneWidget);
        expect(t.takeException(), isNull);
        await h.shot(t, 'ai-provider-consent-${m.code}');
        final cancel = find.text(m.text('取消')).last;
        await t.ensureVisible(cancel);
        await settle(t);
        await t.tap(cancel);
        await settle(t);
        expect(sent, 0);
        expect(
          await AiConsent(h.native).granted(h.controller.settings.value),
          isFalse,
        );
      },
    );
  }
}
