/// 自重动作的进阶阶梯：做满次数上限、动作稳、还有余力，才换成更难的一级。
///
/// 阶梯存放在计划的 `ladders` 里（和俯卧撑阶梯同一套机制，见 plan.dart 的 resolveEx）。
/// 每一级的 name 都优先选动作库里已经有示范和要点的动作；没有示范的级别用
/// 「同一动作 + 停顿 / 放慢 / 垫高」，并在 guide.dart 的 NAME_MAP 里指向同一份示范。
library;

import 'format.dart';

/// 一条阶梯的预设。`start` 是新建模板时现有动作所在的级别。
typedef LadderPreset = ({
  String id,
  String label,
  int start,
  List<Map<String, Object>> steps,
});

const List<LadderPreset> ladderPresets = [
  (
    id: 'squat',
    label: '深蹲',
    start: 0,
    steps: [
      {
        'name': '深蹲',
        'min': 10,
        'max': 15,
        'side': false,
        'gear': '徒手',
        'tip': '站距略宽于肩，蹲到大腿接近水平，膝盖跟着脚尖方向。',
        'hint': '连续两次做满 15 次、动作稳、还有余力就升级',
      },
      {
        'name': '停顿深蹲',
        'min': 8,
        'max': 12,
        'side': false,
        'gear': '徒手',
        'tip': '蹲到最低点停 2 秒再站起，不要靠弹起来借力。',
        'hint': '连续两次做满 12 次、动作稳、还有余力就升级',
      },
      {
        'name': '分腿蹲',
        'min': 8,
        'max': 12,
        'side': true,
        'gear': '徒手，旁边有墙或椅背可以扶',
        'tip': '一脚在前一脚在后，身体垂直往下蹲，前脚踩实，每侧做完为一组。',
        'hint': '连续两次每侧做满 12 次、站得稳就升级',
      },
      {
        'name': '保加利亚分腿蹲',
        'min': 8,
        'max': 12,
        'side': true,
        'gear': '徒手，后脚搭在稳固的椅子或沙发上',
        'tip': '后脚搭在稳固的椅面上，重心放前脚，前膝不要往里塌；每侧做完为一组。',
        'hint': '连续两次每侧做满 12 次、站得稳就升级',
        'upBody': '动作标准的话，换更难的「保加利亚分腿蹲」。后脚要搭在一把稳固的椅子或沙发上，不稳就先继续练分腿蹲。',
      },
      {
        'name': '慢速保加利亚分腿蹲',
        'min': 6,
        'max': 10,
        'side': true,
        'gear': '徒手，后脚搭在稳固的椅子或沙发上',
        'tip': '同样的动作，用 3 秒慢慢蹲下去，最低点不要弹起；每侧做完为一组。',
        'hint': '已经是这条阶梯最难的一级：做满后可以背上装了书的背包加重',
      },
    ],
  ),
  (
    id: 'row',
    label: '反向划船',
    start: 1,
    steps: [
      {
        'name': '高角度反向划船',
        'min': 8,
        'max': 12,
        'side': false,
        'gear': '稳固且能承重、不翻倒的桌子',
        'tip': '脚靠近桌子、身体更直立，更省力；握稳桌沿，把胸拉向桌边。',
        'hint': '连续两次做满 12 次、动作不甩就升级',
      },
      {
        'name': '反向划船',
        'min': 8,
        'max': 12,
        'side': false,
        'gear': '稳固且能承重、不翻倒的桌子',
        'tip': '身体放平成一条直线，先收紧肩胛再拉，胸口贴近桌边；桌子晃就不要做。',
        'hint': '连续两次做满 12 次、动作不甩就升级',
      },
      {
        'name': '脚垫高反向划船',
        'min': 6,
        'max': 10,
        'side': false,
        'gear': '稳固的桌子，脚下垫一把稳固的椅子',
        'tip': '脚放到稳固的椅子上，身体放得更平更难；椅子和桌子都不能滑动。',
        'upBody': '动作标准的话，换更难的「脚垫高反向划船」。脚下要垫一把稳固的椅子，桌子和椅子都不能滑动。',
        'hint': '连续两次做满 10 次、动作不甩就升级',
      },
      {
        'name': '单臂辅助反向划船',
        'min': 4,
        'max': 8,
        'side': true,
        'gear': '稳固且能承重、不翻倒的桌子',
        'tip': '主要靠一只手拉，另一只手只轻轻扶一下桌沿；两侧都练，每侧做完为一组。',
        'hint': '已经是这条阶梯最难的一级：做满后放慢下放 3 秒继续练',
      },
    ],
  ),
  (
    id: 'bridge',
    label: '臀桥',
    start: 0,
    steps: [
      {
        'name': '臀桥',
        'min': 12,
        'max': 20,
        'side': false,
        'gear': '徒手',
        'tip': '脚跟踩实，用臀部发力抬到肩、髋、膝成一条线，顶端夹紧 1 秒。',
        'hint': '连续两次做满 20 次、用臀发力就升级',
      },
      {
        'name': '停顿臀桥',
        'min': 10,
        'max': 15,
        'side': false,
        'gear': '徒手',
        'tip': '顶端停 3 秒再慢慢放下，下背不要塌，用臀发力。',
        'hint': '连续两次做满 15 次、用臀发力就升级',
      },
      {
        'name': '单腿臀桥',
        'min': 8,
        'max': 12,
        'side': true,
        'gear': '垫子',
        'tip': '一只脚踩地、另一条腿抬起，骨盆保持水平不要歪；每侧做完为一组。',
        'hint': '连续两次每侧做满 12 次、骨盆不歪就升级',
      },
      {
        'name': '肩垫高单腿臀桥',
        'min': 6,
        'max': 10,
        'side': true,
        'gear': '垫子，肩背靠在稳固的沙发或椅子边',
        'tip': '肩背靠在稳固的沙发边，幅度比地面更大，顶端夹紧；每侧做完为一组。',
        'hint': '已经是这条阶梯最难的一级：做满后放慢下放 3 秒继续练',
        'upBody': '动作标准的话，换更难的「肩垫高单腿臀桥」。肩背要靠在一件稳固、不会滑动的沙发或椅子上。',
      },
    ],
  ),
  (
    id: 'core',
    label: '腹肌',
    start: 1,
    steps: [
      {
        'name': '卷腹',
        'min': 10,
        'max': 15,
        'side': false,
        'gear': '徒手',
        'tip': '下巴微收，用腹部把肩胛卷离地面，不要用手拉脖子。',
        'hint': '连续两次做满 15 次、动作不扯脖子就升级',
      },
      {
        'name': '反向卷腹',
        'min': 10,
        'max': 15,
        'side': false,
        'gear': '徒手',
        'tip': '用腹部把膝盖卷向胸口，臀部离地一点点就好，不要靠甩腿。',
        'hint': '连续两次做满 15 次、不甩腿就升级',
      },
      {
        'name': '悬垂屈膝举腿',
        'min': 6,
        'max': 10,
        'side': false,
        'gear': '稳固的单杠',
        'tip': '双手握杠悬垂，屈膝把膝盖抬到腰的高度，身体不要晃。',
        'upBody': '动作标准的话，换更难的「悬垂屈膝举腿」。这一级要用稳固的单杠悬垂；没有单杠就先保持反向卷腹，把下放放慢。',
        'hint': '连续两次做满 10 次、身体不晃就升级',
      },
      {
        'name': '悬垂举腿',
        'min': 4,
        'max': 8,
        'side': false,
        'gear': '稳固的单杠',
        'tip': '腿伸直（可微屈膝）抬到接近水平，慢慢放下，不要荡。',
        'hint': '已经是这条阶梯最难的一级：做满后放慢下放 3 秒继续练',
      },
    ],
  ),
];

LadderPreset? ladderPreset(String id) {
  for (final p in ladderPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// 一份新的阶梯 JSON，可直接放进 plan['ladders']。
Map<String, dynamic> buildLadder(String id, [int? stage]) {
  final p = ladderPreset(id)!;
  return <String, dynamic>{
    'label': p.label,
    'stage': stage ?? p.start,
    'steps': [
      for (final s in p.steps) <String, dynamic>{...s},
    ],
  };
}

/// 阶梯在计划编辑页里的名字。
String ladderLabel(String id, Object? ladder) {
  final label = jsonMap(ladder)['label'];
  if (label is String && label.isNotEmpty) return label;
  return id == 'pushup' ? '俯卧撑' : (ladderPreset(id)?.label ?? id);
}

/// 老计划里没有阶梯的动作：它正好是某条预设阶梯的第几级？返回 (阶梯 id, 级别)。
/// 只认徒手、按次数计、没有被临时换动作的动作；加了重量或器械的不算。
({String id, int stage})? ladderMatch(Map<String, dynamic> ex) {
  if (jsTruthy(ex['ladder']) ||
      jsTruthy(ex['swapped']) ||
      jsTruthy(ex['machine']) ||
      jsNumber(ex['weight']) > 0 ||
      ex['unit'] == 'sec') {
    return null;
  }
  for (final p in ladderPresets) {
    for (final (i, s) in p.steps.indexed) {
      if (s['name'] == ex['name']) return (id: p.id, stage: i);
    }
  }
  return null;
}
