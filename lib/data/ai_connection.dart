import 'dart:convert';

import '../config/ai_provider.dart';
import '../core/native.dart';
import '../domain/records.dart';
import 'ai_consent.dart';
import 'state_doc.dart';

/// Accept a base URL or a pasted full inference endpoint without duplicating
/// /responses or /chat/completions. Never guess a host or remove query secrets.
Map<String, dynamic> normalizeAiSettings(Map<String, dynamic> input) {
  final s = Map<String, dynamic>.from(input);
  var base = '${s['baseUrl'] ?? ''}'.trim().replaceFirst(RegExp(r'/+$'), '');
  for (final suffix in ['/chat/completions', '/responses']) {
    if (base.endsWith(suffix)) {
      base = base.substring(0, base.length - suffix.length);
      s['protocol'] = suffix == '/responses' ? 'responses' : 'chat';
      break;
    }
  }
  s['baseUrl'] = base;
  s['model'] = '${s['model'] ?? ''}'.trim();
  if (base.isNotEmpty && !base.startsWith('https://')) {
    throw const DomainError('模型接口必须使用 HTTPS');
  }
  if (base.isNotEmpty) AiConsent.destination(s);
  if (isOfficialOpenAi(s)) s['protocol'] = 'responses';
  if (isOfficialGemini(s)) s['protocol'] = 'chat';
  return s;
}

/// Only a fixed non-personal text is sent. No photo, journal or profile access.
/// Caller must first disclose recipient, credentials and possible usage fees.
Future<void> checkAiConnection(
  Native native,
  Map<String, dynamic> draft,
  String key,
) async {
  final s = normalizeAiSettings(draft);
  if (!aiProviderAllowed(s)) {
    throw const DomainError('iOS 版仅支持 OpenAI 官方接口；请在设置中重新配置');
  }
  if ('${s['baseUrl']}'.isEmpty ||
      '${s['model']}'.isEmpty ||
      key.trim().isEmpty) {
    throw const DomainError('请填写接口地址、模型名称和 API Key');
  }
  final responses = s['protocol'] == 'responses';
  final reply = await native.http(
    HttpCall(
      id: newId(),
      url:
          '${AiConsent.destination(s)}${responses ? '/responses' : '/chat/completions'}',
      method: 'POST',
      timeoutMs: 30000,
      headers: {
        'Authorization': 'Bearer ${key.trim()}',
        'Content-Type': 'application/json',
      },
      body: connectionBody(s, responses),
    ),
  );
  if (reply.status == 401 || reply.status == 403) {
    throw const DomainError('连接失败：请检查 API Key、服务地区和模型访问权限');
  }
  if (reply.status == 429) {
    throw const DomainError('连接失败：服务商额度不足或请求过于频繁，请检查 API 账单');
  }
  if (reply.status < 200 || reply.status >= 300) {
    throw const DomainError('连接失败：请检查接口地址、模型名称和协议');
  }
  if (!connectionHasText(reply.body, responses)) {
    throw const DomainError('服务未返回有效模型结果，请检查接口协议');
  }
}

String connectionBody(Map s, bool responses) => jsonEncode({
  'model': s['model'],
  if (isOfficialOpenAi(s)) 'store': false,
  if (responses)
    'input': 'Reply with OK.'
  else
    'messages': [
      {'role': 'user', 'content': 'Reply with OK.'},
    ],
});

bool connectionHasText(String body, bool responses) {
  try {
    final j = jsonDecode(body);
    if (responses) {
      if (j['output_text'] is String &&
          (j['output_text'] as String).trim().isNotEmpty) {
        return true;
      }
      return (j['output'] as List? ?? []).any(
        (o) => (o['content'] as List? ?? []).any(
          (c) =>
              c['type'] == 'output_text' &&
              c['text'] is String &&
              (c['text'] as String).trim().isNotEmpty,
        ),
      );
    }
    return (j['choices'] as List? ?? []).any(
      (c) =>
          c['message']?['content'] is String &&
          (c['message']['content'] as String).trim().isNotEmpty,
    );
  } on Object {
    return false;
  }
}
