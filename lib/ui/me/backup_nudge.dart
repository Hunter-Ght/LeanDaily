import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';

/// 「我的」页顶部一张安静的提示：记录只在本机，换手机前先备份。
/// 只在这个页面出现，训练页和今日页不会被打断。
class BackupNudgeCard extends StatefulWidget {
  const BackupNudgeCard({super.key});
  @override
  State<BackupNudgeCard> createState() => _BackupNudgeCardState();
}

class _BackupNudgeCardState extends State<BackupNudgeCard> {
  bool _busy = false;

  Future<void> _backup() async {
    if (_busy) return;
    final app = context.app;
    setState(() => _busy = true);
    try {
      await app.exportBackup();
    } on Object catch (e) {
      final message = AppController.message(e);
      // 自己点了取消，不用再说一遍。
      if (message != '已取消导出') app.toast.show(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final everBacked = app.backupStatus.lastExportMs != null;
    final text = everBacked ? '已经一个多月没备份了，导出一份最新的吧。' : '记录只存在这部手机上，换机前先备份一份。';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LText(
              text,
              style: TextStyle(fontSize: 15, height: 1.45, color: p.text),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Pill('现在备份', _busy ? null : _backup),
              const SizedBox(width: 4),
              _TextAction('以后再说', _busy ? null : app.snoozeBackupNudge),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            // 备份不是训练动作：中性灰底，不用发力橙，也不用红色。
            decoration: BoxDecoration(
              color: p.fill2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: LText(
              label,
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
}

class _TextAction extends StatelessWidget {
  const _TextAction(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: LText(
            label,
            style: TextStyle(fontSize: 15, color: p.secondary),
          ),
        ),
      ),
    );
  }
}
