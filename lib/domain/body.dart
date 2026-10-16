import 'dart:math' as math;

/// JSON shapes, shared unchanged with storage and the onboarding UI.
typedef Profile = Map<String, dynamic>;
typedef Targets = Map<String, dynamic>;

// Existing thin-muscle route boundaries, shared by the visual scale.
const thinBodyFatMale = (8.0, 13.0);
const thinBodyFatFemale = (16.0, 23.0);

const profileDefaults = <String, dynamic>{
  'sex': 'male',
  'age': 30,
  'heightCm': 175.0,
  'weightKg': 70.0,
  'bodyFatPct': null,
  'bodyFatMethod': 'bmi',
  'waistCm': null,
  'neckCm': null,
  'hipCm': null,
  'goalBodyFatPct': null,
  'activity': 'light',
  'venue': 'both',
  'daysPerWeek': 3,
  'experience': 'new',
  'limits': <String>[],
};

/// Missing fields use defaults; supplied invalid/clamped fields appear in errors.
/// Optional measurements stay null rather than inventing a body measurement.
Map<String, dynamic> normalizeProfile(Object? raw) {
  final input = raw is Map ? raw : const <String, dynamic>{};
  final errors = <String>[];
  final p = <String, dynamic>{};
  if (raw != null && raw is! Map) errors.add('个人资料格式无效');
  void invalid(String key) => errors.add('个人资料字段无效：$key');
  void choice(String key, List<String> choices) {
    final v = input[key];
    p[key] = choices.contains(v) ? v : profileDefaults[key];
    if (input.containsKey(key) && !choices.contains(v)) invalid(key);
  }

  void numeric(String key, num min, num max, {bool integer = false}) {
    final v = input[key];
    if (v == null && profileDefaults[key] == null) {
      p[key] = null;
    } else if (v is num && v.isFinite) {
      final n = integer ? v.round() : v;
      p[key] = n.clamp(min, max);
      if (n != v || n < min || n > max) invalid(key);
    } else {
      p[key] = profileDefaults[key];
      if (input.containsKey(key)) invalid(key);
    }
  }

  choice('sex', ['male', 'female']);
  numeric('age', 10, 90, integer: true);
  numeric('heightCm', 120, 230);
  numeric('weightKg', 30, 250);
  numeric('bodyFatPct', 3, 60);
  choice('bodyFatMethod', ['manual', 'navy', 'picker', 'bmi']);
  for (final key in ['waistCm', 'neckCm', 'hipCm']) {
    numeric(key, 20, 200);
  }
  // Keep a requested goal below the sex-specific floor until buildTargets so
  // that the safety warning isn't lost on saving/loading the profile.
  numeric('goalBodyFatPct', 3, 60);
  choice('activity', ['sedentary', 'light', 'active']);
  choice('venue', ['bodyweight', 'dumbbell', 'gym', 'both']);
  numeric('daysPerWeek', 2, 6, integer: true);
  choice('experience', ['new', 'some', 'trained']);
  final limits = input['limits'];
  p['limits'] = limits is List
      ? limits.whereType<String>().toList()
      : <String>[];
  if (input.containsKey('limits') &&
      (limits is! List || limits.any((v) => v is! String))) {
    invalid('limits');
  }
  return {'profile': p, 'errors': errors};
}

Profile _profile(Object? p) => normalizeProfile(p)['profile'] as Profile;
double _n(Profile p, String key) => (p[key] as num).toDouble();
bool _male(Profile p) => p['sex'] == 'male';
double bmi(Profile profile) {
  final p = _profile(profile);
  return _n(p, 'weightKg') / math.pow(_n(p, 'heightCm') / 100, 2);
}

double _log10(double x) => math.log(x) / math.ln10;

/// Invalid/missing measurements fall back to BMI, including nonpositive Navy
/// logarithm arguments. Picker values snap to the nearest reference band.
Map<String, dynamic> estimateBodyFat(Profile profile) {
  final p = _profile(profile);
  final method = p['bodyFatMethod'];
  final entered = p['bodyFatPct'] as num?;
  double? value;
  var margin = 5;
  var used = 'bmi';
  if ((method == 'manual' || method == 'picker') && entered != null) {
    used = method as String;
    margin = used == 'manual' ? 0 : 4;
    value = entered.toDouble();
    if (used == 'picker') {
      final bands = _male(p)
          ? [6, 10, 15, 20, 25, 30, 35, 40]
          : [14, 18, 22, 26, 30, 35, 40, 45];
      value = bands
          .reduce((a, b) => (a - entered).abs() <= (b - entered).abs() ? a : b)
          .toDouble();
    }
  } else if (method == 'navy') {
    final waist = p['waistCm'] as num?;
    final neck = p['neckCm'] as num?;
    final hip = p['hipCm'] as num?;
    if (waist != null && neck != null && (_male(p) || hip != null)) {
      final circumference = (waist + (_male(p) ? 0 : hip!) - neck).toDouble();
      if (circumference > 0) {
        final denominator = _male(p)
            ? 1.0324 -
                  .19077 * _log10(circumference) +
                  .15456 * _log10(_n(p, 'heightCm'))
            : 1.29579 -
                  .35004 * _log10(circumference) +
                  .22100 * _log10(_n(p, 'heightCm'));
        final estimate = 495 / denominator - 450;
        if (estimate.isFinite) {
          value = estimate;
          used = 'navy';
          margin = 3;
        }
      }
    }
  }
  value ??= 1.20 * bmi(p) + .23 * _n(p, 'age') - (_male(p) ? 10.8 : 0) - 5.4;
  return {
    'value': (value.clamp(3, 60) * 10).round() / 10,
    'margin': margin,
    'method': used,
  };
}

double bmr(Profile profile) {
  final p = _profile(profile);
  return 10 * _n(p, 'weightKg') +
      6.25 * _n(p, 'heightCm') -
      5 * _n(p, 'age') +
      (_male(p) ? 5 : -161);
}

double tdee(Profile profile) {
  final p = _profile(profile);
  return bmr(p) *
      const {'sedentary': 1.25, 'light': 1.4, 'active': 1.55}[p['activity']]!;
}

String stageOf(Profile profile, [num? bodyFat]) {
  final p = _profile(profile);
  final fat = bodyFat ?? estimateBodyFat(p)['value'] as num;
  final male = _male(p);
  if (_n(p, 'age') < 18) return 'youth';
  if (bmi(p) < 18.5 || (bmi(p) < 20 && fat < (male ? 18 : 26))) return 'bulk';
  if (fat >= (male ? 25 : 35)) return 'cut';
  if (fat >= (male ? 18 : 28)) return 'recomp';
  if (fat >= (male ? 13 : 23)) return 'trim';
  return 'refine';
}

String stageName(String stage) => const {
  'cut': '减脂路线',
  'recomp': '重组路线',
  'trim': '微调路线',
  'refine': '精修路线',
  'bulk': '增肌路线',
  'youth': '成长期',
}[stage]!;

String routeText(String stage) => const {
  'cut': '温和调整饮食，配合力量训练保留肌肉。',
  'recomp': '热量略低于消耗，吃够蛋白，逐步增肌减脂。',
  'trim': '小幅调整饮食，配合训练逐步接近目标。',
  'refine': '维持体脂，逐步补强肩背和腹部。',
  'bulk': '吃够热量和蛋白，配合力量训练增加肌肉。',
  'youth': '保持正常饮食，以力量和动作质量为主',
}[stage]!;

Targets buildTargets(Profile profile, {num? goalOverride}) {
  final p = _profile(profile);
  final fat = estimateBodyFat(p);
  final stage = stageOf(p, fat['value'] as num);
  final floor = _male(p) ? 8 : 16;
  final requested = goalOverride != null && goalOverride.isFinite
      ? goalOverride.toDouble()
      : (p['goalBodyFatPct'] as num?)?.toDouble() ?? (_male(p) ? 11.0 : 20.0);
  final goal = requested.clamp(floor, 60);
  final warnings = <String>[];
  if (bmi(p) < 18.5) warnings.add('建议先吃够营养，配合训练增加肌肉。');
  if (requested < floor) {
    warnings.add('目标体脂低于安全下限，已调整为 $floor%');
    // SPEC does not define another aggressive-goal threshold. The explicit
    // safety floor is the only threshold used here.
    warnings.add('已采用安全范围内的目标。');
  }
  final factor = const {
    'cut': -.22,
    'recomp': -.10,
    'trim': -.12,
    'refine': 0.0,
    'bulk': .08,
    'youth': 0.0,
  }[stage]!;
  final rawKcal = (tdee(p) * (1 + factor.clamp(-.25, double.infinity))).round();
  final minKcal = math.max(bmr(p), _male(p) ? 1500 : 1200);
  if (rawKcal < minKcal) warnings.add('每日热量已按安全下限抬高');
  // Round to tens without letting rounding drop below the safety floor.
  final kcal = math.max(
    (math.max(rawKcal, minKcal) / 10).round() * 10,
    (minKcal / 10).ceil() * 10,
  );
  final weight = _n(p, 'weightKg');
  final protein =
      (math.min(
                220,
                weight *
                    (stage == 'cut'
                        ? 1.8
                        : stage == 'youth'
                        ? 1.6
                        : 2),
              ) /
              5)
          .round() *
      5;
  if (stage == 'youth') warnings.add('年龄未满 18 岁，吃够睡够，重视动作质量。');
  if ((fat['margin'] as num) > 0) {
    warnings.add('体脂为估算值，估算误差 ±${fat['margin']}%');
  }
  List<int>? range;
  if (['cut', 'recomp', 'trim'].contains(stage)) {
    final lean = weight * (1 - (fat['value'] as num) / 100);
    final targetWeight = lean / (1 - goal / 100);
    final loss = math.max(0, weight - targetWeight);
    final weeks = loss / (weight * (stage == 'cut' ? .008 : .005));
    range = [
      (weeks * .8).round().clamp(4, 52),
      (weeks * 1.3).round().clamp(4, 52),
    ];
    if (weeks > 16) warnings.add('减脂超过 16 周，建议阶段性休整');
  }
  final targets = <String, dynamic>{
    'stage': stage,
    'bodyFat': fat,
    'goalBodyFat': goal,
    'kcal': kcal,
    'proteinG': protein,
    'proteinPerJin': protein / (weight * 2),
    'weeksRange': range,
    'warnings': warnings,
  };
  targets['headline'] = headline(targets);
  return targets;
}

/// 每日热量的安全下限：不低于基础代谢，男 1500 / 女 1200 千卡。
int kcalFloor(Profile profile) => math.max(bmr(_profile(profile)), _male(_profile(profile)) ? 1500 : 1200).ceil();

String _text(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();
String headline(Targets targets) {
  final fat = targets['bodyFat'] as Map;
  return '体脂约 ${_text(fat['value'] as num)}%，目标 ${_text(targets['goalBodyFat'] as num)}%。'
      '${routeText(targets['stage'] as String)}';
}
