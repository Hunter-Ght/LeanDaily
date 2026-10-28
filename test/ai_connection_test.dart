import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:leandaily/config/ai_provider.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/ai_connection.dart';
import 'package:leandaily/data/ai_consent.dart';

void main() {
  test(
    'normalizes pasted endpoints and whitespace without weakening HTTPS',
    () {
      for (final suffix in ['', '/', '/responses', '/chat/completions']) {
        final result = normalizeAiSettings({
          ...openAiExample,
          'baseUrl': ' https://api.openai.com/v1$suffix ',
          'model': ' test-model ',
        });
        expect(result['baseUrl'], openAiExample['baseUrl']);
        expect(result['protocol'], 'responses');
        expect(result['model'], 'test-model');
      }
      expect(normalizeAiSettings(aiManualPreset)['baseUrl'], '');
      for (final url in [
        'http://example.test',
        'https://key@example.test',
        'https://example.test?key=secret',
      ]) {
        expect(() => normalizeAiSettings({'baseUrl': url}), throwsException);
      }
    },
  );
  for (final responses in [false, true]) {
    test(
      'connection test sends only fixed text and never authorizes photos: $responses',
      () async {
        final n = FakeNative();
        n.docs['private-record'] = 'private health data';
        final settings = {
          'baseUrl': 'https://example.test/v1',
          'model': 'test',
          'protocol': responses ? 'responses' : 'chat',
        };
        var count = 0;
        n.onHttp = (call) {
          count++;
          expect(call.headers['Authorization'], 'Bearer test-key');
          expect(call.body, isNot(contains('private health data')));
          final body = jsonDecode(call.body!) as Map;
          expect(
            responses ? body['input'] : body['messages'][0]['content'],
            'Reply with OK.',
          );
          return HttpReply(
            200,
            jsonEncode(
              responses
                  ? {
                      'output': [
                        {
                          'content': [
                            {'type': 'output_text', 'text': 'OK'},
                          ],
                        },
                      ],
                    }
                  : {
                      'choices': [
                        {
                          'message': {'content': 'OK'},
                        },
                      ],
                    },
            ),
          );
        };
        await checkAiConnection(n, settings, ' test-key ');
        expect(count, 1);
        expect(await AiConsent(n).granted(settings), false);
        expect(n.secrets.modelKey, '');
      },
    );
  }
  test(
    'iOS legacy provider is rejected before any network or key forwarding',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final n = FakeNative();
        var sent = 0;
        n.onHttp = (_) {
          sent++;
          return const HttpReply(200, '{"output_text":"OK"}');
        };
        await expectLater(
          checkAiConnection(n, geminiExample, 'private-test-key'),
          throwsException,
        );
        await expectLater(
          checkAiConnection(n, {
            'baseUrl': 'https://example.test/v1',
            'model': 'test',
          }, 'private-test-key'),
          throwsException,
        );
        expect(sent, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  test(
    'bad keys, quota, unsupported models and malformed success fail safely',
    () async {
      final n = FakeNative();
      for (final status in [401, 403, 404, 429, 500, 200]) {
        n.onHttp = (_) =>
            HttpReply(status, '{"error":{"message":"secret-test-key"}}');
        try {
          await checkAiConnection(n, {
            ...openAiExample,
            'model': 'test',
          }, 'test-key');
          fail('must reject HTTP $status without valid model output');
        } catch (e) {
          expect('$e', isNot(contains('secret-test-key')));
        }
      }
    },
  );
}
