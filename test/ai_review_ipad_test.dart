import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/config/ai_provider.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/ai_consent.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';

import 'meal_sheet_test.dart' show jpeg;
import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  for (final size in [
    const Size(820, 1180),
    const Size(1180, 820),
    const Size(393, 852),
  ]) {
    testWidgets(
      'iOS setup, explicit connection test and upload consent $size',
      (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        var sent = 0, photoSent = 0;
        final h = await Harness.pump(
          t,
          locale: const Locale('en'),
          size: size,
          empty: true,
          updateUrl: '',
          seed: (n) {
            n.pickResult = [jpeg];
            n.onHttp = (call) {
              sent++;
              final body = jsonDecode(call.body!) as Map;
              expect(call.url, 'https://api.openai.com/v1/responses');
              expect(body['store'], false);
              if (body['input'] is String) {
                return const HttpReply(200, '{"output_text":"OK"}');
              }
              photoSent++;
              return HttpReply(
                200,
                jsonEncode({
                  'output_text': jsonEncode({
                    'items': [
                      {
                        'name': 'Rice',
                        'portion': '1 bowl',
                        'kcal': 200,
                        'protein': 4,
                      },
                    ],
                    'basis': 'before_only',
                    'summary': 'Test estimate',
                    'confidence': '中',
                  }),
                }),
              );
            };
          },
        );
        final nav = t.element(find.byType(Navigator).first);
        openMealSheet(nav);
        await t.pumpAndSettle();
        final setup = find.text('Set up AI connection');
        await t.ensureVisible(setup);
        await t.tap(setup);
        await t.pumpAndSettle();
        final messages = AppMessages(const Locale('en'));
        final provider = find.text(messages.text('服务商'));
        await t.ensureVisible(provider);
        await t.tap(provider);
        await t.pumpAndSettle();
        expect(find.text('Google Gemini'), findsNothing);
        await t.tap(find.text('OpenAI').last);
        await t.pumpAndSettle();
        final keyField = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is FormInput && w.label == 'API Key',
          ),
          matching: find.byType(EditableText),
        );
        await t.ensureVisible(keyField);
        await t.enterText(keyField, 'test-only-key');
        t.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        final check = find.text('Test AI connection');
        await t.ensureVisible(check);
        await t.tap(check);
        await t.pumpAndSettle();
        expect(sent, 0);
        await t.tap(find.text('Cancel').last);
        await t.pumpAndSettle();
        expect(sent, 0);
        await t.tap(check);
        await t.pumpAndSettle();
        await t.tap(find.text('Send test request'));
        await t.pumpAndSettle();
        expect(sent, 1);
        expect(photoSent, 0);
        expect(h.native.docs[AiConsent.storageKey], isNull);
        await t.tap(find.text('Save').first);
        await t.pumpAndSettle();
        expect(
          h.controller.settings.value['baseUrl'],
          openAiExample['baseUrl'],
        );
        // Test the migration path too: a previous grant must not bypass the visible prompt.
        await AiConsent(h.native).grant(h.controller.settings.value);
        SheetController.of(t.element(find.byType(AndroidSettingsSheet)))
            .close();
        await t.pumpAndSettle();
        await t.tap(find.text(messages.text('相册')).first);
        await t.pumpAndSettle();
        // Use the catalog's current product wording rather than the translated guess.
        final button = find.text(messages.text('AI识别营养'));
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pumpAndSettle();
        expect(find.textContaining('api.openai.com'), findsOneWidget);
        expect(find.text('Agree & recognize').hitTestable(), findsOneWidget);
        expect(sent, 1);
        await h.shot(t, 'review-ai-consent-${size.width.toInt()}');
        await t.tap(find.text('Cancel').last);
        await t.pumpAndSettle();
        expect(photoSent, 0);
        await t.tap(button);
        await t.pumpAndSettle();
        await t.tap(find.text('Agree & recognize'));
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 600));
        await t.pumpAndSettle();
        expect(photoSent, 1);
        expect(find.text('Rice'), findsOneWidget);
        expect(t.takeException(), isNull);
        h.controller.vision.dispose();
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 4));
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  test('iOS denies legacy/custom endpoints, Android retains compatibility', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(aiProviderAllowed(openAiExample), true);
    expect(aiProviderAllowed(geminiExample), false);
    expect(aiProviderAllowed({'baseUrl': 'https://example.test/v1'}), false);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(aiProviderAllowed(geminiExample), true);
  });
}
