import '../../l10n/localized_text.dart';
import '../../config/ai_provider.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../core/native.dart';
import '../../data/ai_consent.dart';
import '../../data/ai_connection.dart';
import '../../domain/records.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/menu.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../../l10n/app_messages.dart';

/// 「AI 拍照识别」设置：服务商、接口、模型、API Key、测试连接与授权撤回。
/// 原先和备份、通用设置混在同一个弹层里，现在单独成页。
class AiSettingsSheet extends StatefulWidget {
  const AiSettingsSheet({super.key});
  @override
  State<AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<AiSettingsSheet> {
  Map<String, dynamic>? _cfg;
  String _modelKey = '', _error = '';
  bool _ready = false, _busy = false, _consented = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cfg != null) return;
    _cfg = Map.of(context.app.settings.value);
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final app = context.app;
      final keys = await app.settings.secrets();
      // 还没填有效接口地址时 granted 会抛错，等同于没授权过；不影响读取密钥。
      final consented = await AiConsent(app.native)
          .granted(app.settings.value)
          .catchError((Object _) => false);
      if (mounted) {
        setState(() {
          _modelKey = keys.modelKey;
          _consented = consented;
          _ready = true;
        });
      }
    } on Object {
      if (mounted) setState(() => _error = '无法读取密钥，请重启 APP 后重试');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final app = context.app;
    final settings = normalizeAiSettings(_cfg!);
    if ('${settings['baseUrl']}'.isNotEmpty && !aiProviderAllowed(settings)) {
      throw const DomainError('iOS 版仅支持 OpenAI 官方接口；请在设置中重新配置');
    }
    await app.settings.save(settings, Secrets(modelKey: _modelKey.trim()));
    _cfg = Map.of(app.settings.value);
    await app.resume();
    app.refreshRemindersNow();
    app.toast.show('设置已保存');
  });
  Future<void> _pickProvider() async {
    if (_busy || !_ready) return;
    final picked = await showActionMenu(
      context,
      title: '服务商',
      message: '选择后只会把示例填进下面的表单，保存前不会联网或授权。',
      actions: [
        for (final p in aiPresets)
          if (defaultTargetPlatform != TargetPlatform.iOS || p.id == 'openai')
            MenuAction(id: p.id, label: p.name),
        if (defaultTargetPlatform != TargetPlatform.iOS)
          const MenuAction(id: 'manual', label: '其他兼容服务（手动填写）'),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked.id == 'manual') return _useExample(aiManualPreset, '');
    final preset = aiPresets.firstWhere((p) => p.id == picked.id);
    return _useExample(preset.settings, preset.name);
  }

  Future<void> _useExample(Map<String, String> example, String provider) async {
    if (_busy || !_ready) return;
    final changedDestination =
        (example['baseUrl'] ?? '').replaceFirst(RegExp(r'/+$'), '') !=
        ('${_cfg!['baseUrl'] ?? ''}'.replaceFirst(RegExp(r'/+$'), ''));
    if (changedDestination &&
        ('${_cfg!['baseUrl']}'.isNotEmpty || _modelKey.isNotEmpty)) {
      final accepted = await showConfirm(
        context,
        title: provider.isEmpty ? '改为手动填写？' : '替换为 $provider 范例？',
        message: provider.isEmpty
            ? '接口地址和模型将清空，并清空当前输入的密钥。点击保存后才生效；不会发起识别或授权。'
            : '接口、模型和协议将替换为范例，并清空当前输入的密钥。点击保存后才生效；不会发起识别或授权。',
        confirm: provider.isEmpty ? '改为手动' : '使用范例',
      );
      if (!accepted || !mounted) return;
    }
    setState(() {
      _cfg!.addAll(example);
      if (changedDestination) _modelKey = '';
    });
  }

  Future<void> _testConnection() => _run(() async {
    final app = context.app;
    final settings = normalizeAiSettings(_cfg!);
    if (!aiProviderAllowed(settings)) {
      throw const DomainError('iOS 版仅支持 OpenAI 官方接口；请在设置中重新配置');
    }
    final destination = AiConsent.destination(settings);
    final agreed = await showConfirm(
      context,
      title: '测试 AI 连接？',
      message:
          '接收方：${aiProviderName(settings)}\n地址：$destination\n仅发送固定测试文字和 API Key，不发送照片、身体资料或记录。服务商会收到 IP 地址，可能产生少量 API 费用。这不会授权发送饮食照片。',
      confirm: '发送测试请求',
    );
    if (!agreed || !mounted) return;
    await checkAiConnection(app.native, settings, _modelKey);
    if (mounted) {
      setState(() => _cfg = settings);
      app.toast.show('连接成功；请保存设置。照片识别仍需单独授权。');
    }
  });

  /// 标签在左、输入框在右的一行，和普通设置行同高，不再“标签一行、输入框一行”。
  Widget _field(
    String label,
    String key, {
    String? placeholder,
    Widget? trailing,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: EdgeInsets.fromLTRB(16, 4, trailing == null ? 16 : 8, 4),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: LText(
            label,
            maxLines: 2,
            style: TextStyle(
              fontSize: 17,
              height: 1.25,
              color: context.pal.text,
            ),
          ),
        ),
        Expanded(
          child: FormInput(
            label: label,
            value: key == 'modelKey' ? _modelKey : '${_cfg![key] ?? ''}',
            autocorrect: false,
            align: TextAlign.left,
            fontSize: 15,
            placeholder: placeholder,
            onChanged: (v) => setState(() {
              if (key == 'modelKey') {
                _modelKey = v;
              } else {
                _cfg![key] = v;
                if (key == 'baseUrl') {
                  if (isOfficialOpenAi(_cfg!)) _cfg!['protocol'] = 'responses';
                  if (isOfficialGemini(_cfg!)) _cfg!['protocol'] = 'chat';
                }
              }
            }),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  /// API Key 输入框右侧的小“粘贴”按钮。
  Widget _pasteButton() {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('粘贴 API Key'),
      excludeSemantics: true,
      child: Pressable(
        onTap: _busy || !_ready ? null : _paste,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.fill2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: LText(
              '粘贴',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final key = data?.text?.trim() ?? '';
    if (key.isEmpty) {
      context.app.toast.show('剪贴板没有文本');
      return;
    }
    setState(() => _modelKey = key);
  }

  Widget _button(String s, Future<void> Function() action) =>
      GroupRow(label: s, onTap: _busy || !_ready ? null : () => _run(action));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final official = isOfficialOpenAi(_cfg!) || isOfficialGemini(_cfg!);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return AppSheet(
      title: 'AI 拍照识别',
      onSave: _save,
      saveEnabled: _ready && !_busy,
      confirmClose: () async => !_busy,
      padding: EdgeInsets.only(
        top: 12,
        bottom: 28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Reveal(
            visible: _error.isNotEmpty,
            child: _error.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FormHint(_error, error: true),
                  )
                : const SizedBox.shrink(),
          ),
          GroupCard(
            children: [
              GroupRow(
                label: '服务商',
                value: aiProviderLabel(_cfg!),
                onTap: _busy || !_ready ? null : _pickProvider,
              ),
              _field('接口地址', 'baseUrl', placeholder: openAiExample['baseUrl']),
              _field('模型名称', 'model', placeholder: openAiExample['model']),
              _field('API Key', 'modelKey', trailing: _pasteButton()),
              GroupRow(
                label: '测试 AI 连接',
                onTap: _busy || !_ready ? null : _testConnection,
              ),
              // 官方服务商的协议是固定的；只有自定义服务才需要手动选。
              if (!official && '${_cfg!['baseUrl'] ?? ''}'.trim().isNotEmpty)
                GroupRow(
                  label: '接口协议',
                  value: _cfg!['protocol'] == 'responses'
                      ? 'Responses'
                      : 'Chat Completions',
                  onTap: () async {
                    final picked = await showActionMenu(
                      context,
                      title: '接口协议',
                      actions: const [
                        MenuAction(id: 'chat', label: 'Chat Completions（兼容接口）'),
                        MenuAction(
                          id: 'responses',
                          label: 'Responses（OpenAI / 兼容接口）',
                        ),
                      ],
                    );
                    if (picked != null && mounted) {
                      setState(() => _cfg!['protocol'] = picked.id);
                    }
                  },
                ),
              if (aiDataPolicyUrl(_cfg!) != null)
                GroupRow(
                  label: aiDataPolicyLabel(_cfg!),
                  onTap: () =>
                      _run(() => app.native.openUrl(aiDataPolicyUrl(_cfg!)!)),
                ),
              if (_consented)
                _button('撤回 AI 照片授权', () async {
                  await AiConsent(app.native).revoke();
                  if (mounted) setState(() => _consented = false);
                  app.toast.show('已撤回授权，下次识别前会重新询问');
                }),
            ],
          ),
          // 表单下方只留最关键的一句；其余说明收进「说明」。
          if (isOfficialOpenAi(_cfg!))
            const GroupFooter(
              '使用你自己的 OpenAI API Key 和 API 额度；ChatGPT 订阅不等于 API 额度。示例不会自动启用或联网。',
            )
          else if (isOfficialGemini(_cfg!))
            const GroupFooter(
              '使用你自己的 Google AI Studio API Key；额度和可用性以 Google 官方说明为准。示例不会自动启用或联网。',
            )
          else if (ios)
            const GroupFooter(
              'iOS 版目前仅支持 OpenAI 官方接口（https://api.openai.com/v1），选择服务商后填写你的 API Key 即可。',
            )
          else
            const GroupFooter('接口地址填基础地址，不含 /chat/completions 或 /responses。'),
          const SizedBox(height: 8),
          _Explain(
            children: [
              if (ios && (isOfficialOpenAi(_cfg!) || isOfficialGemini(_cfg!)))
                const GroupFooter(
                  'iOS 版目前仅支持 OpenAI 官方接口（https://api.openai.com/v1），选择服务商后填写你的 API Key 即可。',
                ),
              GroupFooter(aiProviderDisclosure(_cfg!)),
              const GroupFooter(
                '识别由你手动发起，可能产生服务商费用。只发送所选照片、餐次和补充说明；撤回授权不会删除已发送的数据。API Key 只保存在本机安全存储。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 可展开的「说明」区：默认收起，点标题行展开。
class _Explain extends StatefulWidget {
  const _Explain({required this.children});
  final List<Widget> children;
  @override
  State<_Explain> createState() => _ExplainState();
}

class _ExplainState extends State<_Explain> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: AppMessages.of(context).text('说明'),
          excludeSemantics: true,
          child: Pressable(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: Row(
                children: [
                  LText(
                    '说明',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _open ? .25 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: AppIcon('right', size: 12, color: p.tertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
        Reveal(
          visible: _open,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, c) in widget.children.indexed) ...[
                      if (i > 0) const SizedBox(height: 4),
                      c,
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
