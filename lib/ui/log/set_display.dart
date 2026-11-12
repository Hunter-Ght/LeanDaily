import '../../domain/catalog.dart';
import '../../domain/format.dart';
import '../../domain/units.dart';

/// Zero denotes body weight in legacy records. For loaded bodyweight moves the
/// catalogue prescription distinguishes extra load from an ordinary weight.
String setWeightLabel(Map<String, dynamic> set, [Units units = Units.metric]) {
  final w = jsNumber(set['w']);
  if (w == 0) return '自重';
  final exercise = catalog()['${set['ex']}'];
  final bodyweight =
      exercise != null &&
      !jsTruthy(exercise['machine']) &&
      jsNumber(exercise['weight']) == 0;
  return '${bodyweight ? '+' : ''}${units.loadText(w)}';
}

/// 时间线小片里的重量部分：'自重'、'+10'（自重动作加负重）或 '40'，不带单位。
String setChipWeight(Map<String, dynamic> set, [Units units = Units.metric]) {
  final label = setWeightLabel(set, units);
  final suffix = ' ${units.weightUnit}';
  return label.endsWith(suffix)
      ? label.substring(0, label.length - suffix.length)
      : label;
}

String setDisplay(Map<String, dynamic> set, [Units units = Units.metric]) =>
    '${setWeightLabel(set, units)} × ${fmt(set['reps'])} 次${setFlagLabel(set).isEmpty ? '' : ' · ${setFlagLabel(set)}'}';
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
