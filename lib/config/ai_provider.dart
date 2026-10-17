/// Optional example only: no credentials, network calls or automatic activation.
const openAiExample = <String, String>{
  'baseUrl': 'https://api.openai.com/v1',
  'model': 'gpt-6-luna',
  'protocol': 'responses',
};
const openAiDataPolicyUrl =
    'https://developers.openai.com/api/docs/guides/your-data';

bool isOfficialOpenAi(Map settings) {
  final uri = Uri.tryParse('${settings['baseUrl'] ?? ''}');
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'api.openai.com' &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.replaceFirst(RegExp(r'/+$'), '') == '/v1';
}

String aiProviderName(Map settings) =>
    isOfficialOpenAi(settings) ? 'OpenAI' : '自定义 AI 服务（非官方 OpenAI 范例）';

String aiProviderDisclosure(Map settings) => isOfficialOpenAi(settings)
    ? '接收方为 OpenAI。API 数据默认不用于训练，除非你向服务商主动选择共享。App 请求不保存响应，但滥用监测日志通常仍可保留最多 30 天，法律和安全例外可能更久；这不等于零留存。适用 OpenAI 的条款、数据政策和独立计费。'
    : '接收方是你填写的自定义服务，不能仅凭模型名认定它是 OpenAI。其保存、训练、删除和计费规则需由你向服务商核实。不要提交儿童照片或其他敏感个人信息。';
