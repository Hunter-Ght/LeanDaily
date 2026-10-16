import 'movements.dart' show MUSCLES, musclesOf;
import 'plan.dart' show estimateMinutes;

/// Weekly prescription. Monday first; Sunday is zero, as in plan.schedule.
Map<String, dynamic> planInsight(
  Map<String, dynamic> plan, {
  String venue = 'home',
}) {
  final schedule = plan['schedule'] as Map? ?? {};
  final workouts = plan['workouts'] as Map? ?? {};
  final week = <Map<String, dynamic>>[];
  final volume = <String, double>{for (final m in MUSCLES) m['id']!: 0};
  final durations = <int>[];
  for (final dow in [1, 2, 3, 4, 5, 6, 0]) {
    final workout = workouts[schedule['$dow'] ?? schedule[dow]];
    if (workout is! Map) continue;
    final name = '${workout['name'] ?? ''}';
    final short = '${workout['short'] ?? ''}';
    week.add({'dow': dow, 'label': short.isNotEmpty ? short : _label(name)});
    final variant = venue == 'gym' && workout['gym'] is Map
        ? workout['gym'] as Map
        : workout;
    final exercises = (variant['exercises'] as List? ?? []).whereType<Map>();
    for (final ex in exercises) {
      final muscles =
          musclesOf(ex['name'], ex['part'] as String?)?['muscles'] as Map? ??
          {};
      final sets = ex['sets'] is num ? (ex['sets'] as num).toDouble() : 0.0;
      for (final e in muscles.entries) {
        volume['${e.key}'] =
            (volume['${e.key}'] ?? 0) + sets * (e.value as num);
      }
    }
    durations.add(
      estimateMinutes(plan, [
        for (final ex in exercises)
          {...Map<String, dynamic>.from(ex), 'target': ex['sets'] ?? 0},
      ], (variant['warmup'] as Map?)?['minutes'] as num?),
    );
  }
  final max = volume.values.fold<double>(0, (a, b) => a > b ? a : b);
  return {
    'week': week,
    'muscleLevels': <String, int>{
      for (final e in volume.entries)
        e.key: e.value <= 0
            ? 0
            : e.value < max * .25
            ? 1
            : e.value < max * .6
            ? 2
            : 3,
    },
    'muscleVolume': volume,
    'minutes': durations.isEmpty
        ? 0
        : (durations.reduce((a, b) => a + b) / durations.length).round(),
  };
}

String _label(String name) {
  for (final word in ['全身', '推', '拉', '腿', '上', '下']) {
    if (name.contains(word)) return word == '全身' ? '全' : word;
  }
  return name.isEmpty ? '练' : String.fromCharCode(name.runes.first);
}
