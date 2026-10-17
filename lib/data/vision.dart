import 'dart:async';
import 'dart:convert';

import '../core/native.dart';
import '../domain/records.dart';
import 'http_request.dart' show request;
import 'prefs.dart';
import 'ai_consent.dart';
import 'state_doc.dart';

const _prompt =
    '你是专业营养师。识别照片中的所有食物，估算每项份量、热量kcal、蛋白质g、碳水g、脂肪g。多张照片属于同一餐，不重复计算。中国菜考虑用油。只输出JSON：{"items":[{"name":"米饭","portion":"约200g","kcal":232,"protein":4.5,"carbs":51,"fat":0.6}],"summary":"一句话点评","confidence":"高|中|低"}';

/// 只有吃之前的照片：没法知道吃了多少，明确告诉模型按全部吃完算，剩多少由用户在界面里再调。
const _promptBeforeOnly =
    '你是专业营养师。下面的照片都是用户开吃之前拍的，没有吃完后的照片。识别所有食物，估算每项整份的份量、热量kcal、蛋白质g、碳水g、脂肪g，按用户把这些全部吃完来算。多张照片属于同一餐，不重复计算。中国菜考虑用油。只输出JSON：{"items":[{"name":"米饭","portion":"约200g","kcal":232,"protein":4.5,"carbs":51,"fat":0.6}],"summary":"一句话点评","confidence":"高|中|低"}';

/// 吃之前 + 吃完后：让模型逐项算剩余比例，营养按“实际吃下的”给。
const _promptCompare =
    '你是专业营养师。下面是同一餐的照片：标注“吃之前”的是开吃前拍的，标注“吃完后”的是吃完后拍的。请这样做：1) 识别吃之前照片里的每项食物并估算整份份量；2) 对照吃完后的照片，估算每项剩下的比例；3) 按用户实际吃下的份量，给出每项的热量kcal、蛋白质g、碳水g、脂肪g（不是整份的数值）。portion 写实际吃下的份量，并注明剩余，例如“吃了约150g（剩1/4）”。汤、饮料、油脂这类从照片看不出剩多少的，按可见部分估算，并在 summary 里说明是估算。中国菜考虑用油。多张照片属于同一餐，不重复计算。如果吃之前和吃完后的照片明显不是同一餐，不要硬算，把原因写进 warning，并按吃之前的照片整份估算。只输出JSON：{"items":[{"name":"米饭","portion":"吃了约150g（剩1/4）","kcal":174,"protein":3.4,"carbs":38,"fat":0.5}],"eaten_ratio":0.75,"summary":"一句话点评","confidence":"高|中|低","warning":""}，其中 eaten_ratio 是整餐按热量算大约吃掉的比例（0到1）。';

class Vision {
  Vision(this.native);
  final Native native;
  String Function() outputLanguage = () => 'zh_Hans';
  final _jobs = <String, Map<String, dynamic>>{};
  final _timers = <Timer>[];
  bool _disposed = false;
  Map<String, String> startAnalysis(
    List<String> ids, [
    String note = '',
    String meal = '',
    List<String>? phases,
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
    analyze(ids, note, meal, id, phases)
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
    List<String>? phases,
  ]) async {
    final id = jobId ?? newId(),
        settings = Settings(native),
        s = await settings.load(),
        key = (await native.secretsGet()).modelKey;
    if (!truthy(s['baseUrl']) || !truthy(s['model']) || key.isEmpty) {
      throw const DomainError('请先在设置中配置模型');
    }
    if (!await AiConsent(native).granted(s)) {
      throw const DomainError('请先确认将照片发送到你配置的 AI 服务');
    }
    // 吃之前的排在前面、吃完后的在后面，每张前面带一句文字标注，模型不用猜哪张是哪张。
    final kinds = cleanPhases(phases, ids.length);
    final order = [
      for (final phase in [photoPhaseBefore, photoPhaseAfter])
        for (var i = 0; i < ids.length; i++)
          if (kinds[i] == phase) i,
    ];
    final compare = kinds.contains(photoPhaseAfter);
    if (compare && !kinds.contains(photoPhaseBefore)) {
      throw const DomainError('只有吃完后的照片没法判断吃了多少，请先拍一张吃之前的');
    }
    final images = <String>[];
    for (final i in order) {
      images.add(
        'data:image/jpeg;base64,${base64Encode((await native.photoRead(ids[i])).bytes)}',
      );
    }
    if (_jobs[id]?['cancelled'] == true) throw const DomainError('已取消');
    final prompt = compare
        ? _promptCompare
        : (phases == null ? _prompt : _promptBeforeOnly);
    final language = outputLanguage();
    final responseLanguage = language == 'en'
        ? 'English'
        : language == 'zh_Hant'
        ? 'Traditional Chinese'
        : language == 'zh_Hans'
        ? 'Simplified Chinese'
        : 'the language of the meal name and note; default to English';
    final text =
            '$prompt\n餐次：$meal\n补充说明：${cut(note, 300)}\nWrite human-readable food names, portions, summary and warnings in $responseLanguage. Preserve all JSON field names, numeric values and required confidence enum values.',
        responses = s['protocol'] == 'responses';
    final textType = responses ? 'input_text' : 'text';
    final content = <Map<String, dynamic>>[
      for (final (n, url) in images.indexed) ...[
        if (phases != null)
          {
            'type': textType,
            'text':
                '第${n + 1}张（${kinds[order[n]] == photoPhaseAfter ? '吃完后' : '吃之前'}）',
          },
        responses
            ? {'type': 'input_image', 'image_url': url}
            : {
                'type': 'image_url',
                'image_url': {'url': url},
              },
      ],
      {'type': textType, 'text': text},
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
    final ratio = number(parsed['eaten_ratio']);
    return {
      'items': items,
      'basis': compare ? basisCompare : basisBeforeOnly,
      if (compare && ratio.isFinite && ratio >= 0 && ratio <= 1)
        'eaten_ratio': ratio,
      if (compare && truthy(parsed['warning']))
        'warning': cut(parsed['warning'], 200),
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
