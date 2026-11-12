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
      final message = AppController.message(e);
      // 自己在系统选择器里点了取消，不是出错。
      final cancelled = message == '已取消导出' || message == '已取消导入';
      if (mounted && !cancelled) setState(() => _error = message);
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
    await app.restoreFromBackup(b);
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
              GroupRow(
                label: '导出备份',
                sub: app.backupStatusLabel,
                onTap: _busy ? null : () => _run(app.exportBackup),
              ),
              GroupRow(label: '从备份恢复', onTap: _busy ? null : _restore),
            ],
          ),
          const GroupFooter(
            '包含记录、照片和设置，不含密钥。单个备份最多 100MB。卸载 APP 会删除手机记录，请定期导出。',
          ),
          const GroupFooter(
            '导出时可以选择保存位置，比如「文件」、云盘或下载目录。换手机时带上这个文件，在新手机的欢迎页或这里选「从备份恢复」。',
          ),
          if (app.systemBackup.supported) ...[
            const GroupHeader('随 iPhone 备份'),
            GroupCard(
              children: [
                GroupRow(
                  label: '随 iPhone 备份',
                  trailing: FormSwitch(
                    label: '随 iPhone 备份',
                    value: app.systemBackup.enabled,
                    onChanged: (v) => _run(() => app.setSystemBackup(v)),
                  ),
                ),
              ],
            ),
            const GroupFooter(
              '默认关闭，记录只留在这部手机上。打开后，记录和照片会进入 iCloud 或电脑上的 iPhone 备份，换 iPhone 恢复时自动回来。API Key 不会进入备份，换机后需要重新填写。',
            ),
            const GroupFooter('照片也会一起备份，会占用 iCloud 空间。关闭后，之后的备份不再包含这些记录。'),
          ],
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
