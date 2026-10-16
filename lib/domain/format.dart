import 'dart:convert';

/// JavaScript coercions retained at the persisted JSON boundary.
num jsNumber(Object? v) {
  if (v == null) return 0;
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  final s = jsString(v);
  if (s.trim().isEmpty) return 0;
  return num.tryParse(s.trim()) ?? double.nan;
}

bool jsTruthy(Object? v) =>
    v != null && v != false && v != '' && !(v is num && (v == 0 || v.isNaN));
Map<String, dynamic> jsonMap(Object? v) => v is Map
    ? Map<String, dynamic>.from(v)
    : v is List
    ? {for (final (i, value) in v.indexed) '$i': value}
    : <String, dynamic>{};
List<Map<String, dynamic>> jsonRows(Object? v) =>
    v is List ? v.map(jsonMap).toList() : [];
Map<String, dynamic> cloneJson(Map<String, dynamic> v) =>
    jsonMap(jsonDecode(jsonEncode(v)));
String jsString(Object? v) {
  if (v == null) return 'null';
  if (v is List) return v.map((e) => e == null ? '' : jsString(e)).join(',');
  if (v is Map) return '[object Object]';
  if (v is num && v.isFinite && v == v.roundToDouble()) {
    return v.toInt().toString();
  }
  return v.toString();
}

String fmt(Object? n) {
  if (n == null || n == '') return '-';
  final x = jsNumber(n);
  if (!x.isFinite) return '-';
  return x == x.roundToDouble() ? x.toInt().toString() : x.toStringAsFixed(1);
}

DateTime isoDate(String iso, {bool utc = true}) {
  final p = iso.split('-').map(int.parse).toList();
  // JS Date's numeric constructor treats years 0..99 as 1900..1999.
  final y = p[0] >= 0 && p[0] < 100 ? p[0] + 1900 : p[0];
  return utc ? DateTime.utc(y, p[1], p[2]) : DateTime(y, p[1], p[2]);
}

String shiftDate(String iso, int days) {
  final d = isoDate(iso).add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String weekday(String iso) =>
    const ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][isoDate(iso).weekday % 7];
String dateLabel(String iso) {
  final p = iso.split('-');
  return '${jsNumber(p[1])}月${jsNumber(p[2])}日 ${weekday(iso)}';
}

List<List<dynamic>> groupSets(List<dynamic>? sets) {
  final groups = <Object?, List<Map<String, dynamic>>>{};
  for (final s in jsonRows(sets)) {
    groups.putIfAbsent(s['ex'], () => []).add(s);
  }
  for (final list in groups.values) {
    final indexed = list.indexed.toList()
      ..sort((a, b) {
        final n =
            (a.$2.containsKey('no') ? jsNumber(a.$2['no']) : double.nan) -
            (b.$2.containsKey('no') ? jsNumber(b.$2['no']) : double.nan);
        return n.isNaN || n == 0 ? a.$1.compareTo(b.$1) : n.sign.toInt();
      });
    list.setAll(0, indexed.map((e) => e.$2));
  }
  return groups.entries.map((e) => <dynamic>[e.key, e.value]).toList();
}

num workVolume(List<dynamic> list) =>
    jsonRows(list)
        .where((s) => s['type'] != '热身')
        .fold<num>(0, (n, s) => n + jsNumber(s['w']) * jsNumber(s['reps']));
String userNote(Map<String, dynamic>? day) {
  final n = jsonMap(day?['day_row'])['体感备注'];
  if (!jsTruthy(n)) return '';
  final s = n.toString();
  return s.contains('e1RM') || s.startsWith('；') ? '' : s;
}

String effortWord(Object? v) {
  final n = jsNumber(v);
  if (!jsTruthy(n)) return '不记';
  if (n <= 3) return '轻松';
  if (n <= 6) return '适中';
  if (n <= 8) return '吃力';
  return '力竭';
}
