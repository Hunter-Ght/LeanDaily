# 3D 动作示范制作说明

用 three.js 离线渲染人体动画，编码成动画 WebP 放进 App（`assets/motion3d/`）。App 里的播放器见 `lib/ui/kit/motion3d_demo.dart`。

## 流水线

```
specs_*.js（动作数据）→ scene.html（three.js 场景）→ render.cjs（无头 Chrome 逐帧截图）
   → build.sh（缩放 + img2webp 编码）→ assets/motion3d/<动作>.webp + tool/motion3d/entries/<动作>.json
   → manifest.py 合并成 assets/motion3d/manifest.json（只由主线统一运行）
```

- 依赖和模型都在仓库外的 `out/`（已忽略）：`out/motion3d/node_modules`（three、playwright-core）、`out/models/quaternius-ubc`（Quaternius Universal Base Characters，CC0，男性超级英雄体型）、`out/tools/libwebp-*`。
- 在另一个 git 工作区里干活时，先 `ln -s <主仓库>/out out` 把 `out` 链接过来。
- **看图**：`bash tool/motion3d/sheet.sh <动作> [fps=3] [边长=320]` 输出联系表 `out/motion3d/review/<动作>.png`，用 Read 工具看。单帧：`SCENE_QUERY=bg=ebebef node tool/motion3d/render.cjs <动作> <输出目录> 25 480 <秒>`。
- **出成品**：`bash tool/motion3d/build.sh <动作 key>...`。成品规格固定（448px、25 fps、q85）：不要改。

## 坐标与人体

世界坐标，米，y 向上，人面朝 +z，人的**左侧在 +x**（`_l` 骨头在 +x，`_r` 在 −x）。绑定姿势是 T 字，掌心朝下：

| 位置 | 坐标 |
|---|---|
| 骨盆 pelvis | (0, 0.95, −0.04) |
| 胸 spine_03 | (0, 1.31, 0.01) |
| 头 Head | (0, 1.60, −0.02) |
| 肩 upperarm_l | (0.21, 1.455, −0.065)，手臂沿 x 平伸到 0.71 |
| 髋 thigh_l | (0.11, 0.97, −0.04) |
| 膝 calf_l | (0.11, 0.54, −0.04) |
| 踝 foot_l | (0.11, 0.09, −0.09)，脚尖 ball_l (0.11, 0.015, 0.055) |

骨长：大腿 0.43、小腿 0.45、上臂 0.25、前臂 0.24。

`glow.spheres` 里的坐标是**绑定姿势下的世界坐标**（T 字站姿）。人体正面在 +z，所以：胸前 z≈+0.09，背后 z≈−0.1；肩前束 (±0.25, 1.45, −0.03)；腹 (0, 1.0~1.12, 0.12)；臀 (±0.1, 0.95, −0.1)；大腿前 (±0.11, 0.75, 0.03)；上臂在 T 字里沿 x 平伸，所以二头肌在 (±0.34, 1.455, 0.0)，三头肌在 (±0.34, 1.44, −0.1)。

## 动作数据（specs_*.js）

```js
'动作key': {
  mode: 'stand' | 'prone' | 'supine' | 'under' | 'facedown' | 自己在 EXTRA_MODES 里加的名字,
  base: { ...姿势参数默认值 },
  keys: [[秒, { 覆盖的参数 }, 发力程度 0~1, '阶段名'], ..., [结束秒]],   // 最后一项只写结束时间，回到第一帧
  glow: { 骨头名: [前侧强度, 后侧强度] },        // 整根骨头按蒙皮权重着色
  spheres: [[x, y, z, 半径, 强度], ...],          // 最多 8 个球形发光区域（三角肌、胸这类）
  props / bellAxis / barbell / cables / set / table / tilt …  // 见下
  still: 秒,            // 可选：“减少动态效果”时停在这一刻；不写取发力最大那段的开头
  camera: { yaw, dist, target: [x, y, z], fov: 28 },
}
```

- 节奏：一个循环 3.5~4.5 秒（俯卧撑 3.6、深蹲 4.0）；离心（下放）慢 ~2 秒，向心（发力）快 ~1.2 秒，顶/底停 0.3~0.4 秒。动作质量比好看更重要：关节角度要像真人做的。
- **阶段名只能用这几个**（已有三种语言翻译）：起始、下放、停顿、发力、顶峰、伸展、收回、保持、收紧。
- 已有示例：`specs_base.js`（深蹲、俯卧撑、侧平举、臀桥、死虫式、肩推、罗马尼亚硬拉、高脚杯深蹲、弯举、高位俯卧撑、平板、提踵、分腿蹲）。**先读它们**，再动手。

### 姿势模式（scene.html 里的 poseXxx）

- `stand`：站或坐。参数 `drop` 骨盆下沉、`back` 骨盆后移、`tilt` 骨盆前倾（髋铰链）、`lean` 躯干再前弯、`headUp`；
  手臂 `arms:'front'`（`arm` 前举角、`el` 肘屈）、`'side'`（`abd` 外展角、`el`）、`'ik'`（`hx/hy/hz` 手的位置，可加后缀 `L`/`R` 单侧覆盖，如 `hxL`；`pole:[x,y,z]` 决定肘朝哪弯，x 会按左右取反）；
  脚 `heel` 抬脚跟、`stance:{l:[x,z],r:[x,z,heel]}` 前后站位、`fy/fz/fpitch`（可加 `L`/`R`）脚踝额外位移，坐姿器械里小腿摆动用；`legs:'hang'` 悬垂时腿自然下垂。
  **坐姿**：`drop≈0.45、back≈0.4` 把骨盆放到椅面高度和靠背位置，大腿水平，再配 `set` 里的椅子。
- `prone`（俯卧撑、平板）：以脚尖为支点，`lean` 身体与地面夹角，手固定在 `hand`。`under`：同理但脸朝上，抓头顶横杆（`bar:[高, z]`，`hx/hy/hz` 可覆盖），反向划船。
- `supine`（仰卧）：`shoulder:[y,z]` 肩背贴地处，参数 `hip` 骨盆高度、`curl` 卷腹抬肩、`neck`；腿 `feet:[x,y,z]` 脚踩地（IK）或 `hipFlex/knee` 悬空；手臂 `armUp`（0=平放身侧）或 `arms:'ik'`。
- `facedown`（俯卧在地或凳上）：`h` 骨盆高度、`hipZ`、`arch` 后伸抬胸、`flex` 前屈下垂、`legLift` 抬腿，手臂 IK 指向前方（`hx/hy/hz`）。
- 现有模式放不下的，在 `scene.html` 里**自己家族的区域**写 `EXTRA_MODES.名字 = (spec, v) => {...}`，可以用的工具函数：`wpos wquat setWorldPos setWorldQuat rotWorld aim twoBone palm`、常量 `bindPos bindQuat L bones bind X V rad`。**不要改共用的 poseStand/poseProne 等**；确实必须改时改得最小，并在报告里说明。

### 道具

- 哑铃：`props:'dumbbells'`（一对，`bellAxis:'x'|'y'|'z'` 握把方向，默认 z）、`props:'goblet'`（一个竖着托在两手之间）、`oneBell:'l'|'r'`（只画一只）。
- 杠铃/拉杆：`barbell:{ len: 1.8, plate: 0.225, at:[0,-0.02,0] }`，杆在两手中点沿 x 方向，`plate:0` 就是光杆（拉杆、横杆）。
- 拉索：`cables:[{ from:[x,y,z], to:'hands'|'handL'|'handR' }]`，从固定点到手的一根细线。
- 通用道具 `set:[{ box:[宽,高,深] | cyl:[半径,长], at:[x,y,z], rot:[度,度,度], m:'frame'|'pad'|'stack'|'steel'|'plate', follow:'hands'|'handL'|'handR'|'feet', offset:[x,y,z], fixed:true }]`。
  材质：`frame` 深灰金属框架，`pad` 灰褐色软垫（座椅、长凳），`stack` 配重片，`steel` 亮钢，`plate` 杠铃片。`follow` 让道具跟着手/脚走（腿举滑板、拉杆手柄）；`fixed:true` 的不随 `tilt` 整体倾斜。
- `table:[高, z]`：高位俯卧撑的桌台。
- `tilt:{ deg, pivot:[y, z] }`：整体（人 + 非 fixed 道具）绕 (y,z) 后仰 deg 度：先按“直坐”摆好姿势，再倾斜，用于腿举这类斜躺的器械。
- 道具保持极简：几块方块和圆柱，**不要品牌、不要文字、不要写实细节**。器械不能挡住发力的肌肉，也不能穿过身体。

## 画面质量要求（逐条自查）

1. 人完整在画面内，上下左右留 ≥ 5% 余量；整个循环里不被裁切，也不要过小（人/动作区域至少占画面的一半）。
2. 脚（或手）踩地的地方不滑、不悬空、不穿地面；关节不反折、不拧麻花；手腕不异常扭转。
3. 动作幅度到位，符合 `lib/domain/guide.dart` 里该动作的“怎么做”和“常见错误”（先读它）：脊柱中立、膝盖方向正确、肘位正确、顶端不锁死。
4. 发力的肌肉亮在正确位置，且随发力程度变化；不发力的地方不亮。
5. 机位选能看清动作的角度：矢状面动作（深蹲、划船）用 yaw 45~70，正面动作（侧平举、飞鸟）用 yaw 15~35。
6. 器械和身体不穿模，道具和人的比例协调（座椅高度 ≈ 0.45、长凳高 ≈ 0.43）。
7. 成品 webp ≤ 450 KB；超了就缩短停顿或循环。

## 提交

- 提交内容：`specs_<家族>.js`、`scene.html` 里自己家族的区域、`assets/motion3d/*.webp`、`tool/motion3d/entries/*.json`。
- **不要**运行 `manifest.py`、不要改 `assets/motion3d/manifest.json`、不要改 `lib/` `test/` 和翻译文件、不要跑 Flutter。
- 提交信息用中文，结尾加 `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`。
