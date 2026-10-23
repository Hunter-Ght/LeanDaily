/// 矢量动作示范的运动学：关键帧插值 + 两段式反向运动学（IK）。
///
/// 纯函数，不依赖 Flutter。坐标单位约等于厘米，y 轴朝上，地面 y = 0；
/// 侧面视角人物面朝 +x。界面层只负责把 [MotionPose] 画出来。
library;

import 'dart:math' as math;

class P {
  const P(this.x, this.y);
  final double x, y;
  P operator +(P o) => P(x + o.x, y + o.y);
  P operator -(P o) => P(x - o.x, y - o.y);
  P operator *(double k) => P(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  P get unit {
    final l = length;
    return l == 0 ? const P(0, 0) : P(x / l, y / l);
  }

  /// 逆时针转 90°（y 朝上）。
  P get ccw => P(-y, x);

  /// 顺时针转 90°。
  P get cw => P(y, -x);
  static P lerp(P a, P b, double t) => a + (b - a) * t;
  @override
  String toString() => 'P(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

enum MotionView { side, front }

/// 一段肢体：从 [a]（近端）到 [b]（远端）的圆头锥形胶囊；[poly] 非空时画成光滑闭合轮廓。
/// [layer]：0 = 远侧（颜色更浅），1 = 躯干，2 = 近侧。
class MotionPart {
  const MotionPart(
    this.id,
    this.a,
    this.b,
    this.ra,
    this.rb, {
    this.layer = 1,
    this.poly = const [],
  });
  final String id;
  final P a, b;
  final double ra, rb;
  final int layer;
  final List<P> poly;
}

/// 肌肉高亮：画在 [part] 内部（会裁在肢体轮廓里）。[from]/[to] 是沿肢体的比例，
/// [off] 是偏离中线的半径倍数（正 = 近端→远端方向逆时针一侧），[width] 是半径倍数。
/// 解剖朝向：躯干前侧、上臂后侧（肱三头）是负值；大腿前侧、上臂前侧是正值。
class MotionMark {
  const MotionMark(
    this.part, {
    required this.from,
    required this.to,
    this.off = 0,
    this.width = .7,
    this.weight = 1,
  });
  final String part;
  final double from, to, off, width, weight;
}

/// 教学辅助线（虚线）：水平线 [y]（从 [x0] 到 [x1]），或连接两个关节 [j1]→[j2]。
class MotionGuide {
  const MotionGuide.level(double this.y, this.x0, this.x1)
    : j1 = null,
      j2 = null,
      lift = 0;

  /// [lift]：整条线沿法线（j1→j2 逆时针一侧）平移，画在身体外面不被挡住。
  const MotionGuide.joints(String this.j1, String this.j2, {this.lift = 0})
    : y = null,
      x0 = 0,
      x1 = 0;
  final double? y;
  final double x0, x1, lift;
  final String? j1, j2;
}

/// 器械：目前只有哑铃端面（正面看过去的哑铃）。
class MotionProp {
  const MotionProp.dumbbellEnd(this.at);
  final String at;
}

/// 关键帧：[t] 秒时的姿势参数 [v]（未写的沿用 [MotionSpec.base]）。
/// 从这一帧开始的这一段叫 [phase]，发力程度 [load]（0–1）。最后一帧只标结束时间。
class MotionKey {
  const MotionKey(this.t, [this.v = const {}, this.load = 0, this.phase = '']);
  final double t;
  final Map<String, double> v;
  final double load;
  final String phase;
}

class MotionSpec {
  const MotionSpec({
    required this.view,
    required this.keys,
    required this.base,
    required this.marks,
    required this.bounds,
    this.guides = const [],
    this.props = const [],
  });
  final MotionView view;
  final List<MotionKey> keys;
  final Map<String, double> base;
  final List<MotionMark> marks;

  /// 取景框 [左, 下, 右, 上]：固定不随动作缩放，画面不会“呼吸”。
  final List<double> bounds;
  final List<MotionGuide> guides;
  final List<MotionProp> props;
  double get period => keys.last.t;

  /// 发力最大的那一段的起点：减少动态效果时停在这个姿势。
  double get peakTime {
    var best = keys.first;
    for (final k in keys.take(keys.length - 1)) {
      if (k.load > best.load) best = k;
    }
    return best.t;
  }
}

class MotionPose {
  const MotionPose(this.parts, this.joints, this.load, this.phase);

  /// 按绘制顺序排列。
  final List<MotionPart> parts;
  final Map<String, P> joints;
  final double load;
  final String phase;
}

double _ease(double u) =>
    u < .5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3) / 2;
double _rad(double deg) => deg * math.pi / 180;

/// [time] 秒时的姿势；自动循环。
MotionPose sampleMotion(MotionSpec spec, double time) {
  final keys = spec.keys;
  final period = spec.period;
  var t = period <= 0 ? 0.0 : time % period;
  if (t < 0) t += period;
  var i = 0;
  while (i < keys.length - 2 && keys[i + 1].t <= t) {
    i++;
  }
  final k0 = keys[i], k1 = keys[i + 1];
  final span = k1.t - k0.t;
  final e = span <= 0 ? 1.0 : _ease(((t - k0.t) / span).clamp(0, 1));
  final v = <String, double>{};
  for (final name in {...spec.base.keys, ...k0.v.keys, ...k1.v.keys}) {
    final a = k0.v[name] ?? spec.base[name] ?? 0;
    final b = k1.v[name] ?? spec.base[name] ?? 0;
    v[name] = a + (b - a) * e;
  }
  // 发力程度按段给，段与段之间 0.25 秒内平滑过渡，避免数字跳变。
  final previous = keys[(i - 1 + keys.length - 1) % (keys.length - 1)].load;
  final blend = ((t - k0.t) / .25).clamp(0.0, 1.0);
  final load =
      previous + (k0.load - previous) * blend * blend * (3 - 2 * blend);
  final rig = spec.view == MotionView.side ? _side(v) : _front(v);
  return MotionPose(rig.$1, rig.$2, load, k0.phase);
}

/// 身体尺寸（约 175 cm）。
abstract final class Body {
  static const torso = 50.0,
      neck = 8.0,
      head = 10.5,
      upperArm = 29.0,
      forearm = 25.0,
      hand = 8.0,
      thigh = 44.0,
      shin = 43.0,
      footBack = 5.0,
      footFront = 18.0;
}

/// 两段式 IK：根 [root] 到目标 [target]，返回（中间关节, 末端）。
/// [side] = 1 时中间关节在 root→target 的逆时针一侧，-1 为顺时针一侧。够不着时伸直指向目标。
(P, P) solveTwoBone(P root, P target, double l1, double l2, double side) {
  final delta = target - root;
  final dist = delta.length.clamp((l1 - l2).abs() + 1e-3, l1 + l2 - 1e-3);
  final u = delta.length == 0 ? const P(0, -1) : delta.unit;
  final a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist);
  final h = math.sqrt(math.max(0, l1 * l1 - a * a));
  final mid = root + u * a + u.ccw * (h * side);
  return (mid, root + u * dist);
}

P _dir(double deg) => P(math.sin(_rad(deg)), -math.cos(_rad(deg)));
P _heading(double deg) => P(math.cos(_rad(deg)), math.sin(_rad(deg)));

/// 侧面：hipX/hipY 髋；torso 躯干前倾角（相对竖直）；neck 头相对躯干；
/// lean（可选）：身体与地面的夹角，髋由踝沿腿伸直算出、躯干与腿成一直线（俯卧撑、平板一类）；
/// ankX/ankY 踝（IK 定膝，膝在前侧）；foot 脚掌朝向（0 = 水平朝前）；
/// 手臂二选一：handX/handY（IK，肘在后侧）或 sh/el（肩前屈角、肘屈角）；hand 手掌朝向（可选）。
(List<MotionPart>, Map<String, P>) _side(Map<String, double> v) {
  final ankle = P(v['ankX']!, v['ankY']!);
  final lean = v['lean'];
  // 以踝为支点转动：插值角度而不是髋坐标，中途腿不会被 IK 弯折。
  final hip = lean == null
      ? P(v['hipX']!, v['hipY']!)
      : ankle + _heading(lean) * (Body.thigh + Body.shin - .2);
  final torso = lean == null ? v['torso']! : 90 - lean;
  final shoulder = hip + _dir(180 - torso) * Body.torso;
  final headDir = _dir(180 - torso - (v['neck'] ?? 0));
  final neckTop = shoulder + headDir * Body.neck;
  final head = neckTop + headDir * Body.head;
  final joints = <String, P>{
    'hip': hip,
    'shoulder': shoulder,
    'head': head,
    'ankle': ankle,
  };
  // 远侧肢体略向前错开，露出一点轮廓表现纵深。
  const far = P(3.5, .8);
  List<MotionPart> leg(String s, P offset, int layer) {
    final h = hip + offset, an = ankle + offset;
    final (knee, end) = solveTwoBone(h, an, Body.thigh, Body.shin, 1);
    final f = _heading(v['foot'] ?? 0);
    final sole = f.ccw * -3.6;
    joints['knee$s'] = knee;
    return [
      MotionPart('thigh$s', h, knee, 8.6, 6.2, layer: layer),
      MotionPart('shin$s', knee, end, 6.0, 4.1, layer: layer),
      MotionPart(
        'foot$s',
        end + f * -Body.footBack + sole,
        end + f * Body.footFront + sole,
        4.4,
        3.2,
        layer: layer,
      ),
    ];
  }

  List<MotionPart> arm(String s, P offset, int layer) {
    final sh = shoulder + offset;
    late P elbow, wrist;
    if (v.containsKey('handX')) {
      (elbow, wrist) = solveTwoBone(
        sh,
        P(v['handX']!, v['handY']!) + P(offset.x, 0),
        Body.upperArm,
        Body.forearm,
        -1,
      );
    } else {
      elbow = sh + _dir(v['sh'] ?? 0) * Body.upperArm;
      wrist = elbow + _dir((v['sh'] ?? 0) + (v['el'] ?? 0)) * Body.forearm;
    }
    final palm = v.containsKey('hand')
        ? _heading(v['hand']!)
        : (wrist - elbow).unit;
    joints['elbow$s'] = elbow;
    joints['wrist$s'] = wrist;
    return [
      MotionPart('uarm$s', sh, elbow, 5.6, 4.3, layer: layer),
      MotionPart('farm$s', elbow, wrist, 4.2, 3.1, layer: layer),
      MotionPart(
        'hand$s',
        wrist,
        wrist + palm * Body.hand,
        3.2,
        2.6,
        layer: layer,
      ),
    ];
  }

  final parts = <MotionPart>[
    ...arm('F', far, 0),
    ...leg('F', far, 0),
    MotionPart('neck', shoulder, neckTop + headDir * 2, 4.6, 4.2),
    MotionPart('head', head, head, Body.head, Body.head),
    MotionPart('torso', hip, shoulder, 12.5, 11.2),
    ...leg('N', const P(0, 0), 2),
    ...arm('N', const P(0, 0), 2),
  ];
  return (parts, joints);
}

/// 正面：abd 肩外展角（0 = 垂在体侧）；el 肘微屈；shrug 耸肩（厘米）；stance 两踝间半宽。
(List<MotionPart>, Map<String, P>) _front(Map<String, double> v) {
  final shrug = v['shrug'] ?? 0;
  final stance = v['stance'] ?? 12;
  const hipY = 93.0, shY = 145.0;
  final joints = <String, P>{};
  final parts = <MotionPart>[];
  for (final (s, k) in [('L', -1.0), ('R', 1.0)]) {
    final hip = P(9 * k, hipY), ankle = P(stance * k, 8);
    final knee = P.lerp(hip, ankle, Body.thigh / (Body.thigh + Body.shin));
    joints['knee$s'] = knee;
    joints['ankle$s'] = ankle;
    parts
      ..add(MotionPart('thigh$s', hip, knee, 8.2, 6.0))
      ..add(MotionPart('shin$s', knee, ankle, 5.8, 4.0))
      ..add(
        MotionPart(
          'foot$s',
          ankle + P(-2 * k, -4.5),
          ankle + P(4 * k, -5.5),
          4.4,
          3.6,
        ),
      );
  }
  final neckBase = P(0, shY + shrug * .3);
  final head = neckBase + const P(0, Body.neck + Body.head + 2);
  parts
    ..add(
      MotionPart(
        'torso',
        const P(0, hipY),
        neckBase,
        0,
        0,
        poly: [
          P(-16, hipY - 4),
          P(-14.5, 112),
          P(-17, 128),
          P(-21, shY + shrug - 1),
          P(-12, shY + shrug + 5),
          P(12, shY + shrug + 5),
          P(21, shY + shrug - 1),
          P(17, 128),
          P(14.5, 112),
          P(16, hipY - 4),
        ],
      ),
    )
    ..add(MotionPart('neck', neckBase, head, 5.0, 4.6))
    ..add(MotionPart('head', head, head, Body.head, Body.head));
  for (final (s, k) in [('L', -1.0), ('R', 1.0)]) {
    final sh = P(19 * k, shY + shrug);
    final a = v['abd'] ?? 10, e = v['el'] ?? 0;
    P limb(double deg) => P(math.sin(_rad(deg)) * k, -math.cos(_rad(deg)));
    final elbow = sh + limb(a) * Body.upperArm;
    final wrist = elbow + limb(a + e) * Body.forearm;
    final fist = wrist + limb(a + e) * (Body.hand * .6);
    joints['shoulder$s'] = sh;
    joints['elbow$s'] = elbow;
    joints['wrist$s'] = wrist;
    joints['fist$s'] = fist;
    parts
      ..add(MotionPart('uarm$s', sh, elbow, 5.4, 4.2))
      ..add(MotionPart('farm$s', elbow, wrist, 4.1, 3.1))
      ..add(MotionPart('hand$s', wrist, fist, 3.4, 3.4));
  }
  return (parts, joints);
}
