import 'dart:convert';

import '../core/native.dart';

/// 「上次导出备份的时间」和「以后再说」的到期时间。
/// 只属于这部手机，不进备份文件：换手机恢复后，这里从“刚恢复”重新开始算。
class BackupStatus {
  const BackupStatus({this.lastExportMs, this.snoozeUntilMs});
  final int? lastExportMs, snoozeUntilMs;
  BackupStatus copyWith({int? lastExportMs, int? snoozeUntilMs}) =>
      BackupStatus(
        lastExportMs: lastExportMs ?? this.lastExportMs,
        snoozeUntilMs: snoozeUntilMs ?? this.snoozeUntilMs,
      );
}

class BackupStatusStore {
  BackupStatusStore(this.native);
  final Native native;
  static const key = 'leandaily-backup-v1';

  Future<BackupStatus> load() async {
    try {
      final raw = (await native.all())[key];
      final j = raw == null ? null : jsonDecode(raw);
      if (j is Map && j['v'] == 1) {
        int? ms(String k) =>
            j[k] is num && (j[k] as num) > 0 ? (j[k] as num).toInt() : null;
        return BackupStatus(
          lastExportMs: ms('lastExportMs'),
          snoozeUntilMs: ms('snoozeUntilMs'),
        );
      }
    } on Object {
      // 损坏的状态当作没有备份过：只会多提醒一次，不影响记录。
    }
    return const BackupStatus();
  }

  Future<void> save(BackupStatus s) => native.put(
    key,
    jsonEncode({
      'v': 1,
      if (s.lastExportMs != null) 'lastExportMs': s.lastExportMs,
      if (s.snoozeUntilMs != null) 'snoozeUntilMs': s.snoozeUntilMs,
    }),
  );
}
