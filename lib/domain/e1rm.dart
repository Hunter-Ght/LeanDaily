/// 估算 1RM（估算极限）：全 App 统一用 Epley 公式，只在这里算。
///
/// 估算极限 = 重量 × (1 + 次数 / 30)，单位和传入的重量一致（规则内部一律 kg）。
/// 进度页的最佳成绩和曲线、训练小结的「新纪录」、肌肉恢复的强度估计都从这里取值。
library;

/// 次数超过这个数，估算就不准了（公式在低次数时最可靠）：照常计算，界面上要标注「仅供参考」。
const e1rmReliableMaxReps = 12;

/// Epley 估算极限，不取整。重量为 0（自重）时结果为 0。
num estimateE1rm(num weight, num reps) => weight * (1 + reps / 30);

/// 保留 1 位小数的估算极限，进度页和记录导出用。
num estimateE1rmRounded(num weight, num reps) {
  final v = estimateE1rm(weight, reps) * 10;
  return v.isFinite ? (v + .5).floor() / 10 : v;
}

/// 这个次数下的估算是否可靠（1～12 次）。
bool e1rmReliable(num reps) => reps >= 1 && reps <= e1rmReliableMaxReps;

/// 判断「新纪录」用的统一指标：带重量的动作比估算极限，自重动作比次数。
num strengthMetric(num weight, num reps) =>
    weight > 0 ? estimateE1rm(weight, reps) : reps;
