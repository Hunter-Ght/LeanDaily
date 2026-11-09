import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../config/app_info.dart';
import '../../data/backup.dart' as backup;
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/sheet.dart';
import '../kit/menu.dart';

/// 我的 → 备份与高级：备份与恢复、触感与提醒、时区。
/// AI 拍照识别已拆到 [AiSettingsSheet]（ai_settings_sheet.dart）。
class AndroidSettingsSheet extends StatefulWidget {
  const AndroidSettingsSheet({super.key});
  @override
  State<AndroidSettingsSheet> createState() => _AndroidSettingsSheetState();
}

class _AndroidSettingsSheetState extends State<AndroidSettingsSheet> {
  Map<String, dynamic>? _cfg;
  String _error = '';
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cfg ??= Map.of(context.app.settings.value);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
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
      SheetController.of(context).close();
    }
  });

  Widget _button(String s, Future<void> Function() action) =>
      GroupRow(label: s, onTap: _busy ? null : () => _run(action));
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return AppSheet(
      title: '备份与高级',
      cancelLabel: '关闭',
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
          const GroupHeader('备份与恢复'),
          GroupCard(
            children: [
              _button('导出备份', () async {
                await backup.exportBackup(app.native, app.repo);
                app.toast.show('备份已导出');
              }),
              GroupRow(label: '从备份恢复', onTap: _busy ? null : _restore),
            ],
          ),
          const GroupFooter(
            '包含记录、照片和设置，不含密钥。单个备份最多 100MB。卸载 APP 会删除手机记录，请定期导出。',
          ),
          const GroupHeader('触感与提醒'),
          GroupCard(
            children: [
              GroupRow(
                label: '触感反馈',
                sub: '选择时轻触，完成训练时双震',
                trailing: FormSwitch(
                  label: '触感反馈',
                  haptic: false,
                  value: _cfg!['haptics'] != false,
                  onChanged: (v) async {
                    setState(() => _cfg!['haptics'] = v);
                    // 开关立即生效，不必再点保存。
                    await app.setHaptics(v);
                    if (v) app.haptics.selection();
                  },
                ),
              ),
              _button('锁屏休息提醒', () async {
                await app.reminders.enableReminders();
                app.toast.show('已检查提醒权限');
              }),
            ],
          ),
          const GroupHeader('时区'),
          GroupCard(
            children: [
              GroupRow(
                label: '记录时区',
                value: '跟随系统',
                sub: '${_cfg!['tz']}',
                chevron: false,
              ),
            ],
          ),
          const GroupFooter('按手机系统时区计算“今天”。出差或换时区后会自动跟随，已经保存的记录日期不变。'),
          const GroupFooter('薄肌日课 $appVersion · 本地版'),
        ],
      ),
    );
  }
}
