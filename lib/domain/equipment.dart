// 健身房器械库：站在器械前能按“看到的东西”找到动作、恢复状态和标准做法。
// 动作名一律用记录里的规范名（records.defaultEx / movements 里的名字），
// 这样肌肉恢复、示范图和历史记录都能对上。
import 'movements.dart' show MUSCLE, musclesOf;
import 'records.dart' show defaultEx;

class Equipment {
  const Equipment({
    required this.id,
    required this.name,
    required this.kind,
    required this.exercises,
    this.aliases = const [],
    this.demo,
    this.setup = const [],
  });

  final String id, name, kind;

  /// 这台器械能做的动作（规范名），按最常用排在前面。
  final List<String> exercises;

  /// 健身房里的俗称、英文名、品牌叫法，只用于搜索。
  final List<String> aliases;

  /// 用作缩略图的示范 key（guide.dart 的 LIB），没有就显示图标。
  final String? demo;

  /// 上器械前的调节要点：座椅、握把、滑轮、起始重量。
  final List<String> setup;
}

/// 分组顺序即器械页的分区顺序。
const equipmentKinds = ['固定器械', '龙门架与杆', '自由重量', '有氧'];

const equipmentList = <Equipment>[
  Equipment(
    id: 'chest-press',
    name: '坐姿推胸机',
    kind: '固定器械',
    exercises: ['坐姿推胸机'],
    aliases: ['推胸机', '器械推胸', '胸推机', 'chest press'],
    demo: 'machine-chest-press',
    setup: ['调座椅，让握把对准胸口中部', '背和后脑贴紧靠垫，肩胛向后下收', '推到手臂接近伸直，不要锁死手肘'],
  ),
  Equipment(
    id: 'incline-press',
    name: '上斜推胸机',
    kind: '固定器械',
    exercises: ['上斜推胸机'],
    aliases: ['上斜推胸', '上胸推胸机', 'incline press'],
    demo: 'machine-incline-press',
    setup: ['调座椅，让握把对准锁骨下方', '推的方向斜向上，肩膀不要往前耸', '先用轻重量找到上胸发力的感觉'],
  ),
  Equipment(
    id: 'pec-deck',
    name: '蝴蝶机',
    kind: '固定器械',
    exercises: ['蝴蝶机夹胸', '反向蝴蝶机'],
    aliases: ['夹胸机', '飞鸟机', '反向飞鸟机', '后束飞鸟', 'pec deck', 'rear delt fly'],
    demo: 'butterfly',
    setup: [
      '调座椅，让手臂抬起时与肩同高',
      '夹胸：背贴靠垫，手肘微屈，像抱大树一样合拢',
      '练后束：面朝靠垫坐，把手调到最前，向两侧打开',
    ],
  ),
  Equipment(
    id: 'shoulder-press',
    name: '坐姿肩推机',
    kind: '固定器械',
    exercises: ['坐姿肩推机'],
    aliases: ['推肩机', '器械推肩', '肩推机', 'shoulder press'],
    demo: 'machine-shoulder-press',
    setup: ['调座椅，让握把起始位置在肩膀高度', '腰背贴紧靠垫，不要拱腰借力', '推到手臂接近伸直，慢慢放回耳朵高度'],
  ),
  Equipment(
    id: 'lat-pulldown',
    name: '高位下拉机',
    kind: '固定器械',
    exercises: ['高位下拉'],
    aliases: ['下拉机', '高拉机', '背阔下拉', 'lat pulldown'],
    demo: 'lat-pulldown',
    setup: ['调大腿压垫，坐下后刚好压紧大腿', '握距略宽于肩，身体微微后仰', '把杆拉到上胸，想象用手肘往下拉'],
  ),
  Equipment(
    id: 'seated-row',
    name: '坐姿划船机',
    kind: '固定器械',
    exercises: ['坐姿划船'],
    aliases: ['低位划船', '坐姿拉背', '器械划船', 'seated row'],
    demo: 'seated-row',
    setup: ['调座椅或胸垫，让握把与胸口下沿同高', '脚踩稳踏板，膝盖微屈', '拉向腹部时肩胛往后夹，回放时手臂伸直但不耸肩'],
  ),
  Equipment(
    id: 'assisted-pullup',
    name: '辅助引体向上机',
    kind: '固定器械',
    exercises: ['辅助引体向上机'],
    aliases: ['助力引体', '辅助引体', '跪姿引体', '引体助力机', 'assisted pull up'],
    demo: 'assisted-pullup',
    setup: ['配重越重，辅助越多、越轻松', '膝盖跪稳在踏板上再松手', '下放到手臂接近伸直，不要甩身体'],
  ),
  Equipment(
    id: 'leg-press',
    name: '腿举机',
    kind: '固定器械',
    exercises: ['腿举'],
    aliases: ['倒蹬', '蹬腿机', '45度腿举', '斜蹬', 'leg press'],
    demo: 'leg-press',
    setup: ['脚踩踏板中部，与肩同宽', '下放到膝盖约 90°，腰和臀不要离开靠垫', '推起时膝盖不要锁死；先确认安全锁扣会用'],
  ),
  Equipment(
    id: 'hack-squat',
    name: '哈克深蹲机',
    kind: '固定器械',
    exercises: ['哈克深蹲'],
    aliases: ['哈克', '哈克机', 'hack squat'],
    setup: ['肩膀顶住肩垫，背贴靠板', '脚放在踏板中部、与肩同宽', '蹲到大腿约水平再站起，膝盖跟脚尖方向一致'],
  ),
  Equipment(
    id: 'smith',
    name: '史密斯机',
    kind: '固定器械',
    exercises: ['史密斯深蹲', '史密斯卧推'],
    aliases: ['史密斯', '史密斯架', 'smith machine', 'smith'],
    setup: ['杠铃沿固定轨道走，先找到挂钩位置，旋转手腕即可挂上', '开始前把安全挡块调到略低于最低位置', '深蹲时脚可稍微站在杠铃前方'],
  ),
  Equipment(
    id: 'leg-extension',
    name: '腿屈伸机',
    kind: '固定器械',
    exercises: ['腿屈伸'],
    aliases: ['坐姿踢腿', '腿伸展', '股四头机', 'leg extension'],
    demo: 'leg-extension',
    setup: ['调靠背，让膝盖对准器械转轴', '脚踝垫压在脚背上方', '抬到腿接近伸直，停一下再慢慢放下'],
  ),
  Equipment(
    id: 'leg-curl',
    name: '腿弯举机',
    kind: '固定器械',
    exercises: ['腿弯举'],
    aliases: ['坐姿腿弯举', '俯卧腿弯举', '勾腿', '腘绳机', 'leg curl'],
    demo: 'leg-curl',
    setup: ['调靠背，让膝盖对准器械转轴', '脚踝垫在跟腱上方', '勾腿到底停一下，臀部不要离开座椅'],
  ),
  Equipment(
    id: 'hip-machine',
    name: '髋外展 / 内收机',
    kind: '固定器械',
    exercises: ['髋外展机', '髋内收机'],
    aliases: ['夹腿机', '开腿机', '外展机', '内收机', '臀中肌', 'hip abduction', 'hip adduction'],
    setup: ['外展：腿垫在膝盖外侧，向外打开', '内收：腿垫在膝盖内侧，向内夹紧', '先调起始角度，开合幅度以不疼为准'],
  ),
  Equipment(
    id: 'calf-machine',
    name: '提踵机',
    kind: '固定器械',
    exercises: ['坐姿提踵机', '提踵'],
    aliases: ['坐姿提踵', '站姿提踵机', '小腿机', 'calf raise'],
    demo: 'seated-calf',
    setup: ['前脚掌踩在踏板边缘，脚跟悬空', '膝垫压在大腿靠近膝盖处', '脚跟放到最低拉伸，再踮到最高停一下'],
  ),
  Equipment(
    id: 'ab-machine',
    name: '卷腹机',
    kind: '固定器械',
    exercises: ['卷腹机'],
    aliases: ['腹肌机', 'ab crunch'],
    demo: 'ab-machine',
    setup: ['调座椅，让胸垫或把手位于胸前', '用腹部把上身往下卷，不要用手臂拉', '重量宁轻勿重，慢慢回到起始'],
  ),
  Equipment(
    id: 'roman-chair',
    name: '罗马椅',
    kind: '固定器械',
    exercises: ['背部伸展'],
    aliases: ['山羊挺身', '背伸展', '挺身架', 'hyperextension', 'roman chair'],
    demo: 'back-extension',
    setup: ['调腿垫高度，让髋部刚好在垫子边缘外', '身体从髋部折叠向下', '起身到身体成直线即可，不要过度后仰'],
  ),
  Equipment(
    id: 'curl-machine',
    name: '二头弯举机',
    kind: '固定器械',
    exercises: ['二头弯举机'],
    aliases: ['弯举机', '牧师凳', '器械弯举', 'preacher curl', 'biceps curl machine'],
    demo: 'machine-curl',
    setup: ['调座椅，让上臂完整贴在斜垫上', '手肘对准器械转轴', '弯举到顶停一下，下放到手臂接近伸直'],
  ),
  Equipment(
    id: 'dip-machine',
    name: '坐姿臂屈伸机',
    kind: '固定器械',
    exercises: ['坐姿臂屈伸机'],
    aliases: ['器械臂屈伸', '三头机', '坐姿下压机', 'dip machine', 'triceps machine'],
    setup: ['调座椅，让握把在身体两侧', '上身挺直，手肘贴近身体', '往下压到手臂伸直，回放时不要耸肩'],
  ),
  Equipment(
    id: 'cable',
    name: '龙门架 / 拉力器',
    kind: '龙门架与杆',
    exercises: ['龙门架夹胸', '绳索下压', '绳索面拉', '直臂下拉', '拉力器单臂侧平举', '绳索卷腹', '绳索弯举'],
    aliases: ['龙门架', '拉力器', '绳索', '大飞鸟', '十字架', '滑轮', 'cable', 'cable crossover'],
    demo: 'cable-crossover',
    setup: [
      '按动作调滑轮高度：夹胸、下压、面拉、直臂下拉用高位，侧平举、弯举用低位',
      '按动作换手柄：下压和面拉用绳索，直臂下拉用直杆',
      '先站稳再发力，回放时别让配重片撞在一起',
    ],
  ),
  Equipment(
    id: 'pullup-bar',
    name: '单杠 / 双杠',
    kind: '龙门架与杆',
    exercises: ['引体向上', '双杠臂屈伸', '悬垂举腿'],
    aliases: ['单杠', '双杠', '引体架', '举腿架', '悬垂架', 'pull up bar', 'dip station'],
    demo: 'pullup',
    setup: ['做不了完整引体时，先用辅助引体向上机', '双杠臂屈伸身体微微前倾练胸，直立更多练三头', '悬垂举腿时肩膀收紧，不要晃'],
  ),
  Equipment(
    id: 'barbell',
    name: '杠铃 / 力量架',
    kind: '自由重量',
    exercises: ['卧推', '深蹲', '硬拉', '杠铃划船', '杠铃推举', '上斜卧推', '杠铃弯举', '臀推'],
    aliases: ['杠铃', '卧推架', '深蹲架', '力量架', '框架', 'barbell', 'power rack', 'squat rack'],
    demo: 'deadlift',
    setup: ['卧推、深蹲先把安全杠调到略低于最低位置', '空杆通常是 20 kg，两边加片要对称并上好卡扣', '新动作先用空杆练熟动作再加重'],
  ),
  Equipment(
    id: 'dumbbell',
    name: '哑铃',
    kind: '自由重量',
    exercises: ['哑铃卧推', '哑铃上斜卧推', '哑铃推举', '侧平举', '单臂哑铃划船', '哑铃弯举', '锤式弯举', '过头臂屈伸', '罗马尼亚硬拉', '俯身哑铃反向飞鸟', '高脚杯深蹲', '提踵'],
    aliases: ['哑铃架', 'dumbbell', 'db'],
    demo: 'db-curl',
    setup: ['从哑铃架取放时屈膝，背保持挺直', '卧推类动作先坐在凳上把哑铃放在大腿上，再顺势躺下', '记录时按单只哑铃的重量填'],
  ),
  Equipment(
    id: 'bench',
    name: '训练凳',
    kind: '自由重量',
    exercises: ['哑铃卧推', '哑铃上斜卧推', '单臂哑铃划船', '保加利亚分腿蹲'],
    aliases: ['平凳', '上斜凳', '可调凳', '卧推凳', 'bench'],
    demo: 'db-bench',
    setup: ['上斜卧推把靠背调到 30°–45°', '确认插销卡到位再坐上去', '单臂划船时一侧手和膝撑在凳上'],
  ),
  Equipment(
    id: 'tbar',
    name: 'T 杠 / 地雷架',
    kind: '自由重量',
    exercises: ['T杠划船'],
    aliases: ['T杠', '地雷架', 'landmine', 't-bar row'],
    setup: ['杠一端固定在地雷架里，另一端加片', '髋部折叠、背挺直，把杠拉向腹部', '重量从一片开始加'],
  ),
  Equipment(
    id: 'kettlebell',
    name: '壶铃',
    kind: '自由重量',
    exercises: ['壶铃摆荡', '高脚杯深蹲'],
    aliases: ['kettlebell', 'kb'],
    demo: 'goblet-squat',
    setup: ['摆荡靠髋部前送发力，不是用手臂抬', '先用轻壶铃练熟节奏', '周围留出足够空间'],
  ),
  Equipment(
    id: 'ab-wheel',
    name: '健腹轮',
    kind: '自由重量',
    exercises: ['健腹轮'],
    aliases: ['腹肌轮', '滚轮', 'ab wheel'],
    setup: ['先跪姿做，膝下垫毛巾', '推出去时收紧腹部，腰不要塌', '能控制住的距离再往回收'],
  ),
  Equipment(
    id: 'cardio',
    name: '有氧器械',
    kind: '有氧',
    exercises: ['跑步机', '椭圆机', '划船机', '单车'],
    aliases: ['跑步机', '椭圆机', '动感单车', '单车', '划船机', 'treadmill', 'elliptical', 'bike', 'rower'],
    setup: ['开始前夹好安全夹或确认急停按钮', '先慢速热身 3–5 分钟', '有氧不计入肌肉恢复'],
  ),
];

final equipmentById = {for (final e in equipmentList) e.id: e};

/// 动作的俗称 → 规范名。只收录明确是同一个动作的叫法。
const exerciseAliases = <String, String>{
  '大飞鸟': '龙门架夹胸',
  '绳索夹胸': '龙门架夹胸',
  '拉力器夹胸': '龙门架夹胸',
  '倒蹬': '腿举',
  '腿举机': '腿举',
  '坐姿划船机': '坐姿划船',
  '腿屈伸机': '腿屈伸',
  '坐姿腿弯举': '腿弯举',
  '山羊挺身': '背部伸展',
  '器械推肩': '坐姿肩推机',
  '辅助引体': '辅助引体向上机',
  '绳索侧平举': '拉力器单臂侧平举',
  '面拉': '绳索面拉',
  '平板卧推': '卧推',
  '杠铃卧推': '卧推',
  '杠铃深蹲': '深蹲',
  'rdl': '罗马尼亚硬拉',
};

/// 这个动作可以在哪些器械上做。
List<Equipment> equipmentFor(String exercise) {
  final name = exerciseAliases[exercise] ?? exercise;
  return [
    for (final e in equipmentList)
      if (e.exercises.contains(name)) e,
  ];
}

const _groupPart = {
  'chest': '胸',
  'back': '背',
  'shoulders': '肩',
  'arms': '手臂',
  'abs': '核心',
  'quads': '腿',
  'hamstrings': '腿',
  'glutes': '腿',
  'calves': '腿',
};

/// 动作在记录里归到哪个部位：优先用常用列表，其次按主练肌肉推断。
String partOfExercise(String exercise) {
  for (final e in defaultEx.entries) {
    if (e.value.contains(exercise)) return e.key;
  }
  final mv = musclesOf(exercise);
  if (mv == null) return '有氧';
  return _groupPart[MUSCLE[mv['primary']]!['group']] ?? '全身';
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\-_/·]+'), '');

/// 一个搜索结果：动作规范名、部位，以及通过哪台器械或俗称找到的（直接命中则为空）。
typedef ExerciseHit = ({String name, String part, String via});

/// 全部位搜索：动作名、动作俗称、器械名和器械俗称都能搜到。
/// [extra] 是用户自己记过的动作名（自定义动作也要能搜到）；
/// [translate] 用于按当前界面语言的名字匹配。
List<ExerciseHit> searchExercises(
  String query, {
  Iterable<String> extra = const [],
  String Function(String)? translate,
}) {
  final q = _norm(query);
  if (q.isEmpty) return const [];
  bool hit(String s) =>
      _norm(s).contains(q) ||
      (translate != null && _norm(translate(s)).contains(q));
  final out = <String, ExerciseHit>{};
  void add(String name, String via) {
    out.putIfAbsent(
      name,
      () => (name: name, part: partOfExercise(name), via: via),
    );
  }

  final pool = <String>{
    for (final list in defaultEx.values) ...list,
    for (final e in equipmentList) ...e.exercises,
    ...extra,
  };
  for (final name in pool) {
    if (hit(name)) add(name, '');
  }
  for (final a in exerciseAliases.entries) {
    if (hit(a.key)) add(a.value, a.key);
  }
  for (final e in equipmentList) {
    if (hit(e.name) || e.aliases.any(hit)) {
      for (final name in e.exercises) {
        add(name, e.name);
      }
    }
  }
  return out.values.toList();
}

/// 器械搜索：名字或俗称包含关键字即可。
List<Equipment> searchEquipment(
  String query, {
  String Function(String)? translate,
}) {
  final q = _norm(query);
  if (q.isEmpty) return equipmentList;
  bool hit(String s) =>
      _norm(s).contains(q) ||
      (translate != null && _norm(translate(s)).contains(q));
  return [
    for (final e in equipmentList)
      if (hit(e.name) || e.aliases.any(hit) || e.exercises.any(hit)) e,
  ];
}
