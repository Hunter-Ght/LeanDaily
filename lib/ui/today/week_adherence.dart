import '../../domain/calendar.dart';
import '../../domain/format.dart' hide shiftDate;
import '../../domain/goals.dart';

/// Formal training days count once; future entries and warmups do not count.
({int count, num target, int streak}) weekAdherence({
  required String today,
  required Map<String, dynamic> history,
  required num savedDays,
  required num planDays,
}) {
  final target = weekTargetFromHistory(savedDays, planDays, history);
  int trained(String week) => history.entries
      .where(
        (e) =>
            e.key.compareTo(week) >= 0 &&
            e.key.compareTo(shiftDate(week, 7)) < 0 &&
            e.key.compareTo(today) <= 0 &&
            jsonRows(jsonMap(e.value)['sets']).any((s) => s['type'] != '热身'),
      )
      .length;
  final start = mondayOf(today), count = trained(mondayOf(today));
  var week = count >= target ? start : shiftDate(start, -7), streak = 0;
  final earliest = history.keys.toList()..sort();
  while (earliest.isNotEmpty &&
      week.compareTo(mondayOf(earliest.first)) >= 0 &&
      trained(week) >= target) {
    streak++;
    week = shiftDate(week, -7);
  }
  return (count: count, target: target, streak: streak);
}
