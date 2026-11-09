import 'format.dart';

/// 本周某一天的达成情况：训练、蛋白达标、热量在目标 ±10% 内。
class DayHit {
  const DayHit({
    required this.iso,
    required this.train,
    required this.protein,
    required this.kcal,
  });
  final String iso;
  final bool train, protein, kcal;
}

/// [weekDays] 是 buildStats 的 week['days']（周一到周日）；[meals] 是按日期的饮食记录。
List<DayHit> weekHits({
  required List<Map<String, dynamic>> weekDays,
  required Map<String, dynamic> meals,
  required num proteinGoal,
  required num kcalGoal,
}) => [
  for (final d in weekDays)
    DayHit(
      iso: '${d['iso']}',
      train: d['train'] == true,
      protein:
          jsNumber(jsonMap(jsonMap(meals[d['iso']])['totals'])['protein']) >=
          proteinGoal,
      kcal:
          jsNumber(d['kcal']) >= kcalGoal * .9 &&
          jsNumber(d['kcal']) <= kcalGoal * 1.1,
    ),
];
