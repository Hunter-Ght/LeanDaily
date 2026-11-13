import 'format.dart';

/// 显示用的单位制。存储永远是 kg / cm，这里只负责显示与输入的换算。
enum UnitSystem { metric, imperial }

const double kgPerLb = 0.45359237;
const double cmPerInch = 2.54;

double _round(num v, num scale) {
  final x = v * scale;
  return x.isFinite ? x.round() / scale : v.toDouble();
}

/// 集中的单位层：所有界面通过它格式化、解析重量、身高、腰围。
/// 纯 Dart，不依赖 Flutter。公制下的输出与引入单位层之前完全一致。
class Units {
  const Units(this.system);
  static const metric = Units(UnitSystem.metric);
  static const imperial = Units(UnitSystem.imperial);

  final UnitSystem system;
  bool get isImperial => system == UnitSystem.imperial;
  String get id => isImperial ? 'imperial' : 'metric';

  static Units byId(Object? id) => id == 'imperial' ? imperial : metric;

  /// 新安装按系统地区决定：美国默认英制，其余公制。
  static Units forRegion(String? countryCode) =>
      countryCode?.toUpperCase() == 'US' ? imperial : metric;

  @override
  bool operator ==(Object other) => other is Units && other.system == system;
  @override
  int get hashCode => system.hashCode;

  // ------------------------------------------------------------ 单位名

  String get weightUnit => isImperial ? 'lb' : 'kg';

  /// 腰围、颈围、臀围的单位。
  String get lengthUnit => isImperial ? 'in' : 'cm';
  String get heightUnit => isImperial ? 'ft in' : 'cm';

  // ------------------------------------------------------------ 换算

  double kgToLb(num kg) => kg / kgPerLb;
  double lbToKg(num lb) => lb * kgPerLb;

  // ------------------------------------------------------------ 训练重量
  // 公制：原样（显示时仍由 fmt 取一位小数）。英制：取到 0.5 lb。

  num loadValue(num kg) => isImperial ? _round(kgToLb(kg), 2) : kg;

  /// 用户输入的训练重量（显示单位）转成存储的 kg。英制保留三位小数，
  /// 这样「存成 kg 再显示」仍是原来的 lb 数。
  double loadToKg(num value) =>
      isImperial ? _round(lbToKg(value), 1000) : value.toDouble();

  /// 不带单位的训练重量，如 `40`、`88.5`。
  String load(num kg) => fmt(loadValue(kg));

  /// 带单位的训练重量，如 `40 kg`、`88.5 lb`。
  String loadText(num kg) => '${load(kg)} $weightUnit';

  /// 训练重量的变化量（kg 差）：公制同 [fmt]，英制一位小数的 lb，如 `5.5`。
  String loadDelta(num kgDelta) => isImperial
      ? fmt(double.parse(kgToLb(kgDelta).toStringAsFixed(1)))
      : fmt(kgDelta);

  /// 计划/模板给的建议重量（不是用户记过的）：英制吸附到最近的可用档位——
  /// 20 lb 以下 2.5 lb 一档，其余 5 lb 一档，如 5 kg → 10 lb、10 kg → 20 lb、
  /// 20 kg → 45 lb。返回的 kg 对应这个整档，新用户照着练完存下的就是它。
  /// 用户实际记过的重量不要走这里，直接 [loadValue] 如实换算。公制原样。
  num suggestedLoad(num kg) {
    if (!isImperial || !(kg > 0)) return kg;
    final lb = kgToLb(kg);
    final snapped = lb < 20 ? _nearest(lb, 2.5) : _nearest(lb, 5);
    return loadToKg(snapped < 2.5 ? 2.5 : snapped);
  }

  String suggested(num kg) => load(suggestedLoad(kg));
  String suggestedText(num kg) => loadText(suggestedLoad(kg));

  static double _nearest(num v, num step) =>
      (v / step).round() * step.toDouble();

  /// 把 kg 对齐到英制的 0.5 lb 档（公制原样），用于进阶建议写入的新重量。
  num snapLoad(num kg) => isImperial ? loadToKg(loadValue(kg)) : kg;

  /// 训练模式里加减按钮的结果（显示单位）。公制保持原行为：
  /// 器械 [explicitKg] 或 2.5，其余 0.5。英制：哑铃 5 lb（20 lb 以下 2.5 lb），
  /// 杠铃/器械 5 lb；用户给某个动作设了「最小一档」时按它走。
  num stepLoad(
    Map<String, dynamic> ex,
    num current, {
    required bool up,
    num? explicitKg,
  }) {
    if (!isImperial) {
      final step = jsTruthy(ex['machine']) ? (explicitKg ?? 2.5) : .5;
      return _round(current + (up ? step : -step), 10);
    }
    final explicit = explicitKg != null && explicitKg > 0
        ? _round(kgToLb(explicitKg), 100)
        : null;
    if (explicit != null) {
      return _round(current + (up ? explicit : -explicit), 100);
    }
    final dumbbell = _isDumbbell(ex) && !jsTruthy(ex['machine']);
    num step(num at) => dumbbell && at < 20 ? 2.5 : 5;
    var next = up ? current + step(current) : current - step(current - .01);
    // 跨过 20 lb 时先停在 20，不跳档。
    if (dumbbell) {
      if (up && current < 20 && next > 20) next = 20;
      if (!up && current > 20 && next < 20) next = 20;
    }
    return _round(next, 2);
  }

  /// 进阶建议的加重档（kg）。英制对应 5 lb / 2.5 lb 的整档。
  double progressStepKg(Map<String, dynamic> ex, num weightKg) {
    final lb = loadValue(weightKg);
    final stepLb = _isDumbbell(ex) && lb < 20 ? 2.5 : 5;
    return loadToKg(stepLb);
  }

  static bool _isDumbbell(Map<String, dynamic> ex) =>
      '${ex['name']} ${ex['gear'] ?? ''}'.contains('哑铃');

  /// 「最小一档」输入框里的文字：公制 kg，英制 lb（最多两位小数）。
  String stepText(num kg) =>
      isImperial ? fmt(_round(kgToLb(kg), 100)) : fmt(kg);

  /// 「最小一档」输入的值（显示单位）转 kg。
  double stepToKg(num value) =>
      isImperial ? _round(lbToKg(value), 10000) : value.toDouble();

  /// 「最小一档」允许的上限（显示单位）。
  num get stepMax => isImperial ? 110 : 50;

  // ------------------------------------------------------------ 体重（0.1）

  num bodyWeightValue(num kg) => isImperial ? _round(kgToLb(kg), 10) : kg;

  /// 不带单位。[fixed] 为 true 时总是一位小数（`70.0`），否则同 [fmt]。
  String bodyWeight(num kg, {bool fixed = false}) {
    final v = bodyWeightValue(kg);
    return fixed ? v.toStringAsFixed(1) : fmt(v);
  }

  String bodyWeightText(num kg, {bool fixed = false}) =>
      '${bodyWeight(kg, fixed: fixed)} $weightUnit';

  /// 英制保留三位小数，lb 往返不漂移（0.1 lb ≈ 0.045 kg）。
  double bodyWeightToKg(num value) =>
      isImperial ? _round(lbToKg(value), 1000) : value.toDouble();

  /// 体重变化量（kg 差）显示成一位小数的显示单位数值，如 `0.3`。
  String bodyWeightDelta(num kgDelta, {bool fixed = false}) {
    final text = bodyWeightValue(kgDelta.abs()).toStringAsFixed(1);
    return fixed ? text : fmt(double.parse(text));
  }

  /// 体重输入框的合法范围（与存储的 30–250 kg 一致，显示单位，已取整到 0.1）。
  String get bodyWeightRangeText => isImperial ? '67–551 lb' : '30–250 kg';
  bool bodyWeightInRange(num value) {
    final kg = bodyWeightToKg(value);
    return value.isFinite && kg >= 30 && kg <= 250;
  }

  // ------------------------------------------------------------ 身高（ft + in）

  /// 总英寸数（四舍五入到整英寸）。
  int heightInches(num cm) => (cm / cmPerInch).round();
  (int, int) feetInches(num cm) {
    final total = heightInches(cm);
    return (total ~/ 12, total % 12);
  }

  double heightFromInches(num inches) => _round(inches * cmPerInch, 10);
  double heightFromFeetInches(num feet, num inches) =>
      heightFromInches(feet * 12 + inches);

  /// 身高：公制 `175 cm`，英制 `5 ft 9 in`。
  String heightText(num cm) {
    if (!isImperial) return '${fmt(cm)} cm';
    final (ft, inch) = feetInches(cm);
    return '$ft ft $inch in';
  }

  // ------------------------------------------------------------ 腰围等围度（0.1 in）

  num lengthValue(num cm) => isImperial ? _round(cm / cmPerInch, 10) : cm;
  String length(num cm) => fmt(lengthValue(cm));
  String lengthText(num cm) => '${length(cm)} $lengthUnit';

  /// 英制保留两位小数，in 往返不漂移。
  double lengthToCm(num value) =>
      isImperial ? _round(value * cmPerInch, 100) : value.toDouble();

  /// 围度输入框的合法范围（与存储的 20–200 cm 一致）。
  String get lengthRangeText => isImperial ? '8–78 in' : '20–200 cm';

  // ------------------------------------------------------------ 静态文案

  static final _kgInText = RegExp(
    r'(\d+(?:\.\d+)?)(?:\s?[–-]\s?(\d+(?:\.\d+)?))?\s?kg\b',
  );

  /// 把静态文案（器材说明、动作要点）里的「5 kg」换成英制下常见的整数磅数
  /// （小于 2 lb 取 0.5，小于 10 lb 取整，其余取 5 的倍数），如 5 kg → 10 lb、20 kg → 45 lb。
  /// 公制原样返回。
  String localizeText(String s) {
    if (!isImperial || !s.contains('kg')) return s;
    return s.replaceAllMapped(_kgInText, (m) {
      String one(String v) {
        final lb = kgToLb(double.parse(v));
        return fmt(
          lb < 2
              ? _round(lb, 2)
              : lb < 10
              ? _round(lb, 1)
              : _nearest(lb, 5),
        );
      }

      final lo = one(m[1]!);
      return m[2] == null ? '$lo lb' : '$lo–${one(m[2]!)} lb';
    });
  }
}
