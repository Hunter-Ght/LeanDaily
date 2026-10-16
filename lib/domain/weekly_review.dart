import 'calendar.dart';
import 'format.dart' hide shiftDate;

/// Reviews only the last completed calendar week; absent records are unknown.
Map<String, dynamic>? weeklyReview({
  required String today,
  required Map<String, Map<String, dynamic>> days,
  required Map<String, dynamic> Function(String iso) meals,
  required List<Map<String, dynamic>> bodyEntries,
  required String? stage,
  required int kcalGoal,
  required int proteinGoal,
  required int trainTarget,
  required int kcalFloor,
  required String done,
}) {
  final monday = mondayOf(today);
  if (daysApart(monday, today) > 3) return null;
  final week = shiftDate(monday, -7);
  if (done == week) return null;
  final previous = shiftDate(week, -7);
  bool inWeek(String date, String start) =>
      date.compareTo(start) >= 0 && date.compareTo(shiftDate(start, 7)) < 0;
  final recorded = <String>{};
  var trainDays = 0, mealDays = 0, proteinDays = 0, kcalDays = 0;
  for (var i = 0; i < 7; i++) {
    final date = shiftDate(week, i);
    final sets = jsonRows(days[date]?['sets']);
    if (sets.isNotEmpty) recorded.add(date);
    if (sets.any((s) => s['type'] != '热身')) trainDays++;
    final meal = meals(date);
    if (jsonRows(meal['meals']).isEmpty) continue;
    recorded.add(date);
    mealDays++;
    final totals = jsonMap(meal['totals']);
    if (proteinGoal > 0 && jsNumber(totals['protein']) >= proteinGoal * .9) {
      proteinDays++;
    }
    final kcal = jsNumber(totals['kcal']);
    if (kcalGoal > 0 && kcal >= kcalGoal * .9 && kcal <= kcalGoal * 1.1) {
      kcalDays++;
    }
  }
  final weights = <double>[], oldWeights = <double>[];
  for (final entry in bodyEntries) {
    final date = '${entry['date']}';
    if (inWeek(date, week)) recorded.add(date);
    final weight = jsNumber(entry['weightKg']).toDouble();
    if (!weight.isFinite || weight <= 0) continue;
    if (inWeek(date, week)) weights.add(weight);
    if (inWeek(date, previous)) oldWeights.add(weight);
  }
  if (recorded.length < 3) return null;
  double mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
  final avg = weights.isEmpty ? null : mean(weights);
  final change = weights.length < 2 || oldWeights.length < 2
      ? null
      : avg! - mean(oldWeights);
  // Ignore binary floating point noise at the specified percentage boundaries.
  final pct = change == null
      ? null
      : double.parse((change / mean(oldWeights) * 100).toStringAsFixed(10));
  int? delta;
  String message;
  if (stage == null ||
      stage == 'youth' ||
      !const ['cut', 'trim', 'bulk', 'recomp', 'refine'].contains(stage)) {
    message = '保持训练的节奏，吃够睡够，给恢复留出时间';
  } else if ((stage == 'cut' || stage == 'trim') && mealDays < 4) {
    message = '这周饮食记录不多，先把记录补全，下周的建议会更准';
  } else if (pct == null) {
    message = '记体重能让回顾更准';
  } else if (stage == 'cut' || stage == 'trim') {
    if (pct <= -1) {
      delta = 100;
      message = '下降偏快，每日多吃 100 千卡更利于保住肌肉';
    } else if (pct < -.25) {
      message = '节奏很好，继续保持';
    } else if (kcalDays >= 4) {
      delta = -100;
      message = '体重这周基本没动，每日少 100 千卡试试';
    } else {
      message = '先保持当前节奏，继续记录饮食和体重';
    }
  } else if (stage == 'bulk') {
    if (pct < .1) {
      delta = 150;
      message = '体重没怎么涨，每日多吃 150 千卡';
    } else if (pct > .5) {
      delta = -100;
      message = '涨得偏快，每日少 100 千卡，多长肌肉少长脂肪';
    } else {
      message = '增重节奏刚好';
    }
  } else if (pct.abs() <= .5) {
    message = '体重稳定，重点放在力量进步';
  } else if (pct < -.8) {
    delta = 100;
    message = '体重下降偏快，每日多吃 100 千卡，给力量进步留出余地';
  } else if (pct > .5) {
    delta = -100;
    message = '体重上升偏快，每日少 100 千卡，继续关注力量进步';
  } else {
    message = '先保持当前节奏，继续关注力量进步';
  }
  if (delta != null && delta < 0 && kcalGoal + delta < kcalFloor) {
    delta = null;
    message = '已经在安全下限，不建议再降';
  }
  final extra = trainDays < trainTarget
      ? '这周练了 $trainDays/$trainTarget 天，下周先把时间固定下来'
      : proteinDays < 4
      ? '蛋白达标 $proteinDays 天，用“常吃”一键添加更方便'
      : null;
  String labelDate(String date) {
    final d = DateTime.parse(date);
    return '${d.month}月${d.day}日';
  }

  return {
    'week': week,
    'label': '${labelDate(week)}–${labelDate(shiftDate(week, 6))}',
    'trainDays': trainDays,
    'trainTarget': trainTarget,
    'proteinDays': proteinDays,
    'kcalDays': kcalDays,
    'mealDays': mealDays,
    'weightAvg': avg,
    'weightChange': change,
    'weightPct': pct,
    'message': '$message。${extra == null ? '' : '$extra。'}',
    'action': delta == null
        ? null
        : {
            'kind': 'kcal',
            'delta': delta,
            'label': '每日${delta > 0 ? '多' : '少'} ${delta.abs()} 千卡',
          },
  };
}
