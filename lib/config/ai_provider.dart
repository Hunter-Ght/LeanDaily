import 'package:flutter/foundation.dart';

/// iOS distribution supports only an identified provider with documented data
/// controls. Legacy custom settings stay local and are never silently rerouted.
bool aiProviderAllowed(Map settings) =>
    defaultTargetPlatform != TargetPlatform.iOS || isOfficialOpenAi(settings);

/// Optional example only: no credentials, network calls or automatic activation.
const openAiExample = <String, String>{
  'baseUrl': 'https://api.openai.com/v1',
  'model': 'gpt-6-luna',
  'protocol': 'responses',
};
const geminiExample = <String, String>{
  'baseUrl': 'https://generativelanguage.googleapis.com/v1beta/openai/',
  'model': 'gemini-3.5-flash-lite',
  'protocol': 'chat',
};

/// 服务商快捷入口：只把示例填进表单，不保存、不联网、不授权。
class AiPreset {
  const AiPreset(this.id, this.name, this.settings);
  final String id, name;
  final Map<String, String> settings;
}

const aiPresets = <AiPreset>[
  AiPreset('openai', 'OpenAI', openAiExample),
  AiPreset('gemini', 'Google Gemini', geminiExample),
];

/// “其他兼容服务（手动填写）”：清空接口与模型。
const aiManualPreset = <String, String>{
  'baseUrl': '',
  'model': '',
  'protocol': 'chat',
};

const geminiDataPolicyUrl = 'https://ai.google.dev/gemini-api/terms';
const openAiDataPolicyUrl =
    'https://developers.openai.com/api/docs/guides/your-data';

bool _officialEndpoint(Map settings, String host, String path) {
  final uri = Uri.tryParse('${settings['baseUrl'] ?? ''}');
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == host &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.replaceFirst(RegExp(r'/+$'), '') == path;
}

bool isOfficialOpenAi(Map settings) =>
    _officialEndpoint(settings, 'api.openai.com', '/v1');

bool isOfficialGemini(Map settings) => _officialEndpoint(
  settings,
  'generativelanguage.googleapis.com',
  '/v1beta/openai',
);

/// 设置页“服务商”行右侧显示的名字；以接口地址为准。
String aiProviderLabel(Map settings) =>
    '${settings['baseUrl'] ?? ''}'.trim().isEmpty
    ? '未设置'
    : isOfficialOpenAi(settings)
    ? 'OpenAI'
    : isOfficialGemini(settings)
    ? 'Google Gemini'
    : '自定义';

String aiProviderName(Map settings) => isOfficialOpenAi(settings)
    ? 'OpenAI'
    : isOfficialGemini(settings)
    ? 'Google Gemini'
    : '自定义 AI 服务';

String? aiDataPolicyUrl(Map settings) => isOfficialOpenAi(settings)
    ? openAiDataPolicyUrl
    : isOfficialGemini(settings)
    ? geminiDataPolicyUrl
    : null;

String aiDataPolicyLabel(Map settings) =>
    isOfficialGemini(settings) ? '查看 Google Gemini 数据处理说明' : '查看 OpenAI 数据处理说明';

String aiProviderDisclosure(Map settings) => isOfficialOpenAi(settings)
    ? '接收方为 OpenAI。API 数据默认不用于训练，除非你向服务商主动选择共享。App 请求不保存响应，但滥用监测日志通常仍可保留最多 30 天，法律和安全例外可能更久；这不等于零留存。适用 OpenAI 的条款、数据政策和独立计费。'
    : isOfficialGemini(settings)
    ? '接收方为 Google Gemini。免费额度受地区、账号和配额限制，不保证永久免费。免费服务可能使用输入和输出改进产品及模型，并由人工审查；不要发送敏感、保密或个人信息。付费服务和部分地区适用不同数据条款。Google 要求 API 使用者年满 18 岁。请只提交不含人物或身份信息的普通食物照片和说明，勿包含健康状况、病史或儿童信息。'
    : '接收方是你填写的自定义服务，不能仅凭模型名认定它是官方服务。其保存、训练、删除和计费规则需由你向服务商核实。不要提交儿童照片或其他敏感个人信息。';
