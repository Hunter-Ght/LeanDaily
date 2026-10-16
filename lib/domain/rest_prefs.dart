import 'dart:convert';

import 'format.dart';

Map<String, dynamic> normalizeRestPrefs(Object? prefs) {
  final p = jsonMap(prefs);
  return {'enabled': p['enabled'] != false, 'sec': p['sec'] == 120 ? 120 : 90};
}

/// Parses the exact fw-rest-v1 document, including the legacy bare seconds.
Map<String, dynamic> restPrefs(String? raw) {
  if (raw == '120' || raw == '90') {
    return {'enabled': true, 'sec': int.parse(raw!)};
  }
  try {
    final j = jsonDecode(raw ?? '');
    if (j is Map || j is List) return normalizeRestPrefs(j);
  } on FormatException {
    /* Defaults match Web private/empty storage. */
  }
  return {'enabled': true, 'sec': 90};
}

Map<String, dynamic> saveRestPrefs(Object? prefs) => normalizeRestPrefs(prefs);
