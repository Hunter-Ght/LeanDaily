/// Calendar-day windows; missing days are omitted rather than treated as zero.
/// Profile is the starting measurement. Callers must retain it to preserve a
/// historical baseline when updating their current profile weight.
Map<String, dynamic> bodyTrend(
  List<Map<String, dynamic>> entries,
  Map<String, dynamic>? profile,
  Map<String, dynamic>? targets,
  String today,
) {
  final end = DateTime.parse(today);
  final valid = entries.where((e) {
    final date = DateTime.tryParse('${e['date']}');
    final weight = e['weightKg'];
    return date != null &&
        !date.isAfter(end) &&
        weight is num &&
        weight.isFinite &&
        weight > 0;
  }).toList()..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
  double? mean(DateTime at, int offset) {
    final hi = at.subtract(Duration(days: offset));
    final lo = hi.subtract(const Duration(days: 6));
    final window = valid.where((e) {
      final d = DateTime.parse(e['date'] as String);
      return !d.isBefore(lo) && !d.isAfter(hi);
    }).toList();
    return window.isEmpty
        ? null
        : window.fold<double>(0, (sum, e) => sum + (e['weightKg'] as num)) /
              window.length;
  }

  final series = <Map<String, dynamic>>[];
  if (valid.isNotEmpty) {
    final first = DateTime.parse(valid.first['date'] as String);
    final start = end.subtract(const Duration(days: 83));
    for (
      var day = first.isBefore(start) ? start : first;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      final value = mean(day, 0);
      if (value != null) {
        series.add({
          'date': day.toIso8601String().substring(0, 10),
          'weightKg': value,
        });
      }
    }
  }
  final current = mean(end, 0), previous = mean(end, 7);
  final change = current == null || previous == null
      ? null
      : current - previous;
  final fat = (targets?['bodyFat'] as Map?)?['value'] ?? profile?['bodyFatPct'];
  final startWeight = profile?['weightKg'];
  final goal = targets?['goalBodyFat'];
  final stage = targets?['stage'];
  final estimate = current != null && startWeight is num && fat is num
      ? (100 * (1 - startWeight * (1 - fat / 100) / current))
            .clamp(0, 100)
            .toDouble()
      : null;
  final progress =
      ['cut', 'recomp', 'trim', 'refine'].contains(stage) &&
          estimate != null &&
          fat is num &&
          goal is num &&
          fat > goal
      ? ((fat - estimate) / (fat - goal)).clamp(0, 1).toDouble()
      : null;
  return {
    'series': series,
    'latestMean': current,
    'weekChange': change,
    'estimatedBodyFat': estimate,
    'progress': progress,
    'gainInRange': ['bulk', 'youth'].contains(stage) && change != null
        ? change >= .2 - 1e-9 && change <= .4 + 1e-9
        : null,
    'stage': stage,
    'count': valid.length,
  };
}
