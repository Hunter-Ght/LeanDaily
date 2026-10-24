// 3D 动作示范的数据：每个动作的姿势模式、关键帧、发力肌肉区域和机位。
// keys：[秒, 姿势, 发力程度, 阶段名]；最后一帧只标结束时间（回到第一帧）。
// glow：骨头名 → [前侧, 后侧]；spheres：[x, y, z, 半径, 强度]（绑定姿势、世界坐标、米）。
// camera：yaw 水平角、dist 距离（身高倍数）、target 注视点、fov。
// set：场景道具（长凳、杠铃杆、器械座椅……），见 scene.html 的 buildProps。
export const BASE = {
  squat: {
    mode: 'stand', arms: 'front',
    base: { drop: 0.015, back: 0, lean: 4, arm: 10, el: 14 },
    keys: [
      [0, {}, 0.15, '起始'], [0.5, {}, 0.55, '下放'],
      [2.5, { drop: 0.42, back: 0.17, lean: 40, arm: 86, el: 4 }, 0.8, '停顿'],
      [2.8, { drop: 0.42, back: 0.17, lean: 40, arm: 86, el: 4 }, 1, '发力'],
      [4.0],
    ],
    glow: { thigh_l: [1, 0.25], thigh_r: [1, 0.25], pelvis: [0, 0.95], spine_01: [0, 0.2] },
    camera: { yaw: 55, dist: 2.05, target: [0, 0.83, -0.07], fov: 28 },
  },
  pushup: {
    mode: 'prone', ankle: [0.11, -0.66], foot: -62, hand: [0.27, 0.035, 0.64],
    base: { lean: 18, neck: -6 },
    keys: [
      [0, {}, 0.2, '起始'], [0.3, {}, 0.6, '下放'],
      [2.1, { lean: 4 }, 0.85, '停顿'],
      [2.4, { lean: 4 }, 1, '发力'],
      [3.6],
    ],
    glow: { upperarm_l: [0.2, 0.85], upperarm_r: [0.2, 0.85] },
    spheres: [[0.1, 1.33, 0.09, 0.15, 1], [-0.1, 1.33, 0.09, 0.15, 1], [0.2, 1.43, 0.03, 0.09, 0.7], [-0.2, 1.43, 0.03, 0.09, 0.7]],
    camera: { yaw: 60, dist: 1.85, target: [0, 0.22, 0.28], fov: 28 },
  },
  'lateral-raise': {
    mode: 'stand', arms: 'side', props: 'dumbbells',
    base: { drop: 0.01, abd: 12, el: 10 },
    keys: [
      [0, {}, 0.15, '起始'], [0.4, {}, 0.9, '发力'],
      [1.6, { abd: 84, el: 8 }, 1, '顶峰'],
      [2.0, { abd: 84, el: 8 }, 0.6, '下放'],
      [4.0],
    ],
    glow: {},
    spheres: [[0.245, 1.42, -0.05, 0.15, 1], [-0.245, 1.42, -0.05, 0.15, 1]],
    camera: { yaw: 22, dist: 2.25, target: [0, 0.98, 0], fov: 28 },
  },
  'glute-bridge': {
    mode: 'supine', shoulder: [0.1, -0.55], feet: [0.15, 0.07, 0.42],
    base: { hip: 0.13, neck: 0, armUp: 0 },
    keys: [
      [0, {}, 0.2, '起始'], [0.4, {}, 0.9, '发力'],
      [1.4, { hip: 0.46 }, 1, '顶峰'],
      [2.4, { hip: 0.46 }, 0.6, '下放'],
      [4.0],
    ],
    glow: { pelvis: [0, 1], thigh_l: [0, 0.45], thigh_r: [0, 0.45] },
    camera: { yaw: 62, dist: 1.75, target: [0, 0.2, -0.05], fov: 28 },
  },
  // 死虫式：桌面式起始，对侧手脚慢慢伸远，回来换另一侧；下背始终贴地。
  'dead-bug': {
    mode: 'supine', shoulder: [0.1, -0.55], still: 2.1,
    base: { hip: 0.11, neck: 4, hipFlexL: 90, kneeL: 90, hipFlexR: 90, kneeR: 90, armUpL: 90, armUpR: 90 },
    keys: [
      [0, {}, 0.3, '起始'], [0.4, {}, 1, '伸展'],
      [2.0, { armUpL: 165, hipFlexR: 18, kneeR: 4 }, 0.8, '停顿'],
      [2.4, { armUpL: 165, hipFlexR: 18, kneeR: 4 }, 0.5, '收回'],
      [3.6, {}, 1, '伸展'],
      [5.2, { armUpR: 165, hipFlexL: 18, kneeL: 4 }, 0.8, '停顿'],
      [5.6, { armUpR: 165, hipFlexL: 18, kneeL: 4 }, 0.5, '收回'],
      [6.8],
    ],
    glow: { spine_01: [1, 0], pelvis: [0.6, 0] },
    spheres: [[0, 1.12, 0.12, 0.17, 1.3], [0, 1.0, 0.13, 0.15, 1.2]],
    camera: { yaw: 64, dist: 2.45, target: [0, 0.3, -0.12], fov: 28 },
  },

  // —— 哑铃肩推：哑铃从肩旁推到头顶，肘微外展，顶端手臂接近伸直但不锁死。
  'db-shoulder-press': {
    mode: 'stand', arms: 'ik', props: 'dumbbells', bellAxis: 'x', pole: [0.8, -1, -0.15],
    base: { drop: 0.01, hx: 0.27, hy: 1.5, hz: 0.02 },
    keys: [
      [0, {}, 0.2, '起始'], [0.3, {}, 0.9, '发力'],
      [1.5, { hx: 0.2, hy: 1.9, hz: -0.04 }, 1, '顶峰'],
      [1.9, { hx: 0.2, hy: 1.9, hz: -0.04 }, 0.6, '下放'],
      [4.0],
    ],
    spheres: [[0.25, 1.45, -0.03, 0.13, 1], [-0.25, 1.45, -0.03, 0.13, 1], [0.36, 1.44, -0.1, 0.1, 0.8], [-0.36, 1.44, -0.1, 0.1, 0.8]],
    camera: { yaw: 32, dist: 2.45, target: [0, 1.14, 0], fov: 28 },
  },
  // —— 罗马尼亚硬拉：髋铰链，背保持挺直，哑铃贴着大腿滑到小腿中段再回来。
  rdl: {
    mode: 'stand', arms: 'ik', props: 'dumbbells', bellAxis: 'z', pole: [0.5, -1, -0.6],
    base: { drop: 0.02, back: 0, tilt: 0, lean: 2, hx: 0.2, hy: 0.78, hz: -0.02 },
    keys: [
      [0, {}, 0.25, '起始'], [0.4, {}, 0.7, '下放'],
      [2.4, { drop: 0.1, back: 0.3, tilt: 66, lean: 4, hx: 0.19, hy: 0.5, hz: 0.1 }, 0.9, '停顿'],
      [2.8, { drop: 0.1, back: 0.3, tilt: 66, lean: 4, hx: 0.19, hy: 0.5, hz: 0.1 }, 1, '发力'],
      [4.2],
    ],
    glow: { thigh_l: [0, 1], thigh_r: [0, 1], pelvis: [0, 1], spine_01: [0, 0.5] },
    camera: { yaw: 60, dist: 2.3, target: [0, 0.88, -0.05], fov: 28 },
  },
  // —— 高脚杯深蹲：一个哑铃竖着托在胸前，躯干比徒手深蹲更直。
  'goblet-squat': {
    mode: 'stand', arms: 'ik', props: 'goblet', pole: [0.5, -1, -0.5],
    base: { drop: 0.015, back: 0, lean: 4, hx: 0.07, hy: 1.28, hz: 0.12 },
    keys: [
      [0, {}, 0.15, '起始'], [0.5, {}, 0.55, '下放'],
      [2.5, { drop: 0.46, back: 0.15, lean: 22, hx: 0.08, hy: 0.9, hz: 0.2 }, 0.8, '停顿'],
      [2.8, { drop: 0.46, back: 0.15, lean: 22, hx: 0.08, hy: 0.9, hz: 0.2 }, 1, '发力'],
      [4.0],
    ],
    glow: { thigh_l: [1, 0.25], thigh_r: [1, 0.25], pelvis: [0, 0.95] },
    camera: { yaw: 55, dist: 2.25, target: [0, 0.9, -0.02], fov: 28 },
  },
  // —— 哑铃弯举：上臂贴身不动，手握哑铃（中立握，握把前后），边弯边旋后，顶端哑铃横在肩前、掌心朝肩。
  'db-curl': {
    mode: 'stand', arms: 'front', props: 'dumbbells', fist: { mode: 'curl', deg: 80 },
    base: { drop: 0.01, arm: 3, el: 2, roll: 0 },
    keys: [
      [0, {}, 0.2, '起始'], [0.3, {}, 0.9, '发力'],
      [1.4, { arm: 10, el: 138, roll: 85 }, 1, '顶峰'],
      [1.8, { arm: 10, el: 138, roll: 85 }, 0.6, '下放'],
      [3.8],
    ],
    spheres: [[0.3, 1.34, 0.0, 0.1, 1.2], [-0.3, 1.34, 0.0, 0.1, 1.2]],
    camera: { yaw: 38, dist: 2.1, target: [0, 1.0, 0.0], fov: 28 },
  },
  // —— 高位俯卧撑（手撑桌面）：身体一直线，手臂伸直时肩在手的上方，下放到胸口接近桌沿；肘朝后、略向外。
  'incline-pushup': {
    mode: 'prone', ankle: [0.11, -0.66], foot: -62, hand: [0.26, 0.77, 0.38], table: [0.77, 0.38],
    pole: [0.4, 0.15, -1],
    base: { lean: 54, neck: -4 },
    keys: [
      [0, {}, 0.2, '起始'], [0.3, {}, 0.6, '下放'],
      [2.0, { lean: 44 }, 0.85, '停顿'],
      [2.3, { lean: 44 }, 1, '发力'],
      [3.6],
    ],
    spheres: [[0.1, 1.33, 0.09, 0.15, 1], [-0.1, 1.33, 0.09, 0.15, 1], [0.2, 1.43, 0.03, 0.09, 0.7], [-0.2, 1.43, 0.03, 0.09, 0.7]],
    glow: { upperarm_l: [0.2, 0.85], upperarm_r: [0.2, 0.85] },
    camera: { yaw: 60, dist: 2.0, target: [0, 0.55, 0.15], fov: 28 },
  },
  // —— 平板支撑：前臂撑地，身体一直线；静态保持，只有发力程度轻轻起伏（呼吸）。
  plank: {
    mode: 'prone', ankle: [0.13, -0.7], foot: -62, hand: [0.1, 0.045, 0.95], pole: [0, -1, -0.15],
    base: { lean: 10, neck: 8 },
    keys: [[0, {}, 0.6, '保持'], [1.5, {}, 1, '收紧'], [3.0]],
    spheres: [[0, 1.12, 0.12, 0.17, 1.3], [0, 1.0, 0.13, 0.15, 1.2], [0.1, 1.33, 0.09, 0.13, 0.5], [-0.1, 1.33, 0.09, 0.13, 0.5]],
    still: 1.6,
    camera: { yaw: 58, dist: 2.45, target: [0, 0.22, 0.28], fov: 28 },
  },
  // —— 提踵：脚尖踩地，脚跟尽量抬高，顶端停一下，慢慢放下。
  'calf-raise': {
    mode: 'stand', arms: 'front',
    base: { drop: 0.0, arm: 6, el: 6, heel: 0 },
    keys: [
      [0, {}, 0.2, '起始'], [0.3, {}, 0.8, '发力'],
      [1.2, { heel: 0.11 }, 1, '顶峰'],
      [1.7, { heel: 0.11 }, 0.6, '下放'],
      [3.6],
    ],
    glow: { calf_l: [0.1, 1], calf_r: [0.1, 1] },
    camera: { yaw: 50, dist: 2.3, target: [0, 0.92, 0], fov: 28 },
  },
  // —— 分腿蹲：前后站开，身体垂直下降到后膝接近地面，前脚发力站起。
  'split-squat': {
    mode: 'stand', arms: 'front', stance: { l: [0.1, 0.4], r: [0.1, -0.38, 0.1] },
    base: { drop: 0.02, back: 0, lean: 3, arm: 6, el: 6 },
    keys: [
      [0, {}, 0.2, '起始'], [0.5, {}, 0.55, '下放'],
      [2.4, { drop: 0.36 }, 0.8, '停顿'],
      [2.7, { drop: 0.36 }, 1, '发力'],
      [4.0],
    ],
    glow: { thigh_l: [1, 0.3], thigh_r: [1, 0.3], pelvis: [0, 0.9] },
    camera: { yaw: 70, dist: 2.2, target: [0, 0.8, 0], fov: 28 },
  },
};
