import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
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
  test('provider label follows the endpoint, not a stored name', () {
    expect(aiProviderLabel({'baseUrl': ''}), '未设置');
    expect(aiProviderLabel(openAiExample), 'OpenAI');
    expect(aiProviderLabel(geminiExample), 'Google Gemini');
    expect(aiProviderLabel({'baseUrl': 'https://example.test/v1'}), '自定义');
    expect(aiPresets.map((p) => p.id), ['openai', 'gemini']);
    for (final p in aiPresets) {
      expect(p.settings.containsKey('modelKey'), isFalse);
    }
  });
  test('Gemini identity requires the official compatible endpoint', () {
    expect(isOfficialGemini(geminiExample), isTrue);
    expect(aiProviderName(geminiExample), 'Google Gemini');
    for (final base in [
      'https://generativelanguage.googleapis.com/v1beta',
      'https://generativelanguage.googleapis.com.evil.test/v1beta/openai',
      'https://generativelanguage.googleapis.com@evil.test/v1beta/openai',
      'https://generativelanguage.googleapis.com:444/v1beta/openai',
      'https://generativelanguage.googleapis.com/v1beta/openai?key=x',
    ]) {
      expect(isOfficialGemini({...geminiExample, 'baseUrl': base}), isFalse);
    }
  });
  test('Gemini sends images to chat completions only after consent', () async {
    final n = FakeNative();
    final settings = {...defaults, ...geminiExample};
    n.docs['android-settings'] = jsonEncode(settings);
    n.docs['fw-profile-v1'] = jsonEncode({'age': 30});
    n.secrets = const Secrets(modelKey: 'test-gemini-key');
    final photo = await n.photoWrite(Uint8List.fromList([255, 216, 255]));
    var sent = 0;
    n.onHttp = (call) {
      sent++;
      expect(
        call.url,
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      );
      final body = jsonDecode(call.body!) as Map;
      expect(body['model'], 'gemini-3.5-flash-lite');
      expect(body.containsKey('store'), false);
      expect(body['messages'][0]['content'][0]['type'], 'image_url');
      return HttpReply(
        200,
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '{"items":[{"name":"Rice","kcal":174,"protein":4.5}],"summary":"Estimate only"}',
              },
            },
          ],
        }),
      );
    };
    final v = Vision(n);
    addTearDown(v.dispose);
    await expectLater(v.analyze([photo]), throwsA(isA<Exception>()));
    expect(sent, 0);
    await AiConsent(n).grant(settings);
    await v.analyze([photo]);
    expect(sent, 1);
    for (final profile in [
      {'age': 17},
      <String, dynamic>{},
    ]) {
      n.docs['fw-profile-v1'] = jsonEncode(profile);
      await expectLater(v.analyze([photo]), throwsA(isA<Exception>()));
      expect(sent, 1);
    }
  });
  testWidgets('API key uses normal editing and long-press paste', (t) async {
    String clipboard = 'test-pasted-key';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard.isNotEmpty};
          }
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final h = await Harness.pump(
      t,
      locale: const Locale('en'),
      empty: true,
      updateUrl: '',
    );
    showAppSheet<void>(
      t.element(find.byType(Navigator).first),
      (_) => const AndroidSettingsSheet(),
    );
    await settle(t);
    final field = find.descendant(
      of: find.byWidgetPredicate((w) => w is FormInput && w.label == 'API Key'),
      matching: find.byType(EditableText),
    );
    await t.ensureVisible(field);
    await settle(t);
    final input = t.widget<EditableText>(field);
    expect(input.obscureText, false);
    expect(input.keyboardType, TextInputType.text);
    expect(input.autocorrect, false);
    await t.longPress(field);
    await settle(t);
    expect(find.text('Paste').hitTestable(), findsWidgets);
    final state = t.state<EditableTextState>(field);
    final paste = state.contextMenuButtonItems.firstWhere(
      (b) => b.type == ContextMenuButtonType.paste,
    );
    expect(paste.onPressed, isNotNull);
    paste.onPressed!();
    await settle(t);
    expect(t.widget<EditableText>(field).controller.text, 'test-pasted-key');
    clipboard = 'test-button-paste';
    FocusManager.instance.primaryFocus?.unfocus();
    t.testTextInput.hide();
    await settle(t);
    await t.ensureVisible(find.bySemanticsLabel('Paste API key'));
    await t.tap(find.bySemanticsLabel('Paste API key'));
    await settle(t);
    expect(t.widget<EditableText>(field).controller.text, 'test-button-paste');
    expect(h.native.secrets.modelKey, isEmpty);
  });
  testWidgets('Gemini example changes draft and clears the old provider key', (
    t,
  ) async {
    final h = await Harness.pump(
      t,
      empty: true,
      updateUrl: '',
      seed: (n) {
        n.docs['android-settings'] = jsonEncode({
          ...defaults,
          ...openAiExample,
        });
        n.secrets = const Secrets(modelKey: 'old-test-key');
      },
    );
    showAppSheet<void>(
      t.element(find.byType(Navigator).first),
      (_) => const AndroidSettingsSheet(),
    );
    await settle(t);
    final button = find.text('服务商');
    await t.ensureVisible(button);
    await settle(t);
    await t.tap(button);
    await settle(t);
    await t.tap(find.text('Google Gemini').last);
    await settle(t);
    await t.tap(find.text('使用范例'));
    await settle(t);
    final fields = t.widgetList<FormInput>(find.byType(FormInput));
    expect(
      fields.firstWhere((f) => f.label == '接口地址').value,
      geminiExample['baseUrl'],
    );
    expect(fields.firstWhere((f) => f.label == 'API Key').value, isEmpty);
    expect(h.native.secrets.modelKey, 'old-test-key');
    expect(h.controller.settings.value['protocol'], 'responses');
    await t.ensureVisible(
      find.byWidgetPredicate((w) => w is FormInput && w.label == 'API Key'),
    );
    await settle(t);
    await h.shot(t, 'gemini-settings-zh');
    await t.tap(find.text('保存').first);
    await settle(t);
    expect(h.controller.settings.value['protocol'], 'chat');
    expect(h.native.secrets.modelKey, isEmpty);
    expect(await AiConsent(h.native).granted(geminiExample), false);
    await t.pump(const Duration(seconds: 4));
  });
  test('updated disclosure invalidates the old consent fingerprint', () async {
    final n = FakeNative();
    n.docs[AiConsent.storageKey] = sha256(
      utf8.encode('2|${openAiExample['baseUrl']}|responses'),
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
      final example = find.text('服务商');
      await t.ensureVisible(example);
      await settle(t);
      await t.tap(example);
      await settle(t);
      await t.tap(find.text('OpenAI').last);
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
    testWidgets('Gemini data terms and actions fit at small width: $locale', (
      t,
    ) async {
      final h = await Harness.pump(
        t,
        locale: locale,
        empty: true,
        updateUrl: '',
        size: const Size(320, 568),
      );
      showAppSheet<bool>(
        t.element(find.byType(Navigator).first),
        (_) => const AiConsentSheet(settings: geminiExample),
      );
      await settle(t);
      final messages = AppMessages(locale);
      final terms = find.text(messages.text('查看 Google Gemini 数据处理说明'));
      await t.ensureVisible(terms);
      await settle(t);
      expect(terms.hitTestable(), findsOneWidget);
      expect(find.text(messages.text('同意并识别')).hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await h.shot(t, 'gemini-consent-${messages.code}');
      await t.tap(find.text(messages.text('取消')).last);
      await settle(t);
      expect(await AiConsent(h.native).granted(geminiExample), isFalse);
    });
  }
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
        final recognize = find.text(m.text('AI识别营养'));
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
