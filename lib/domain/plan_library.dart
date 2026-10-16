import 'dart:convert';

import 'plan.dart' show normalizePlan;

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
  }
  return a == b;
}

/// Immutable JSON-backed library. Every accessor returns a detached JSON copy.
/// Operations return a new library; neither caller data nor previous versions
/// are mutated. IDs and milliseconds are supplied by the caller for determinism.
class PlanLibrary {
  PlanLibrary.empty()
    : _json = {'v': 1, 'activeId': null, 'items': <Object?>[]};

  factory PlanLibrary.fromJson(Map<String, dynamic> json) {
    final copy = _copy(json);
    if (copy['v'] != 1 || copy['items'] is! List) {
      throw const FormatException('Invalid plan library');
    }
    final ids = <String>{};
    for (final item in copy['items'] as List) {
      if (item is! Map ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          !ids.add(item['id'] as String) ||
          item['name'] is! String ||
          !sources.contains(item['source']) ||
          item['createdAt'] is! num ||
          item['updatedAt'] is! num ||
          item['plan'] is! Map) {
        throw const FormatException('Invalid plan library item');
      }
    }
    if (ids.isNotEmpty && !ids.contains(copy['activeId']) ||
        ids.isEmpty && copy['activeId'] != null) {
      throw const FormatException('Invalid active plan');
    }
    return PlanLibrary._(copy);
  }

  PlanLibrary._(this._json);
  final Map<String, dynamic> _json;
  static const sources = {'legacy', 'template', 'generated', 'custom'};

  Map<String, dynamic> toJson() => _copy(_json);
  bool get isEmpty => (_json['items'] as List).isEmpty;
  String? get activeId => _json['activeId'] as String?;
  List<Map<String, dynamic>> get items =>
      (toJson()['items'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get activePlan =>
      isEmpty ? null : _copy(_find(activeId!)['plan'] as Map<String, dynamic>);

  Map<String, dynamic> _find(String id) =>
      (_json['items'] as List).cast<Map<String, dynamic>>().firstWhere(
        (item) => item['id'] == id,
        orElse: () => throw ArgumentError.value(id, 'planId'),
      );

  PlanLibrary add({
    required String id,
    required String name,
    required Map<String, dynamic> plan,
    required int now,
    String source = 'custom',
    String? templateId,
    int? templateVersion,
  }) {
    if (id.isEmpty || items.any((item) => item['id'] == id)) {
      throw ArgumentError.value(id, 'id');
    }
    if (!sources.contains(source)) throw ArgumentError.value(source, 'source');
    final next = toJson();
    (next['items'] as List).add({
      'id': id,
      'name': name,
      'source': source,
      'templateId': ?templateId,
      'templateVersion': ?templateVersion,
      'createdAt': now,
      'updatedAt': now,
      'plan': _copy(plan),
    });
    if (isEmpty) next['activeId'] = id;
    return PlanLibrary._(next);
  }

  PlanLibrary rename(String planId, String name, int now) =>
      _change(planId, {'name': name, 'updatedAt': now});

  PlanLibrary duplicate(
    String planId, {
    required String id,
    required String name,
    required int now,
  }) {
    final original = _find(planId);
    final next = add(
      id: id,
      name: name,
      plan: original['plan'] as Map<String, dynamic>,
      now: now,
      source: 'custom',
    );
    return original['needsNormalize'] == true
        ? next._change(id, {'needsNormalize': true})
        : next;
  }

  PlanLibrary remove(String planId) {
    _find(planId);
    if (items.length == 1 || activeId == planId) {
      throw StateError('Cannot remove the last or active plan');
    }
    final next = toJson();
    (next['items'] as List).removeWhere((item) => item['id'] == planId);
    return PlanLibrary._(next);
  }

  PlanLibrary setActive(String planId) {
    _find(planId);
    return PlanLibrary._(toJson()..['activeId'] = planId);
  }

  PlanLibrary update(String planId, Map<String, dynamic> plan, int now) =>
      _change(planId, {
        'plan': _copy(plan),
        'updatedAt': now,
        'needsNormalize': !_equal(plan, normalizePlan(_copy(plan))),
      });

  PlanLibrary _change(String id, Map<String, dynamic> fields) {
    _find(id);
    final next = toJson();
    (next['items'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['id'] == id)
        .addAll(fields);
    return PlanLibrary._(next);
  }
}

/// Normalization is a diagnostic only: even non-fixed-point legacy plans are
/// retained verbatim. normalizePlan mutates nested JSON, so compare a copy.
PlanLibrary migrateFromLegacy(Object legacyPlanJson, int now) {
  final decoded = legacyPlanJson is String
      ? jsonDecode(legacyPlanJson)
      : legacyPlanJson;
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid legacy plan');
  }
  final library = PlanLibrary.empty().add(
    id: 'legacy',
    name: '我的原始方案',
    source: 'legacy',
    plan: decoded,
    now: now,
  );
  return library._change('legacy', {
    'needsNormalize': !_equal(decoded, normalizePlan(_copy(decoded))),
  });
}
