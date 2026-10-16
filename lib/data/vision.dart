import 'dart:async';
import 'dart:convert';

import '../core/native.dart';
import '../domain/records.dart';
import 'http_request.dart' show request;
import 'prefs.dart';
import 'state_doc.dart';

const _prompt =
    '你是专业营养师。识别照片中的所有食物，估算每项份量、热量kcal、蛋白质g、碳水g、脂肪g。多张照片属于同一餐，不重复计算。中国菜考虑用油。只输出JSON：{"items":[{"name":"米饭","portion":"约200g","kcal":232,"protein":4.5,"carbs":51,"fat":0.6}],"summary":"一句话点评","confidence":"高|中|低"}';

class Vision {
  Vision(this.native);
  final Native native;
  final _jobs = <String, Map<String, dynamic>>{};
  final _timers = <Timer>[];
  bool _disposed = false;
  Map<String, String> startAnalysis(
    List<String> ids, [
    String note = '',
    String meal = '',
  ]) {
    final id = newId();
    final job = <String, dynamic>{
      'phase': '正在识别营养',
      'think': '',
      'done': false,
      'finished': false,
      'error': '',
      'cancelled': false,
    };
    _jobs[id] = job;
    analyze(ids, note, meal, id)
        .then((a) {
          if (job['cancelled'] != true) {
            job['analysis'] = a;
            job['done'] = true;
          }
        })
        .catchError((Object _) {
          if (job['cancelled'] != true) job['error'] = '识别失败，请检查接口、密钥和网络后手动重试';
        })
        .whenComplete(() {
          job['finished'] = true;
          if (!_disposed) {
            _timers.add(
              Timer(
                const Duration(milliseconds: 180000),
                () => _jobs.remove(id),
              ),
            );
          }
        });
    return {'job': id};
  }

  Map<String, dynamic> analysisStatus(String id) {
    final j = _jobs[id];
    if (j == null) throw const DomainError('识别已结束，请手动重试');
    return Map.unmodifiable(j);
  }

  Future<void> cancelAnalysis(String id) async {
    final j = _jobs[id];
    if (j != null) {
      j['cancelled'] = true;
      j['finished'] = true;
      j['error'] = '已取消识别';
    }
    await native.cancelHttp(id);
  }

  Future<Map<String, dynamic>> analyze(
    List<String> ids, [
    String note = '',
    String meal = '',
    String? jobId,
  ]) async {
    final id = jobId ?? newId(),
        settings = Settings(native),
        s = await settings.load(),
        key = (await native.secretsGet()).modelKey;
    if (!truthy(s['baseUrl']) || !truthy(s['model']) || key.isEmpty) {
      throw const DomainError('请先在设置中配置模型');
    }
    final images = <String>[];
    for (final path in ids) {
      images.add(
        'data:image/jpeg;base64,${base64Encode((await native.photoRead(path)).bytes)}',
      );
    }
    if (_jobs[id]?['cancelled'] == true) throw const DomainError('已取消');
    final text = '$_prompt\n餐次：$meal\n补充说明：${cut(note, 300)}',
        responses = s['protocol'] == 'responses';
    final content = <Map<String, dynamic>>[
      for (final url in images)
        responses
            ? {'type': 'input_image', 'image_url': url}
            : {
                'type': 'image_url',
                'image_url': {'url': url},
              },
      {'type': responses ? 'input_text' : 'text', 'text': text},
    ];
    final body = responses
        ? {
            'model': s['model'],
            'input': [
              {'role': 'user', 'content': content},
            ],
            if (Uri.parse(s['baseUrl'] as String).host == 'api.x.ai')
              'reasoning': {'effort': 'low'},
          }
        : {
            'model': s['model'],
            'messages': [
              {'role': 'user', 'content': content},
            ],
          };
    final j = await request(
      native,
      '${(s['baseUrl'] as String).replaceFirst(RegExp(r'/$'), '')}${responses ? '/responses' : '/chat/completions'}',
      method: 'POST',
      body: body,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      id: id,
    );
    Object? raw;
    if (responses) {
      raw = j['output_text'];
      if (!truthy(raw)) {
        raw = (j['output'] as List? ?? [])
            .expand((o) => (o['content'] as List? ?? []))
            .where((c) => c['type'] == 'output_text')
            .map((c) => c['text'])
            .join();
      }
    } else {
      final choices = j['choices'] as List?;
      raw = choices == null || choices.isEmpty
          ? null
          : choices.first['message']?['content'];
    }
    if (raw is List) raw = raw.map((x) => x['text'] ?? '').join();
    if (raw is! String) throw const DomainError('模型没有返回文字结果');
    raw = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      throw const DomainError('模型结果不是有效 JSON');
    }
    if (parsed is! Map ||
        parsed['items'] is! List ||
        (parsed['items'] as List).isEmpty) {
      throw const DomainError('模型没有识别出食物');
    }
    final items = cleanItems(parsed['items']);
    if (items.isEmpty) throw const DomainError('模型结果没有有效食物');
    return {
      'items': items,
      'summary': cut(truthy(parsed['summary']) ? parsed['summary'] : '', 600),
      'confidence': cut(
        truthy(parsed['confidence']) ? parsed['confidence'] : '',
        20,
      ),
    };
  }

  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}
