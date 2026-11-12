/// 备份提醒的规则。纯函数：不读时钟、不碰存储，调用方把事实传进来。
///
/// 记录只在本机，换手机会全部丢失。已经有不少记录、又很久没备份时，
/// 在「我的」页顶部放一张安静的卡片；点“以后再说”后 14 天不再出现。
library;

/// 累计训练日达到这个数，就值得备份了。
const backupMinTrainingDays = 10;

/// 或者最早的记录距今达到这个天数。
const backupMinSpanDays = 14;

/// 距上次备份超过这个天数，再提醒一次。
const backupStaleDays = 30;

/// 点“以后再说”后静默的天数。
const backupSnoozeDays = 14;

const _dayMs = 24 * 60 * 60 * 1000;

/// 记录的概况：有几个训练日、最早的记录距今多少天。
class BackupFacts {
  const BackupFacts({required this.trainingDays, required this.spanDays});
  final int trainingDays;
  final int spanDays;

  /// 记录多到“丢了会心疼”的程度。
  bool get worthBackingUp =>
      trainingDays >= backupMinTrainingDays || spanDays >= backupMinSpanDays;
}

/// 从两组记录日期（`yyyy-MM-dd`）算概况。[trainDates] 可含重复；已删除的记录由调用方先滤掉。
/// [spanDays] 取训练和饮食里最早的一天到 [today] 的天数。
BackupFacts backupFacts({
  required Iterable<String> trainDates,
  required Iterable<String> mealDates,
  required String today,
}) {
  final days = trainDates.toSet();
  String? first;
  for (final d in [...days, ...mealDates]) {
    if (first == null || d.compareTo(first) < 0) first = d;
  }
  final span = first == null ? 0 : _daysBetween(first, today);
  return BackupFacts(trainingDays: days.length, spanDays: span < 0 ? 0 : span);
}

int _daysBetween(String a, String b) =>
    DateTime.parse('${b}T00:00:00Z')
        .difference(DateTime.parse('${a}T00:00:00Z'))
        .inDays;

/// 距上次备份过去了几个整天；从没备份过是 null。时钟被往回拨时按 0 算。
int? daysSinceBackup({required int? lastBackupMs, required int nowMs}) {
  if (lastBackupMs == null) return null;
  final d = (nowMs - lastBackupMs) ~/ _dayMs;
  return d < 0 ? 0 : d;
}

/// 是否该显示备份提示卡。
///
/// - 没什么记录：不提示。
/// - 点过“以后再说”且还没到期：不提示。
/// - 已经打开了系统备份（随设备备份）：不提示，记录有别的保障。
/// - 从没手动备份过，或超过 [backupStaleDays] 天没备份：提示。
bool shouldNudgeBackup({
  required BackupFacts facts,
  required int? lastBackupMs,
  required int? snoozeUntilMs,
  required int nowMs,
  bool systemBackupOn = false,
}) {
  if (systemBackupOn || !facts.worthBackingUp) return false;
  if (snoozeUntilMs != null && nowMs < snoozeUntilMs) return false;
  final days = daysSinceBackup(lastBackupMs: lastBackupMs, nowMs: nowMs);
  return days == null || days > backupStaleDays;
}

/// “以后再说”之后，下次最早提示的时间。
int backupSnoozeUntil(int nowMs) => nowMs + backupSnoozeDays * _dayMs;

/// 「我的」页备份行右侧的状态文案（简体中文原文，由调用方翻译）。
/// 不用警告语气：没备份过也只是平静地说明。
String backupStatusText({required int? lastBackupMs, required int nowMs}) {
  final days = daysSinceBackup(lastBackupMs: lastBackupMs, nowMs: nowMs);
  if (days == null) return '还没备份过';
  if (days == 0) return '今天已备份';
  if (days == 1) return '昨天备份';
  if (days < 60) return '$days 天前备份';
  return '${days ~/ 30} 个月前备份';
}
