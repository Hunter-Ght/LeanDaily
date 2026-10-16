import 'dart:async';
import 'dart:convert';

import '../core/native.dart';
import '../domain/plan_library.dart';

const planLibraryKey = 'fw-plans-v1';
const legacyPlanKey = 'fw-plan-v1';
const legacySnapshotKey = 'fw-plan-legacy-v1';
const _progressKey = 'fw-progress-v1';
const _dayStatesKey = 'fw-plan-day-v1';

class _Lane {
  Future<void> pending = Future.value();
}

/// A rollback failure is surfaced explicitly; it must never look like success.
/// Native only offers single-document puts, so disk/process failure across
/// documents requires a future native transaction API for full atomicity.
class PlanStoreRollbackError implements Exception {
  PlanStoreRollbackError(this.cause, this.failures);
  final Object cause;
  final Map<String, Object> failures;
  @override
  String toString() =>
      'Plan store rollback failed: ${failures.keys.join(', ')}';
}

class PlanStore {
  PlanStore(this.native, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final Native native;
  final DateTime Function() clock;
  static final _lanes = Expando<_Lane>();
  PlanLibrary _library = PlanLibrary.empty();
  PlanLibrary get library => PlanLibrary.fromJson(_library.toJson());
  Map<String, dynamic>? get activePlan => _library.activePlan;

  Future<T> _serial<T>(Future<T> Function() work) {
    final lane = _lanes[native] ??= _Lane();
    final next = lane.pending.then((_) => work());
    lane.pending = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  int get _now => clock().millisecondsSinceEpoch;
  Object? _read(Map<String, String> docs, String key) {
    final raw = docs[key];
    return raw == null ? null : jsonDecode(raw);
  }

  /// today matches the existing controller load contract. Legacy startDate is
  /// deliberately never filled in here: migration preserves even blank dates.
  Future<PlanLibrary> load(String today) => _serial(() async {
    final docs = await native.all();
    final next = await _load(docs);
    _library = next;
    return library;
  });

  Future<PlanLibrary> _load(Map<String, String> docs) async {
    final saved = _read(docs, planLibraryKey);
    if (saved != null) {
      if (saved is! Map<String, dynamic>) {
        throw const FormatException('Invalid plan library');
      }
      final next = PlanLibrary.fromJson(saved);
      await _persist(next, docs);
      return next;
    }
    final old = _read(docs, legacyPlanKey);
    if (old == null) return PlanLibrary.empty();
    final next = migrateFromLegacy(old, _now);
    // Snapshot first, before touching any legacy keys. Once present it survives
    // even a later failed migration and is never replaced on a retry.
    if (_read(docs, legacySnapshotKey) == null) {
      final snapshot = jsonEncode({
        'savedAt': _now,
        'plan': old,
        'progress': _read(docs, _progressKey),
        'dayStates': _read(docs, _dayStatesKey),
      });
      await native.put(legacySnapshotKey, snapshot);
      docs[legacySnapshotKey] = snapshot;
    }
    await _persist(next, docs);
    return next;
  }

  Future<void> _persist(
    PlanLibrary next,
    Map<String, String> docs, {
    Map<String, String> extra = const {},
  }) async {
    final plan = next.activePlan;
    final changes = <String, String>{
      ...extra,
      if (plan != null)
        legacyPlanKey: _sameJson(_read(docs, legacyPlanKey), plan)
            ? docs[legacyPlanKey]!
            : jsonEncode(plan),
      planLibraryKey: jsonEncode(next.toJson()),
    }..removeWhere((key, value) => docs[key] == value);
    final attempted = <String>[];
    try {
      for (final entry in changes.entries) {
        attempted.add(entry.key);
        await native.put(entry.key, entry.value);
      }
    } catch (error, stack) {
      final failures = <String, Object>{};
      for (final key in attempted.reversed) {
        try {
          // No delete primitive: absent keys are restored to JSON null, the
          // same absent-value convention used by backup restoration.
          await native.put(key, docs[key] ?? 'null');
        } catch (rollbackError) {
          failures[key] = rollbackError;
        }
      }
      if (failures.isNotEmpty) throw PlanStoreRollbackError(error, failures);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<PlanLibrary> _change(PlanLibrary Function(PlanLibrary) change) =>
      _serial(() async {
        var docs = await native.all();
        final current = await _load(docs);
        // _load may have migrated and persisted the library.
        docs = await native.all();
        final next = change(current);
        await _persist(next, docs);
        _library = next;
        return library;
      });

  Future<PlanLibrary> add({
    required String id,
    required String name,
    required Map<String, dynamic> plan,
    String source = 'custom',
    String? templateId,
    int? templateVersion,
  }) {
    final detached = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
    return _change(
      (library) => library.add(
        id: id,
        name: name,
        plan: detached,
        now: _now,
        source: source,
        templateId: templateId,
        templateVersion: templateVersion,
      ),
    );
  }

  Future<PlanLibrary> rename(String planId, String name) =>
      _change((library) => library.rename(planId, name, _now));
  Future<PlanLibrary> duplicate(
    String planId, {
    required String id,
    required String name,
  }) => _change(
    (library) => library.duplicate(planId, id: id, name: name, now: _now),
  );
  Future<PlanLibrary> remove(String planId) =>
      _change((library) => library.remove(planId));
  Future<PlanLibrary> setActive(String planId) =>
      _change((library) => library.setActive(planId));
  Future<PlanLibrary> update(String planId, Map<String, dynamic> plan) {
    final detached = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
    return _change((library) => library.update(planId, detached, _now));
  }

  Future<PlanLibrary> restoreLegacySnapshot() => _serial(() async {
    final docs = await native.all();
    final snapshot = _read(docs, legacySnapshotKey);
    if (snapshot is! Map ||
        snapshot['plan'] is! Map<String, dynamic> ||
        !snapshot.containsKey('progress') ||
        !snapshot.containsKey('dayStates')) {
      throw const FormatException('Missing or invalid legacy snapshot');
    }
    final saved = _read(docs, planLibraryKey);
    final current = saved == null
        ? PlanLibrary.empty()
        : PlanLibrary.fromJson(saved as Map<String, dynamic>);
    final original = migrateFromLegacy(snapshot['plan'] as Object, _now);
    PlanLibrary next;
    if (current.items.any((item) => item['id'] == 'legacy')) {
      next = current
          .update('legacy', original.activePlan!, _now)
          .setActive('legacy');
    } else {
      next = PlanLibrary.fromJson({
        ...current.toJson(),
        'activeId': 'legacy',
        'items': [...current.items, ...original.items],
      });
    }
    await _persist(
      next,
      docs,
      extra: {
        _progressKey: jsonEncode(snapshot['progress']),
        _dayStatesKey: jsonEncode(snapshot['dayStates']),
      },
    );
    _library = next;
    return library;
  });
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _sameJson(a[i], b[i]));
  }
  return a == b;
}
