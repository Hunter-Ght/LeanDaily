import 'format.dart';
import 'plan.dart' show resolveEx;
import 'progress.dart' as progression;
import 'progress_options.dart';
import 'stats_range.dart';
import 'strength_rows.dart';
import 'units.dart';

/// 一个动作在进阶规则里的当前状态：计划里的动作 + `targetFor` 的结果。
class StrengthStep {
  const StrengthStep({
    required this.ex,
    required this.target,
    required this.adjustable,
    this.capConfirms = 2,
  });

  /// 计划里的这个动作（已按阶梯解析）。
  final Map<String, dynamic> ex;

  /// `progress.targetFor` 的返回值：目标次数、连续做到的次数、上次的评估等。
  final Map<String, dynamic> target;

  /// 重量可以按档调整（有器械 / 杠铃 / 可调哑铃）：做满之后下一步是加重量，否则是升级难度。
  final bool adjustable;

  /// 做满上限要连续稳定几次才进阶（进阶规则里 2 次，有经验的用户 3 次）。
  final int capConfirms;
}

/// 计划里所有动作（按阶梯解析后）。
Iterable<Map<String, dynamic>> _planExercises(Map<String, dynamic> plan) sync* {
  final raw = plan['workouts'];
  final workouts = raw is Map ? raw.values : (raw is List ? raw : const []);
  for (final w in workouts) {
    for (final e in jsonRows(jsonMap(w)['exercises'])) {
      yield resolveEx(plan, e);
    }
  }
}

/// 计划里按秒计的动作名：这些动作记录里的「次数」是秒数。
Set<String> timedExerciseNames(Map<String, dynamic> plan) => {
  for (final e in _planExercises(plan))
    if (e['unit'] == 'sec') '${e['name']}',
};

/// 查这个动作的进阶状态；动作不在计划里（计划外动作、旧阶梯）返回 null。
StrengthStep? strengthStepFor(
  String name, {
  required Map<String, dynamic> plan,
  required Map<String, dynamic> days,
  required Map<String, dynamic> dayStates,
  required Map<String, dynamic> progress,
  required String today,
  required ProgressOptions options,
}) {
  final ex = _planExercises(plan).where((e) => e['name'] == name).firstOrNull;
  if (ex == null) return null;
  final target = progression.targetFor(
    ex,
    days,
    dayStates: dayStates,
    today: today,
    include: true,
    progress: progress,
    options: options,
  );
  final loaded = ex['machine'] == true || jsNumber(ex['weight']) > 0;
  return StrengthStep(
    ex: ex,
    target: target,
    adjustable: loaded && adjustableLoad(ex, options),
    capConfirms: options.capConfirms,
  );
}

/// 力量块每行的那一句话（每行只有一句），按阶段给最有用的信息：
/// - 只记录过 1 次：告诉他再练一次就能看到变化；
/// - 有变化：几多（估算极限 / 次数 / 时长）、比什么时候；
/// - 持平：离进阶规则的下一步还差什么；拿不到进阶状态才写「与上次持平」。
String strengthCaption(
  StrengthRow row, {
  required StatsRange range,
  Units units = Units.metric,
  StrengthStep? step,
}) {
  if (row.points.length < 2 || row.change == StrengthChange.first) {
    return '已记录 1 次，再练一次就能看到变化';
  }
  final base = row.base == StrengthBase.firstRecord
      ? '第一次记录'
      : switch (range) {
          StatsRange.weeks4 => '4 周前',
          StatsRange.weeks12 => '12 周前',
          StatsRange.all => '第一次记录',
        };
  // 次数、秒数不是重量：只有带重量的动作才按单位制换算。
  final v = row.bodyweight ? fmt(row.delta) : units.loadDelta(row.delta);
  final u = units.weightUnit;
  return switch (row.change) {
    StrengthChange.idle => switch (range) {
      StatsRange.weeks12 => '近 12 周没练过',
      _ => '近 4 周没练过',
    },
    StrengthChange.flat => nextStepHint(step) ?? '与上次持平',
    StrengthChange.up =>
      row.timed
          ? '↑ 时长 +$v 秒（比$base）'
          : row.bodyweight
          ? '↑ 次数 +$v（比$base）'
          : '↑ 估算极限 +$v $u（比$base）',
    StrengthChange.down =>
      row.timed
          ? '时长 −$v 秒（比$base）'
          : row.bodyweight
          ? '次数 −$v（比$base）'
          : '估算极限 −$v $u（比$base）',
    StrengthChange.first => '',
  };
}

/// 持平时，离进阶规则的下一步还差什么；没有进阶状态、或状态里没有值得说的就返回 null。
String? nextStepHint(StrengthStep? step) {
  if (step == null) return null;
  final ex = step.ex, t = step.target;
  final last = t['last'] is Map ? jsonMap(t['last']) : null;
  if (last == null) return null;
  final sec = ex['unit'] == 'sec';
  final reps = jsNumber(t['reps']), max = jsNumber(ex['max']);
  final stepSize = sec ? 5 : 1;
  // 先说要紧的：上次有不适、状态差，不谈进阶。
  if (last['flag'] == 'pain') return '上次标了不舒服，这次先不加量';
  if (last['flag'] == 'form') return '上次动作有点变形，先把动作做标准';
  if (last['skipped'] == true) return '上次状态不好，不算进度';
  if (last['met'] != true) {
    final got = fmt(last['minReps']);
    return sec
        ? '目标 ${fmt(reps)} 秒，上次做到 $got 秒'
        : '目标 ${fmt(reps)} 次，上次做到 $got 次';
  }
  if (reps >= max) {
    final left = (step.capConfirms - jsNumber(t['cap'])).toInt();
    final weight = step.adjustable;
    if (left <= 0) {
      return switch ((sec, weight)) {
        (false, true) => '已稳定做满 ${fmt(max)} 次，可以加重量了',
        (false, false) => '已稳定做满 ${fmt(max)} 次，可以升级难度了',
        (true, true) => '已稳定做满 ${fmt(max)} 秒，可以加重量了',
        (true, false) => '已稳定做满 ${fmt(max)} 秒，可以升级难度了',
      };
    }
    final m = fmt(max);
    if (left == 1) {
      return switch ((sec, weight)) {
        (false, true) => '再做满 1 次 $m 次就加重量',
        (false, false) => '再做满 1 次 $m 次就升级难度',
        (true, true) => '再做满 1 次 $m 秒就加重量',
        (true, false) => '再做满 1 次 $m 秒就升级难度',
      };
    }
    return switch ((sec, weight)) {
      (false, true) => '再做满 $left 次 $m 次就加重量',
      (false, false) => '再做满 $left 次 $m 次就升级难度',
      (true, true) => '再做满 $left 次 $m 秒就加重量',
      (true, false) => '再做满 $left 次 $m 秒就升级难度',
    };
  }
  // 目标刚被提高：上次做到了旧目标。
  if (reps > jsNumber(last['target'])) {
    return sec ? '目标提到了 ${fmt(reps)} 秒，下次试试' : '目标提到了 ${fmt(reps)} 次，下次试试';
  }
  if (jsNumber(t['streak']) >= 1) {
    final next = fmt(reps + stepSize);
    return sec
        ? '再做到 ${fmt(reps)} 秒，目标就提到 $next 秒'
        : '再做到 ${fmt(reps)} 次，目标就提到 $next 次';
  }
  return null;
}
