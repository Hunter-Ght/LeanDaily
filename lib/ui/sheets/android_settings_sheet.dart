import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../config/app_info.dart';
import '../../core/native.dart';
import '../../data/backup.dart' as backup;
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/menu.dart';
import '../kit/sheet.dart';

class AndroidSettingsSheet extends StatefulWidget {
  const AndroidSettingsSheet({super.key});
  @override
  State<AndroidSettingsSheet> createState() => _AndroidSettingsSheetState();
}

class _AndroidSettingsSheetState extends State<AndroidSettingsSheet> {
  Map<String, dynamic>? _cfg;
  String _modelKey = '', _error = '';
  bool _ready = false, _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cfg != null) return;
    _cfg = Map.of(context.app.settings.value);
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final keys = await context.app.settings.secrets();
      if (mounted) {
        setState(() {
          _modelKey = keys.modelKey;
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
    await app.settings.save(_cfg!, Secrets(modelKey: _modelKey));
    _cfg = Map.of(app.settings.value);
    await app.resume();
    app.refreshRemindersNow();
    app.toast.show('设置已保存');
  });
  Future<void> _restore() => _run(() async {
    final app = context.app;
    final b = await backup.chooseBackup(app.native);
    if (!mounted) return;
    if (!await showConfirm(
      context,
      title: '恢复备份并替换手机记录？',
      message: '当前记录将被替换。密钥不会恢复。建议先导出当前备份。',
      confirm: '恢复',
      danger: true,
    )) {
      return;
    }
    await backup.restoreBackup(app.native, app.repo, b);
    await app.reminders.scheduleRest(0);
    await app.reloadAfterRestore();
    if (mounted) {
      _cfg = Map.of(app.settings.value);
      _modelKey = '';
      SheetController.of(context).close();
    }
  });
  Widget _field(
    String label,
    String key, {
    String? placeholder,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.pal.secondary),
        ),
        FormInput(
          label: label,
          value: key == 'modelKey' ? _modelKey : '${_cfg![key] ?? ''}',
          obscure: secret,
          align: TextAlign.left,
          placeholder: placeholder,
          onChanged: (v) => setState(() {
            if (key == 'modelKey') {
              _modelKey = v;
            } else {
              _cfg![key] = v;
            }
          }),
        ),
      ],
    ),
  );
  Widget _button(String s, Future<void> Function() action) =>
      GroupRow(label: s, onTap: _busy || !_ready ? null : () => _run(action));
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return AppSheet(
      title: '高级',
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
          const GroupFooter('记录和照片保存在这部手机。'),
          const GroupHeader('交互'),
          GroupCard(
            children: [
              GroupRow(
                label: '触感反馈',
                trailing: FormSwitch(
                  label: '触感反馈',
                  value: _cfg!['haptics'] != false,
                  onChanged: (v) => setState(() => _cfg!['haptics'] = v),
                ),
              ),
            ],
          ),
          const GroupFooter('切换选项、选择日期和完成训练时，给一次轻触反馈。'),
          const GroupHeader('备份与恢复'),
          GroupCard(
            children: [
              _button('导出备份', () async {
                await backup.exportBackup(app.native, app.repo);
                app.toast.show('备份已导出');
              }),
              GroupRow(
                label: '选择备份并恢复',
                onTap: _busy || !_ready ? null : _restore,
              ),
            ],
          ),
          const GroupFooter(
            '备份包含记录、照片和普通设置，不包含密钥。第一版单个备份最多100MB。卸载 APP 会删除手机记录，请定期导出。',
          ),
          const GroupHeader('拍照识别（大模型）'),
          GroupCard(
            children: [
              _field('接口地址', 'baseUrl', placeholder: 'https://你的服务地址/v1'),
              _field('模型名称', 'model', placeholder: '服务商支持图片输入的模型'),
              _field('API Key', 'modelKey', secret: true),
              GroupRow(
                label: '接口协议',
                value: _cfg!['protocol'] == 'responses'
                    ? 'Responses（含 xAI）'
                    : 'Chat Completions（兼容接口）',
                onTap: () async {
                  final picked = await showActionMenu(
                    context,
                    title: '接口协议',
                    actions: const [
                      MenuAction(id: 'chat', label: 'Chat Completions（兼容接口）'),
                      MenuAction(id: 'responses', label: 'Responses（含 xAI）'),
                    ],
                  );
                  if (picked != null && mounted) {
                    setState(() => _cfg!['protocol'] = picked.id);
                  }
                },
              ),
            ],
          ),
          const GroupFooter(
            '地址填写到 /v1，不包含 /chat/completions 或 /responses。识别由你手动发起，可能产生服务商费用。',
          ),
          const GroupHeader('提醒'),
          GroupCard(
            children: [
              _button('开启锁屏休息提醒', () async {
                await app.reminders.enableReminders();
                app.toast.show('已检查提醒权限');
              }),
            ],
          ),
          const GroupHeader('时区'),
          GroupCard(
            children: [_field('记录时区', 'tz', placeholder: 'Asia/Shanghai')],
          ),
          const GroupFooter('更改时区只影响今天和后续日期，不改变已经保存的记录日期。'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: FormButton(
              _busy ? '正在处理…' : '保存设置',
              onTap: _ready && !_busy ? _save : null,
              filled: true,
            ),
          ),
          const GroupFooter('薄肌日课 $appVersion · 本地版'),
        ],
      ),
    );
  }
}
