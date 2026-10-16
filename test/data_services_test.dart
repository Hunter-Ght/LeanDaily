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
      final v = Vision(n);
      addTearDown(v.dispose);
      final result = await v.analyze([p], '备注', '早餐');
      expect(result['items'].single['protein'], 6.3);
      expect(result['items'].single['name'], '蛋');
    }
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
