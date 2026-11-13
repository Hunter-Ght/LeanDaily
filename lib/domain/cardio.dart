import 'calendar.dart' show shiftDate;
import 'records.dart' show DomainError, jsString, number;

/// 有氧记录的类型（存 id，界面显示中文名再翻译）。
const cardioTypes = [
  'walk',
  'run',
  'bike',
  'elliptical',
  'rower',
  'stairs',
  'swim',
  'rope',
  'other',
];
const cardioTypeLabels = {
  'walk': '走路',
  'run': '跑步',
  'bike': '骑车',
  'elliptical': '椭圆机',
  'rower': '划船机',
  'stairs': '爬楼',
  'swim': '游泳',
  'rope': '跳绳',
  'other': '其他',
};

/// 吃力程度：轻松 / 适中 / 吃力。可不填。
const cardioEfforts = ['easy', 'moderate', 'hard'];
const cardioEffortLabels = {'easy': '轻松', 'moderate': '适中', 'hard': '吃力'};

const cardioDefaultMinutes = 20;
const cardioMaxMinutes = 600;
const cardioMaxKm = 1000;

/// 校验并整理一条有氧记录（存储用，距离永远是公里）。输入无效时抛 [DomainError]。
Map<String, dynamic> cleanCardio({
  required String date,
  required Object? type,
  required Object? minutes,
  Object? distanceKm,
  Object? effort,
}) {
  final day = DateTime.tryParse('${date}T12:00:00Z');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      day == null ||
      day.toIso8601String().substring(0, 10) != date) {
    throw const DomainError('日期无效');
  }
  if (!cardioTypes.contains(type)) throw const DomainError('有氧类型无效');
  final m = minutes == null ? double.nan : number(minutes);
  if (!m.isFinite ||
      m != m.truncateToDouble() ||
      m < 1 ||
      m > cardioMaxMinutes) {
    throw const DomainError('时长应为 1–600 分钟');
  }
  double? km;
  if (distanceKm != null && jsString(distanceKm).trim().isNotEmpty) {
    final d = number(distanceKm);
    if (!d.isFinite || d <= 0 || d > cardioMaxKm) {
      throw const DomainError('距离无效');
    }
    km = (d * 1000).round() / 1000;
  }
  if (effort != null && effort != '' && !cardioEfforts.contains(effort)) {
    throw const DomainError('吃力程度无效');
  }
  return {
    'date': date,
    'type': type,
    'minutes': m.toInt(),
    'distanceKm': ?km,
    if (effort != null && effort != '') 'effort': effort,
  };
}

/// 读取或导入时用：无效的整条丢掉，不让一条坏数据挡住其余记录。
Map<String, dynamic>? tryCleanCardio(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String || id.isEmpty) return null;
  try {
    final row = cleanCardio(
      date: jsString(raw['date']),
      type: raw['type'],
      minutes: raw['minutes'],
      distanceKm: raw['distanceKm'],
      effort: raw['effort'],
    );
    final ts = number(raw['ts']);
    return {'id': id, ...row, if (ts.isFinite && ts > 0) 'ts': ts.toInt()};
  } on DomainError {
    return null;
  }
}

/// 某天所有有氧的总分钟数；[entries] 里不在 [dates] 范围内的不算。
int cardioMinutes(
  Iterable<Map<String, dynamic>> entries, {
  required String from,
  required String until,
}) {
  var total = 0;
  for (final e in entries) {
    final date = '${e['date']}';
    if (date.compareTo(from) >= 0 && date.compareTo(until) < 0) {
      total += (number(e['minutes'])).toInt();
    }
  }
  return total;
}

// ------------------------------------------------------------------ 坚持规则
//
// 有氧是「活动」，不是「力量训练」：
//  - 计划训练天数（本周 x/y 天、每周出勤、连续几周）只数力量训练，有氧不会让你「完成」计划日；
//  - 连续天数和坚持格子把有氧日算作没断；
//  - 有氧不参与肌肉恢复和训练量统计，也不换算热量。

/// 一天的活动：什么都没有 / 只有有氧（活动日）/ 有力量训练。
enum DayActivity { none, cardio, strength }

DayActivity dayActivity({required bool strength, required bool cardio}) =>
    strength
    ? DayActivity.strength
    : cardio
    ? DayActivity.cardio
    : DayActivity.none;

/// 本周（周一到周日）每天的活动。
List<DayActivity> weekActivity({
  required List<String> weekDays,
  required Set<String> strengthDates,
  required Set<String> cardioDates,
}) => [
  for (final iso in weekDays)
    dayActivity(
      strength: strengthDates.contains(iso),
      cardio: cardioDates.contains(iso),
    ),
];

/// 「训练天数」：只数力量训练日，有氧日不算。
int trainingDays(Iterable<DayActivity> week) =>
    week.where((d) => d == DayActivity.strength).length;

/// 「只有有氧、没有力量」的活动日数。
int cardioOnlyDays(Iterable<DayActivity> week) =>
    week.where((d) => d == DayActivity.cardio).length;

/// 连续有活动（力量或有氧）的天数。今天还没记不算断：从昨天往回数。
int activeStreak({
  required String today,
  required Set<String> strengthDates,
  required Set<String> cardioDates,
}) {
  bool active(String iso) =>
      strengthDates.contains(iso) || cardioDates.contains(iso);
  var streak = 0, cursor = active(today) ? 0 : 1;
  while (active(shiftDate(today, -cursor))) {
    streak++;
    cursor++;
  }
  return streak;
}
