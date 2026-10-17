import '../../app/app_controller.dart';
import '../../data/state_doc.dart' show mark;
import '../../domain/format.dart';
import '../../domain/movements.dart' show musclesOf;
import '../today/today_model.dart';

/// Uses the same row schema and defaults as the former inline recorder.
num trainingReps(
  Map<String, dynamic> e,
  Map<String, dynamic> target,
  List<Map<String, dynamic>> sets,
) => jsNumber(sets.lastOrNull?['reps'] ?? target['reps'] ?? e['min']);
num trainingWeight(
  Map<String, dynamic> e,
  Map<String, dynamic> target,
  List<Map<String, dynamic>> sets,
) => jsNumber(
  sets.lastOrNull?['w'] ??
      (jsTruthy(target['weight']) ? target['weight'] : e['weight']),
);
bool trainingHasLoad(Map<String, dynamic> e, List<Map<String, dynamic>> sets) =>
    musclesOf(e['name'], '${e['part']}')?['kind'] != 'bw' &&
    (jsTruthy(e['machine']) ||
        jsNumber(e['weight']) > 0 ||
        jsNumber(sets.firstOrNull?['w']) > 0);

Future<String> saveTrainingSet(
  AppController app,
  TodayModel model,
  Map<String, dynamic> e,
  num reps,
  num weight,
) async {
  if (!reps.isFinite || reps < 1) throw StateError('先填次数');
  if (jsTruthy(e['machine']) && weight <= 0) {
    throw StateError('先填这台器械的重量（座椅配重数字）');
  }
  final ids = await app.repo.addSets(
    date: model.iso,
    part: '${e['part']}',
    exercise: '${e['name']}',
    unilateral: jsTruthy(e['side']),
    rows: [
      {'weight': weight, 'reps': reps.round(), 'rpe': null, 'type': '正式'},
    ],
  );
  final after = TodayModel(app);
  final wasComplete = model.items.any(
    (i) => i['ex']['id'] == e['id'] && i['complete'] == true,
  );
  final isComplete = after.items.any(
    (i) => i['ex']['id'] == e['id'] && i['complete'] == true,
  );
  if (!model.complete && after.complete) {
    app.haptics.completed();
  } else if (!wasComplete && isComplete) {
    app.haptics.exerciseCompleted();
  } else {
    app.haptics.saved();
  }
  app.startRest(jsNumber(e['rest']) > 0 ? jsNumber(e['rest']).toInt() : null);
  return ids.single;
}

/// Feedback updates the existing row, preserving its ID, timestamp and notes.
Future<void> trainingFeedback(
  AppController app,
  String id, {
  int? remaining,
  String? flag,
}) => app.repo.mutate((state) {
  final row = state['sets'][id];
  if (row == null || row['deleted'] == true) return;
  if (remaining != null) row['rpe'] = 10 - remaining;
  if (flag != null) row['flag'] = flag;
  mark(state, 'sets', id);
  mark(state, 'days', '${row['date']}');
}, incrementRevision: true);
