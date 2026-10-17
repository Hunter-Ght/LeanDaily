import 'package:leandaily/data/ai_consent.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/vision.dart';
import 'package:leandaily/data/reminders.dart';
import 'package:leandaily/data/prefs.dart';
import 'package:leandaily/domain/records.dart';

void main() {
  test('vision chat and Responses use original prompt/schema and clean output', () async {
    final n = FakeNative();
    n.secrets = const Secrets(modelKey: 'key');
    final p = await n.photoWrite(Uint8List.fromList([255, 216, 255]));
    for (final protocol in ['chat', 'responses']) {
      n.docs['android-settings'] = jsonEncode({
        ...defaults,
        'baseUrl': 'https://api.x.ai/v1/',
        'model': 'model',
        'protocol': protocol,
      });
      n.onHttp = (c) {
        final b = jsonDecode(c.body!);
        expect(c.headers['Authorization'], 'Bearer key');
        expect(
          b.containsKey('store'),
          false,
        ); // Do not change custom-provider protocols.
        final content = (b[protocol == 'chat' ? 'messages' : 'input'] as List)
            .single['content'];
        expect(content.length, 2);
        expect(content.last['text'], contains('餐次：早餐\n补充说明：备注'));
        if (protocol == 'responses') {
          expect(b['reasoning'], {'effort': 'low'});
          expect(c.url, 'https://api.x.ai/v1/responses');
        }
        final text =
            '```json\n{"items":[{"name":" 蛋 ","protein":6.25}],"summary":"好","confidence":"高"}\n```';
        return HttpReply(
          200,
          jsonEncode(
            protocol == 'chat'
                ? {
                    'choices': [
                      {
                        'message': {
                          'content': [
                            {'text': text},
                          ],
                        },
                      },
                    ],
                  }
                : {
                    'output': [
                      {
                        'content': [
                          {'type': 'output_text', 'text': text},
                        ],
                      },
                    ],
                  },
          ),
        );
      };
      await AiConsent(
        n,
      ).grant(jsonDecode(n.docs['android-settings']!) as Map<String, dynamic>);
      final v = Vision(n);
      addTearDown(v.dispose);
      final result = await v.analyze([p], '备注', '早餐');
      expect(result['items'].single['protein'], 6.3);
      expect(result['items'].single['name'], '蛋');
    }
  });
  test(
    'vision labels before/after photos and reports how the result was reached',
    () async {
      final n = FakeNative();
      n.secrets = const Secrets(modelKey: 'key');
      n.docs['android-settings'] = jsonEncode({
        ...defaults,
        'baseUrl': 'https://example.test',
        'model': 'm',
      });
      final a = await n.photoWrite(Uint8List.fromList([255, 216, 255, 1]));
      final b = await n.photoWrite(Uint8List.fromList([255, 216, 255, 2]));
      final c = await n.photoWrite(Uint8List.fromList([255, 216, 255, 3]));
      late Map sent;
      n.onHttp = (call) {
        sent = jsonDecode(call.body!) as Map;
        final text = jsonEncode({
          'items': [
            {'name': '米饭', 'portion': '吃了约150g（剩1/4）', 'kcal': 174},
          ],
          'eaten_ratio': 0.75,
          'warning': '两组照片像是不同的餐',
          'summary': '好',
        });
        return HttpReply(
          200,
          jsonEncode({
            'choices': [
              {
                'message': {'content': text},
              },
            ],
          }),
        );
      };
      await AiConsent(
        n,
      ).grant(jsonDecode(n.docs['android-settings']!) as Map<String, dynamic>);
      final v = Vision(n);
      addTearDown(v.dispose);
      // 乱序传入：吃完后的在前，也必须按“吃之前 → 吃完后”排好并逐张标注。
      final compare = await v.analyze(
        [b, a, c],
        '',
        '午餐',
        null,
        ['after', 'before', 'before'],
      );
      final content = (sent['messages'] as List).single['content'] as List;
      expect(content.map((e) => e['type']), [
        'text',
        'image_url',
        'text',
        'image_url',
        'text',
        'image_url',
        'text',
      ]);
      expect(
        content.where((e) => e['type'] == 'text').map((e) => e['text']).take(3),
        ['第1张（吃之前）', '第2张（吃之前）', '第3张（吃完后）'],
      );
      expect(content.last['text'], contains('标注“吃之前”'));
      expect(compare['basis'], basisCompare);
      expect(compare['eaten_ratio'], 0.75);
      expect(compare['warning'], '两组照片像是不同的餐');

      final single = await v.analyze([a], '', '午餐', null, ['before']);
      final only =
          ((sent['messages'] as List).single['content'] as List).last['text'];
      expect(only, contains('没有吃完后的照片'));
      expect(single['basis'], basisBeforeOnly);
      expect(single.containsKey('eaten_ratio'), false);
      expect(single.containsKey('warning'), false);

      await expectLater(
        v.analyze([b], '', '午餐', null, ['after']),
        throwsA(
          isA<DomainError>().having(
            (e) => e.message,
            'message',
            contains('请先拍一张吃之前的'),
          ),
        ),
      );
    },
  );
  test('photo phases default to before and pending-after only applies to unsettled meals', () {
    expect(cleanPhases(null, 2), ['before', 'before']);
    expect(cleanPhases(['after', 'x'], 3), ['after', 'before', 'before']);
    expect(
      needsAfterPhoto({
        'photo_ids': ['p'],
      }),
      true,
    );
    expect(
      needsAfterPhoto({
        'photo_ids': ['p'],
        'after_skipped': true,
      }),
      false,
    );
    expect(
      needsAfterPhoto({
        'photo_ids': ['p', 'q'],
        'photo_phases': ['before', 'after'],
      }),
      false,
    );
    expect(needsAfterPhoto({'photo_ids': <String>[]}), false);
    expect(needsAfterPhoto({'items': []}), false);
  });
  test('vision cancellation prevents late result, failure status and missing config', () async {
    final n = FakeNative(), v = Vision(FakeNative());
    addTearDown(v.dispose);
    await expectLater(
      v.analyze([]),
      throwsA(
        isA<DomainError>().having((e) => e.message, 'message', '请先在设置中配置模型'),
      ),
    );
    n.docs['android-settings'] = jsonEncode({
      ...defaults,
      'baseUrl': 'https://example.test',
      'model': 'm',
    });
    n.secrets = const Secrets(modelKey: 'k');
    final reply = Completer<HttpReply>(), entered = Completer<void>();
    n.onHttp = (c) {
      entered.complete();
      return reply.future;
    };
    await AiConsent(n)
        .grant(jsonDecode(n.docs['android-settings']!) as Map<String, dynamic>);
    final vision = Vision(n);
    addTearDown(vision.dispose);
    final id = vision.startAnalysis([])['job']!;
    await entered.future;
    await vision.cancelAnalysis(id);
    reply.complete(
      const HttpReply(
        200,
        '{"choices":[{"message":{"content":"{\\"items\\":[{\\"name\\":\\"蛋\\"}]}"}}]}',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vision.analysisStatus(id)['cancelled'], true);
    expect(vision.analysisStatus(id)['done'], false);
    expect(n.cancelledHttp, contains(id));
    n.onHttp = (_) => const HttpReply(500, '{}');
    final bad = vision.startAnalysis([])['job']!;
    for (
      var i = 0;
      i < 10 && vision.analysisStatus(bad)['finished'] != true;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(vision.analysisStatus(bad)['error'], '识别失败，请检查接口、密钥和网络后手动重试');
  });
  test('reminders serialize cancellation, permissions and preserve rest on plan changes', () async {
    final n = FakeNative(), now = DateTime(2026, 10, 15);
    final r = Reminders(n, clock: () => now);
    final future = now.add(const Duration(minutes: 2));
    await Future.wait([
      r.scheduleRest(future.millisecondsSinceEpoch),
      r.scheduleRest(
        future.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      ),
    ]);
    expect(n.scheduled.single.id, 1);
    expect(
      n.scheduled.single.atMs,
      future.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
    );
    await r.applyPlan([
      PlanNote(id: 1000, title: '训练', body: '卧推', at: future),
    ]);
    expect(n.scheduled.length, 2);
    n.notifyGranted = false;
    await r.applyPlan([
      PlanNote(id: 1001, title: '训练', body: '卧推', at: future),
    ]);
    expect(n.scheduled.single.id, 1);
    await expectLater(
      r.scheduleRest(future.millisecondsSinceEpoch),
      throwsA(
        isA<DomainError>().having(
          (e) => e.message,
          'message',
          '锁屏提醒未开启，可在 APP 设置中开启',
        ),
      ),
    );
    expect(n.scheduled, isEmpty);
    await expectLater(r.enableReminders(), throwsA(isA<DomainError>()));
    await expectLater(r.enablePlanReminders(), throwsA(isA<DomainError>()));
    n.notifyGranted = true;
    await r.scheduleRest(future.millisecondsSinceEpoch);
    await r.scheduleRest(now.millisecondsSinceEpoch);
    expect(n.scheduled, isEmpty);
  });
}
