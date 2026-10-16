import '../../domain/catalog.dart';
import '../../domain/format.dart';

/// Zero denotes body weight in legacy records. For loaded bodyweight moves the
/// catalogue prescription distinguishes extra load from an ordinary weight.
String setWeightLabel(Map<String, dynamic> set) {
  final w = jsNumber(set['w']);
  if (w == 0) return '自重';
  final exercise = catalog()['${set['ex']}'];
  final bodyweight =
      exercise != null &&
      !jsTruthy(exercise['machine']) &&
      jsNumber(exercise['weight']) == 0;
  return '${bodyweight ? '+' : ''}${fmt(w)} kg';
}

String setDisplay(Map<String, dynamic> set) =>
    '${setWeightLabel(set)} × ${fmt(set['reps'])} 次${setFlagLabel(set).isEmpty ? '' : ' · ${setFlagLabel(set)}'}';
String setEffortLabel(Object? rpe) => rpe == null || '$rpe'.isEmpty
    ? ''
    : '还能做 ${10 - jsNumber(rpe) >= 3 ? '3+' : fmt(10 - jsNumber(rpe))} 次';

String setFlagLabel(Map<String, dynamic> set) => switch (set['flag']) {
  'form' => '动作变形',
  'pain' => '有点痛',
  _ => '',
};
String setFeedbackLabel(Map<String, dynamic> set) => [
  setEffortLabel(set['rpe']),
  setFlagLabel(set),
].where((s) => s.isNotEmpty).join(' · ');
