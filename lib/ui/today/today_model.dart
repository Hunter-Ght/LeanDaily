import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/deload.dart';
import '../../domain/plan.dart' as plan;
import '../../domain/progress.dart' as progress;
import '../../domain/muscles.dart';
import '../../domain/movements.dart';

/// 一次页面快照；所有目标和统计直接调用已移植的领域函数。
class TodayModel {
  TodayModel(this.app) : iso = app.today {
    state = jsonMap(app.dayStates[iso]);
    day = app.repo.day(iso);
    history = app.repo.allDays().map(
      (key, value) => MapEntry(key, jsonMap(value)),
    );
    slot = plan.workoutFor(app.plan, iso, state);
    workout = jsonMap(slot['workout']);
    final raw = train
        ? plan.exercisesFor(app.plan, workout, iso)
        : <Map<String, dynamic>>[];
    for (final e in raw) {
      before['${e['id']}'] = progress.targetFor(
        e,
        history,
        today: iso,
        dayStates: app.dayStates,
        progress: app.progress,
        options: app.progressOptions,
      );
      after['${e['id']}'] = progress.targetFor(
        e,
        history,
        today: iso,
        dayStates: app.dayStates,
        progress: app.progress,
        options: app.progressOptions,
        include: true,
      );
    }
    num setsOf(Map<String, dynamic> e) =>
        jsNumber(before['${e['id']}']?['sets'] ?? e['sets']);
    prog = train
        ? plan.dayProgress(app.plan, workout, iso, day, lite, setsOf)
        : {};
    all = train ? plan.exercisesFor(app.plan, workout, iso, false, setsOf) : [];
    next = plan.nextTraining(app.plan, iso, app.dayStates);
    missed = plan.missedWorkout(app.plan, iso, app.dayStates, history);
    final review = progress.weeklyReview(app.plan, history, app.dayStates, iso);
    final src = train
        ? raw
        : next != null
        ? plan.exercisesFor(
            app.plan,
            jsonMap(next!['workout']),
            '${next!['iso']}',
          )
        : <Map<String, dynamic>>[];
    final suggested = <Map<String, dynamic>>[];
    for (final e in src) {
      final s = progress.suggest(e, {
        'plan': app.plan,
        'days': history,
        'dayStates': app.dayStates,
        'progress': app.progress,
        'today': iso,
        'review': review,
      }, options: app.progressOptions);
      if (s != null) suggested.add(s);
    }
    final deload = deloadSuggestion(
      days: history,
      dayStates: app.dayStates,
      progress: app.progress,
      plan: app.plan,
      today: iso,
      stage: app.targets?['stage'] as String?,
      options: app.progressOptions,
    );
    if (deload != null) suggested.add(deload);
    const rank = {
      'pain': 0,
      'deload': 1,
      'ease': 2,
      'ladder': 2,
      'load': 2,
      'cap': 2,
      'jump': 3,
      'sets': 4,
    };
    // Keep Web's stable ordering within a suggestion priority.
    final sorted = suggested.indexed.toList()
      ..sort((a, b) {
        final d = (rank[a.$2['kind']] ?? 9).compareTo(rank[b.$2['kind']] ?? 9);
        return d != 0 ? d : a.$1.compareTo(b.$1);
      });
    var setSuggestions = 0;
    suggestions = sorted
        .map((e) => e.$2)
        .where((s) => s['kind'] != 'sets' || ++setSuggestions == 1)
        .take(3)
        .toList();
    if (train) {
      final previous = Map<String, Map<String, dynamic>>.from(history)
        ..remove(iso);
      final st = muscleStatus(previous, app.clock().millisecondsSinceEpoch);
      if (jsNumber(st['setCount']) > 0) {
        final ids = <String>{};
        for (final e in all) {
          if (jsTruthy(e['optional']) || lite && !jsTruthy(e['core'])) continue;
          final mv = musclesOf(e['name'], '${e['part']}');
          for (final entry in jsonMap(mv?['muscles']).entries) {
            if (jsNumber(entry.value) >= .8) ids.add(entry.key);
          }
        }
        recovery =
            ids.map((id) => jsonMap(jsonMap(st['byMuscle'])[id])).toList()
              ..sort(
                (a, b) =>
                    jsNumber(b['fatigue']).compareTo(jsNumber(a['fatigue'])),
              );
      }
    }
  }
  final AppController app;
  final String iso;
  late final Map<String, dynamic> state, day, slot, workout, prog;
  late final Map<String, Map<String, dynamic>> history;
  final before = <String, Map<String, dynamic>>{},
      after = <String, Map<String, dynamic>>{};
  late final List<Map<String, dynamic>> all, suggestions;
  List<Map<String, dynamic>> recovery = [];
  late final Map<String, dynamic>? next, missed;
  bool get train => slot['kind'] == 'train';
  bool get lite => jsTruthy(state['lite']);
  bool get complete => prog['complete'] == true;
  bool get started =>
      jsTruthy(state['started']) ||
      jsNumber(prog['doneSets']) > 0 ||
      items.any((i) => jsNumber(i['done']) > 0);
  List<Map<String, dynamic>> get items => jsonRows(prog['items']);
  String get firstOpen =>
      '${items.where((i) => !jsTruthy(i['complete']) && !jsTruthy(jsonMap(i['ex'])['optional'])).firstOrNull?['ex']['id'] ?? ''}';
  String get ready => '${state['ready'] ?? 'ok'}';
}
