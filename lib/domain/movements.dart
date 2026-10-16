// Tables transcribed from reference/web-src/movements.js.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
const MUSCLES = [
  {'id': 'chest_up', 'name': '上胸', 'group': 'chest'},
  {'id': 'chest', 'name': '中下胸', 'group': 'chest'},
  {'id': 'delt_front', 'name': '前束肩', 'group': 'shoulders'},
  {'id': 'delt_side', 'name': '中束肩', 'group': 'shoulders'},
  {'id': 'delt_rear', 'name': '后束肩', 'group': 'shoulders'},
  {'id': 'biceps', 'name': '肱二头肌', 'group': 'arms'},
  {'id': 'triceps', 'name': '肱三头肌', 'group': 'arms'},
  {'id': 'abs', 'name': '腹直肌', 'group': 'abs'},
  {'id': 'obliques', 'name': '腹斜肌', 'group': 'abs'},
  {'id': 'lats', 'name': '背阔肌', 'group': 'back'},
  {'id': 'mid_back', 'name': '中背', 'group': 'back'},
  {'id': 'lower_back', 'name': '下背', 'group': 'back'},
  {'id': 'quads', 'name': '股四头肌', 'group': 'quads'},
  {'id': 'hamstrings', 'name': '腘绳肌', 'group': 'hamstrings'},
  {'id': 'glutes', 'name': '臀大肌', 'group': 'glutes'},
  {'id': 'calves', 'name': '小腿', 'group': 'calves'},
];
const GROUPS = [
  {'id': 'chest', 'name': '胸'},
  {'id': 'back', 'name': '背'},
  {'id': 'shoulders', 'name': '肩'},
  {'id': 'arms', 'name': '手臂'},
  {'id': 'abs', 'name': '腹'},
  {'id': 'quads', 'name': '股四头'},
  {'id': 'hamstrings', 'name': '腘绳'},
  {'id': 'glutes', 'name': '臀'},
  {'id': 'calves', 'name': '小腿'},
];
final MUSCLE = {for (final m in MUSCLES) m['id']!: m};
final GROUP = {for (final g in GROUPS) g['id']!: g};
const _table = [
  [
    ['高位俯卧撑', '低台面俯卧撑', '跪姿俯卧撑', '标准俯卧撑', '俯卧撑'],
    {'chest': 1, 'chest_up': 0.25, 'delt_front': 0.5, 'triceps': 0.5},
    'bw',
  ],
  [
    ['弹力带胸推'],
    {'chest': 1, 'chest_up': 0.3, 'delt_front': 0.5, 'triceps': 0.5},
    'band',
  ],
  [
    ['哑铃地板卧推', '哑铃平板卧推', '哑铃卧推', '卧推'],
    {'chest': 1, 'chest_up': 0.4, 'delt_front': 0.5, 'triceps': 0.6},
    'free',
  ],
  [
    ['坐姿推胸机'],
    {'chest': 1, 'chest_up': 0.3, 'delt_front': 0.4, 'triceps': 0.5},
    'machine',
  ],
  [
    ['上斜推胸机'],
    {'chest_up': 1, 'chest': 0.5, 'delt_front': 0.6, 'triceps': 0.5},
    'machine',
  ],
  [
    ['上斜哑铃卧推', '哑铃上斜卧推', '上斜卧推'],
    {'chest_up': 1, 'chest': 0.5, 'delt_front': 0.6, 'triceps': 0.5},
    'free',
  ],
  [
    ['拉力器高位向下夹胸', '龙门架夹胸'],
    {'chest': 1, 'chest_up': 0.15, 'delt_front': 0.3},
    'machine',
  ],
  [
    ['蝴蝶机夹胸'],
    {'chest': 1, 'chest_up': 0.3, 'delt_front': 0.3},
    'machine',
  ],
  [
    ['双杠臂屈伸'],
    {'chest': 1, 'triceps': 0.8, 'delt_front': 0.5},
    'bw',
  ],
  [
    ['脚抬高俯卧撑'],
    {'chest_up': 1, 'chest': 0.7, 'delt_front': 0.6, 'triceps': 0.5},
    'bw',
  ],
  [
    ['弹力带夹胸'],
    {'chest': 1, 'chest_up': 0.3, 'delt_front': 0.3},
    'band',
  ],

  [
    ['哑铃肩推', '轻哑铃坐姿肩推', '哑铃推举', '杠铃推举'],
    {'delt_front': 1, 'delt_side': 0.6, 'triceps': 0.5, 'chest_up': 0.2},
    'free',
  ],
  [
    ['坐姿肩推机', '器械推肩'],
    {'delt_front': 1, 'delt_side': 0.6, 'triceps': 0.5, 'chest_up': 0.2},
    'machine',
  ],
  [
    ['轻重量侧平举', '轻哑铃侧平举', '侧平举'],
    {'delt_side': 1, 'delt_rear': 0.2, 'delt_front': 0.1},
    'free',
  ],
  [
    ['拉力器单臂侧平举'],
    {'delt_side': 1, 'delt_rear': 0.2, 'delt_front': 0.1},
    'machine',
  ],
  [
    ['前平举'],
    {'delt_front': 1, 'delt_side': 0.3, 'chest_up': 0.3},
    'free',
  ],
  [
    ['反向飞鸟', '面拉', '俯身哑铃反向飞鸟', '绳索面拉'],
    {'delt_rear': 1, 'mid_back': 0.6, 'delt_side': 0.2},
    'free',
  ],
  [
    ['反向蝴蝶机'],
    {'delt_rear': 1, 'mid_back': 0.6, 'delt_side': 0.2},
    'machine',
  ],
  [
    ['弹力带拉开'],
    {'delt_rear': 1, 'mid_back': 0.8, 'delt_side': 0.2},
    'band',
  ],

  [
    ['单臂哑铃划船'],
    {
      'lats': 1,
      'mid_back': 0.7,
      'delt_rear': 0.5,
      'biceps': 0.5,
      'lower_back': 0.2,
    },
    'free',
  ],
  [
    ['杠铃划船', 'T杠划船'],
    {
      'lats': 1,
      'mid_back': 0.8,
      'delt_rear': 0.5,
      'biceps': 0.5,
      'lower_back': 0.4,
    },
    'free',
  ],
  [
    ['弯腰双臂哑铃划船'],
    {
      'mid_back': 1,
      'lats': 0.7,
      'delt_rear': 0.5,
      'biceps': 0.5,
      'lower_back': 0.4,
    },
    'free',
  ],
  [
    ['坐姿划船机', '坐姿划船'],
    {'mid_back': 1, 'lats': 0.7, 'delt_rear': 0.5, 'biceps': 0.5},
    'machine',
  ],
  [
    ['高位下拉', '辅助引体向上机'],
    {'lats': 1, 'biceps': 0.6, 'mid_back': 0.4, 'delt_rear': 0.3},
    'machine',
  ],
  [
    ['引体向上'],
    {'lats': 1, 'biceps': 0.7, 'mid_back': 0.4, 'delt_rear': 0.3},
    'bw',
  ],
  [
    ['直臂下拉'],
    {'lats': 1, 'triceps': 0.2},
    'machine',
  ],
  [
    ['硬拉'],
    {
      'glutes': 1,
      'hamstrings': 0.9,
      'lower_back': 0.8,
      'quads': 0.5,
      'mid_back': 0.4,
      'lats': 0.2,
    },
    'free',
  ],

  [
    ['深蹲', '徒手深蹲'],
    {'quads': 1, 'glutes': 0.6, 'hamstrings': 0.3, 'lower_back': 0.2},
    'bw',
  ],
  [
    ['高脚杯深蹲'],
    {
      'quads': 1,
      'glutes': 0.6,
      'hamstrings': 0.3,
      'lower_back': 0.2,
      'abs': 0.15,
    },
    'free',
  ],
  [
    ['分腿蹲', '箭步蹲', '保加利亚分腿蹲'],
    {'quads': 1, 'glutes': 0.7, 'hamstrings': 0.3},
    'bw',
  ],
  [
    ['腿举机', '腿举'],
    {'quads': 1, 'glutes': 0.5, 'hamstrings': 0.2},
    'machine',
  ],
  [
    ['腿屈伸', '腿屈伸机'],
    {'quads': 1},
    'machine',
  ],
  [
    ['坐姿腿弯举', '腿弯举'],
    {'hamstrings': 1, 'calves': 0.15},
    'machine',
  ],
  [
    ['轻哑铃罗马尼亚硬拉', '罗马尼亚硬拉'],
    {'hamstrings': 1, 'glutes': 0.7, 'lower_back': 0.4},
    'free',
  ],
  [
    ['臀桥', '臀推'],
    {'glutes': 1, 'hamstrings': 0.4, 'quads': 0.15},
    'bw',
  ],
  [
    ['单腿臀桥'],
    {'glutes': 1, 'hamstrings': 0.5, 'quads': 0.1},
    'bw',
  ],
  [
    ['提踵', '站姿提踵', '坐姿提踵机'],
    {'calves': 1},
    'bw',
  ],
  [
    ['超人式'],
    {'lower_back': 1, 'glutes': 0.6, 'hamstrings': 0.3, 'delt_rear': 0.2},
    'bw',
  ],
  [
    ['背部伸展'],
    {'lower_back': 1, 'glutes': 0.5, 'hamstrings': 0.4},
    'machine',
  ],

  [
    ['哑铃弯举', '杠铃弯举', '锤式弯举'],
    {'biceps': 1},
    'free',
  ],
  [
    ['二头弯举机'],
    {'biceps': 1},
    'machine',
  ],
  [
    ['绳索下压'],
    {'triceps': 1},
    'machine',
  ],
  [
    ['仰卧臂屈伸', '过头臂屈伸', '站姿哑铃臂屈伸', '哑铃臂后屈伸'],
    {'triceps': 1},
    'free',
  ],
  [
    ['椅子臂屈伸'],
    {'triceps': 1, 'chest': 0.4, 'delt_front': 0.4},
    'bw',
  ],

  [
    ['卷腹', '卷腹机', '绳索卷腹', '反向卷腹'],
    {'abs': 1, 'obliques': 0.2},
    'bw',
  ],
  [
    ['死虫式'],
    {'abs': 1, 'obliques': 0.3},
    'bw',
  ],
  [
    ['侧平板支撑'],
    {'obliques': 1, 'abs': 0.5, 'delt_side': 0.2, 'glutes': 0.3},
    'timed',
  ],
  [
    ['平板支撑'],
    {
      'abs': 1,
      'obliques': 0.5,
      'delt_front': 0.3,
      'lower_back': 0.2,
      'glutes': 0.2,
    },
    'timed',
  ],
  [
    ['悬垂举腿'],
    {'abs': 1, 'obliques': 0.3},
    'bw',
  ],
  [
    ['健腹轮'],
    {'abs': 1, 'delt_front': 0.3, 'lats': 0.3},
    'bw',
  ],
  [
    ['俄罗斯转体'],
    {'obliques': 1, 'abs': 0.6},
    'bw',
  ],

  [
    ['壶铃摆荡'],
    {
      'glutes': 1,
      'hamstrings': 0.8,
      'lower_back': 0.5,
      'delt_front': 0.3,
      'abs': 0.3,
    },
    'free',
  ],
  [
    ['波比跳'],
    {
      'quads': 0.6,
      'chest': 0.4,
      'delt_front': 0.3,
      'triceps': 0.3,
      'abs': 0.4,
      'glutes': 0.4,
    },
    'bw',
  ],
  [
    ['农夫行走'],
    {'mid_back': 0.6, 'abs': 0.4, 'obliques': 0.4, 'glutes': 0.3},
    'free',
  ],
];
const _part = {
  '胸': {'chest': 1, 'chest_up': 0.4, 'delt_front': 0.4, 'triceps': 0.4},
  '背': {'lats': 1, 'mid_back': 0.6, 'biceps': 0.4, 'delt_rear': 0.3},
  '腿': {'quads': 1, 'glutes': 0.6, 'hamstrings': 0.4},
  '肩': {'delt_front': 0.8, 'delt_side': 0.8, 'delt_rear': 0.3},
  '手臂': {'biceps': 0.7, 'triceps': 0.7},
  '核心': {'abs': 1, 'obliques': 0.4},
  '全身': {
    'quads': 0.5,
    'glutes': 0.4,
    'abs': 0.4,
    'delt_front': 0.3,
    'mid_back': 0.3,
  },
};
const _keywords = [
  [r'俯卧撑', '高位俯卧撑'],
  [r'上斜', '上斜哑铃卧推'],
  [r'卧推|推胸', '哑铃平板卧推'],
  [r'夹胸', '蝴蝶机夹胸'],
  [r'侧平举', '轻哑铃侧平举'],
  [r'肩推|推举', '哑铃肩推'],
  [r'反向飞鸟|面拉', '反向飞鸟'],
  [r'引体|下拉', '高位下拉'],
  [r'划船', '坐姿划船机'],
  [r'硬拉', '罗马尼亚硬拉'],
  [r'深蹲', '深蹲'],
  [r'蹲', '分腿蹲'],
  [r'腿举', '腿举机'],
  [r'腿弯举', '腿弯举'],
  [r'腿屈伸', '腿屈伸'],
  [r'臀', '臀桥'],
  [r'提踵', '提踵'],
  [r'弯举', '哑铃弯举'],
  [r'下压|臂屈伸', '绳索下压'],
  [r'卷腹|仰卧起坐|举腿', '卷腹'],
  [r'支撑', '平板支撑'],
];
final _byName = <String, ({Map<String, num> mus, String kind})>{
  for (final entry in _table)
    for (final name in entry[0] as List)
      name as String: (
        mus: Map<String, num>.from(entry[1] as Map),
        kind: entry[2] as String,
      ),
};
Map<String, dynamic> _result(
  Map<String, num> mus,
  String kind,
  String matched,
) {
  var primary = mus.keys.first;
  for (final id in mus.keys) {
    if (mus[id]! > mus[primary]!) primary = id;
  }
  return {
    'muscles': mus,
    'primary': primary,
    'group': MUSCLE[primary]!['group'],
    'kind': kind,
    'matched': matched,
  };
}

Map<String, dynamic>? musclesOf(Object? name, [String? part = '']) {
  final n = (name ?? '').toString().trim();
  if (const {'跑步机', '椭圆机', '划船机', '单车'}.contains(n) || part == '有氧') {
    return null;
  }
  final hit = _byName[n];
  if (hit != null) return _result(hit.mus, hit.kind, 'exact');
  for (final k in _keywords) {
    if (RegExp(k[0]).hasMatch(n)) {
      final e = _byName[k[1]]!;
      return _result(e.mus, e.kind, 'keyword');
    }
  }
  final mus = _part[part];
  return mus == null ? null : _result(mus, 'free', 'part');
}

List<String> catalogNames() => _byName.keys.toList();
