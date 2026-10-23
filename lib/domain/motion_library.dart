/// 矢量动作示范的数据。每个动作：几帧关键姿势 + 节奏 + 发力肌肉 + 教学辅助线。
/// 姿势参数的含义见 motion.dart 里 `_side` / `_front` 的注释；数值按 175 cm 身材推算。
library;

import 'motion.dart';

/// 阶段名会显示在示范左下角。
const phaseStart = '起始', phaseDown = '下放', phaseHold = '停顿';
const phaseUp = '发力', phaseTop = '顶峰';

/// 深蹲（侧面）：下放 2 秒，底部停 0.3 秒，1.2 秒站起。
/// 底部：小腿前倾约 35°，大腿接近水平，躯干前倾约 40°，重心落在脚掌中部；手臂前平举配重。
const _squatStand = {'hipX': 0.0, 'hipY': 93.0, 'torso': 4.0, 'neck': 2.0};
const _squatBottom = {
  'hipX': -18.5,
  'hipY': 51.0,
  'torso': 40.0,
  'neck': -26.0,
  'sh': 88.0,
  'el': 4.0,
};
const squatMotion = MotionSpec(
  view: MotionView.side,
  base: {..._squatStand, 'ankX': 0, 'ankY': 8, 'foot': 0, 'sh': 10, 'el': 14},
  keys: [
    MotionKey(0, {}, .15, phaseStart),
    MotionKey(.5, {}, .55, phaseDown),
    MotionKey(2.5, _squatBottom, .8, phaseHold),
    MotionKey(2.8, _squatBottom, 1, phaseUp),
    MotionKey(4.0),
  ],
  marks: [
    MotionMark('thighF', from: .12, to: .9, off: .45, width: .7),
    MotionMark('thighN', from: .12, to: .9, off: .45, width: .7),
    MotionMark('torso', from: -.08, to: .2, off: .55, width: .85, weight: .9),
  ],
  guides: [MotionGuide.level(47, -42, 42)],
  bounds: [-62, -4, 80, 184],
);

/// 俯卧撑（侧面）：以脚尖为支点整块下降，肩—髋—踝一条线；1.8 秒下放，1.2 秒推起。
/// 顶端：手在肩正下方、手臂接近伸直；底部：肩离地约 22 cm（胸口贴近地面），肘朝后上方。
const _pushTop = {'lean': 15.7};
const _pushBottom = {'lean': .85};
const pushupMotion = MotionSpec(
  view: MotionView.side,
  base: {
    ..._pushTop,
    'neck': 6,
    'ankX': -4,
    'ankY': 20,
    'foot': -75,
    'handX': 128,
    'handY': 4,
    'hand': 0,
  },
  keys: [
    MotionKey(0, {}, .2, phaseStart),
    MotionKey(.3, {}, .6, phaseDown),
    MotionKey(2.1, _pushBottom, .85, phaseHold),
    MotionKey(2.4, _pushBottom, 1, phaseUp),
    MotionKey(3.6),
  ],
  marks: [
    MotionMark('torso', from: .6, to: .95, off: -.5, width: .62),
    MotionMark('uarmN', from: .0, to: .32, off: .35, width: .85, weight: .7),
    MotionMark('uarmF', from: .2, to: .88, off: -.45, width: .7, weight: .8),
    MotionMark('uarmN', from: .2, to: .88, off: -.45, width: .7, weight: .85),
  ],
  guides: [MotionGuide.joints('ankle', 'shoulder', lift: 17)],
  bounds: [-22, -4, 156, 92],
);

/// 哑铃侧平举（正面）：1.2 秒抬到与肩同高，顶端停 0.4 秒，2 秒慢慢放下；肘微屈，不耸肩。
const lateralRaiseMotion = MotionSpec(
  view: MotionView.front,
  base: {'abd': 12, 'el': 8, 'shrug': 0, 'stance': 13},
  keys: [
    MotionKey(0, {}, .15, phaseStart),
    MotionKey(.4, {}, .9, phaseUp),
    MotionKey(1.6, {'abd': 84, 'el': 6}, 1, phaseTop),
    MotionKey(2.0, {'abd': 84, 'el': 6}, .6, phaseDown),
    MotionKey(4.0),
  ],
  marks: [
    MotionMark('uarmL', from: -.12, to: .4, off: -.2, width: 1.05),
    MotionMark('uarmR', from: -.12, to: .4, off: .2, width: 1.05),
  ],
  guides: [MotionGuide.level(145, -92, 92)],
  props: [MotionProp.dumbbellEnd('fistL'), MotionProp.dumbbellEnd('fistR')],
  bounds: [-96, -4, 96, 184],
);

/// 动作要点库的 key → 矢量示范。没有的动作继续用照片。
const motionLibrary = <String, MotionSpec>{
  'squat': squatMotion,
  'pushup': pushupMotion,
  'lateral-raise': lateralRaiseMotion,
};
