import 'cardio.dart';
import 'format.dart';

/// 本周某一天的达成情况：训练、蛋白达标、热量在目标 ±10% 内。
class DayHit {
  const DayHit({
    required this.iso,
    required this.train,
    required this.protein,
    required this.kcal,
    this.cardio = false,
  });
  final String iso;

  /// [train] 只看力量训练；[cardio] 为真表示这天有有氧（活动日）。
  final bool train, protein, kcal, cardio;

  /// 这天的活动：力量 > 有氧 > 无。有氧日不算完成训练。
  DayActivity get activity => dayActivity(strength: train, cardio: cardio);
}

/// [weekDays] 是 buildStats 的 week['days']（周一到周日）；[meals] 是按日期的饮食记录。
List<DayHit> weekHits({
  required List<Map<String, dynamic>> weekDays,
  required Map<String, dynamic> meals,
  required num proteinGoal,
  required num kcalGoal,
  Set<String> cardioDates = const {},
}) => [
  for (final d in weekDays)
    DayHit(
      iso: '${d['iso']}',
      cardio: cardioDates.contains('${d['iso']}'),
      train: d['train'] == true,
      protein:
          jsNumber(jsonMap(jsonMap(meals[d['iso']])['totals'])['protein']) >=
          proteinGoal,
      kcal:
          jsNumber(d['kcal']) >= kcalGoal * .9 &&
          jsNumber(d['kcal']) <= kcalGoal * 1.1,
    ),
];
