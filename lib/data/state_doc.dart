import 'dart:convert';
import 'dart:math';

import '../domain/records.dart';

Map<String, dynamic> emptyState() => {
  'version': 1,
  'revision': 0,
  'sets': <String, dynamic>{},
  'meals': <String, dynamic>{},
  'notes': <String, dynamic>{},
  'tasks': <String, dynamic>{},
  'idem': <String, dynamic>{},
  'sync': {'lastSuccess': '', 'error': ''},
};
Map<String, dynamic> parseState(String? raw) {
  final decoded = raw == null ? null : jsonDecode(raw);
  final state = decoded == null
      ? emptyState()
      : Map<String, dynamic>.from(decoded as Map);
  if (state['version'] != 1) throw const DomainError('数据版本不兼容，请更新 APP');
  return state;
}

final _random = Random.secure();
String newId() {
  final b = List.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Map<String, dynamic> cloneJson(Map<String, dynamic> state) =>
    jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
void mark(Map<String, dynamic> state, String kind, String id) {
  final tasks = state['tasks'] as Map;
  final key = '$kind:$id';
  tasks[key] = {
    'kind': kind,
    'id': id,
    'version': ((tasks[key] as Map?)?['version'] as num? ?? 0) + 1,
    'nonce': newId(),
  };
}
