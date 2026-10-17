import 'dart:convert';

import '../core/native.dart';
import '../domain/records.dart';
import 'ai_consent.dart';

const defaults = <String, dynamic>{
  'tz': 'Asia/Shanghai',
  'model': '',
  'baseUrl': '',
  'protocol': 'chat',
  'haptics': true,
  'autoUpdateCheck': true,
};

class Settings {
  Settings(this.native, {this.deviceTz = 'Asia/Shanghai'});
  final Native native;
  final String deviceTz;
  Map<String, dynamic> _value = Map.of(defaults);
  Map<String, dynamic> get value => Map.unmodifiable(_value);
  Future<Map<String, dynamic>> load() async {
    final raw = (await native.all())['android-settings'];
    final decoded = raw == null ? null : jsonDecode(raw);
    _value = {
      ...defaults,
      'tz': deviceTz,
      for (final k in defaults.keys)
        if (decoded is Map && decoded.containsKey(k)) k: decoded[k],
    };
    return value;
  }

  Future<void> save(Map<String, dynamic> s, [Secrets? secrets]) async {
    await native.clock('${s['tz'] ?? deviceTz}');
    if (truthy(s['baseUrl'])) {
      if (!'${s['baseUrl']}'.startsWith('https://')) {
        throw const DomainError('模型接口必须使用 HTTPS');
      }
      AiConsent.destination(s);
    }
    final safe = {
      for (final k in defaults.keys)
        k: s[k] ?? (k == 'tz' ? deviceTz : defaults[k]),
    };
    if (secrets != null) await native.secretsSet(secrets);
    await native.put('android-settings', jsonEncode(safe));
    _value = safe;
  }

  Future<Secrets> secrets() => native.secretsGet();
}

Future<Secrets> secrets(Native native) => native.secretsGet();
Object? _decode(String? raw) {
  try {
    return jsonDecode(raw ?? '');
  } catch (_) {
    return null;
  }
}

const goalDefaults = <String, int>{
  'sets': 12,
  'meals': 3,
  'kcal': 1800,
  'weekDays': 0,
};
Map<String, int> _clampGoals(Map g) {
  int clamp(String key, int min, int max) {
    // JS Number(undefined) is NaN, while explicit null becomes zero.
    final n = g.containsKey(key) ? number(g[key]) : double.nan;
    return n.isFinite ? (n + .5).floor().clamp(min, max) : goalDefaults[key]!;
  }

  return {
    'sets': clamp('sets', 1, 40),
    'meals': clamp('meals', 1, 8),
    'kcal': clamp('kcal', 200, 8000),
    'weekDays': clamp('weekDays', 0, 7),
  };
}

class GoalsStore {
  GoalsStore(this.native);
  final Native native;
  Future<Map<String, int>> load() async {
    final v = _decode((await native.all())['fw-goals-v1']);
    return _clampGoals(v is Map ? v : {});
  }

  Future<Map<String, int>> save(Map goals) async {
    final next = _clampGoals(goals);
    await native.put('fw-goals-v1', jsonEncode(next));
    return next;
  }
}

class RestPrefsStore {
  RestPrefsStore(this.native);
  final Native native;
  Map<String, dynamic> _normalize(Map p) => {
    'enabled': p['enabled'] != false,
    'sec': p['sec'] == 120 ? 120 : 90,
  };
  Future<Map<String, dynamic>> load() async {
    final raw = (await native.all())['fw-rest-v1'];
    if (raw == '90' || raw == '120') {
      return {'enabled': true, 'sec': int.parse(raw!)};
    }
    final p = _decode(raw);
    return _normalize(p is Map ? p : {});
  }

  Future<Map<String, dynamic>> save(Map prefs) async {
    final next = _normalize(prefs);
    await native.put('fw-rest-v1', jsonEncode(next));
    return next;
  }
}

class DayStatesStore {
  DayStatesStore(this.native);
  final Native native;
  Future<Map<String, dynamic>> load() async {
    final v = _decode((await native.all())['fw-plan-day-v1']);
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  Future<Map<String, dynamic>> save(
    Map<String, dynamic> states,
    String today,
  ) async {
    final min = DateTime.parse('${today}T12:00:00')
        .subtract(const Duration(days: 45))
        .toIso8601String()
        .substring(0, 10);
    final next = {
      for (final e in states.entries)
        if (e.key.compareTo(min) >= 0) e.key: e.value,
    };
    await native.put('fw-plan-day-v1', jsonEncode(next));
    return next;
  }
}

class RestTimerStore {
  RestTimerStore(this.native);
  final Native native;
  Future<Map<String, dynamic>> load() async {
    final v = _decode((await native.all())['android-rest']);
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  Future<void> save({required num until, required num total}) =>
      native.put('android-rest', jsonEncode({'until': until, 'total': total}));
}
