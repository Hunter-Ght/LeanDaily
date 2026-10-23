# MuscleMap 肌群映射

来源：[https://github.com/melihcolpan/MuscleMap](https://github.com/melihcolpan/MuscleMap)；作者 Melih Colpan；MIT。
固定提交：`5f576a5d3d697c3720abfada8e618d1cef08ea32`。

复现：`python3 tool/musclemap/convert.py /tmp/musclemap-src`。仅读取该仓库，不使用其他来源。

四视图保留上游坐标及 viewBox。`groups` 额外保存每个原始组／子组，便于追溯；
`muscles` 按我们的 id 汇总，完全相同的路径去重，不合并子区几何。
`other` 保存未跟踪肌群及非肌肉部位，并逐条加入 `inert`。

## 映射判断与限制

- 正面 `deltoids` 是整块肩部，单独归 `delt_side`；`frontDeltoid` 归前束。两者有覆盖，未来绘制应先画中束再画前束；没有独立中束几何，不自行裁剪。
- 背面 `deltoids` 由 `rearDeltoid` 替代；胸、腹、斜方肌使用子区替代父区，父区仅归档于 `groups`。
- `upperBack` 是背阔主体，归 `lats`；肩袖 `rotatorCuff` 保留中性。菱形肌与下斜方肌归 `mid_back`；上斜方肌保持中性。
- 股四头父区含中央区域，不能只保留内／外侧子区；保留全部独立形状，同一路径只计一次。
- 两种性别均覆盖全部 16 个 id，无缺失例外。女性背面无 head，头部由 hair 覆盖。
- 致谢页为 UI 硬编码，许可证页使用 Flutter LicenseRegistry，无许可数据文件；本次按范围不改 UI，完整许可随 assets/legal/ 打包。

## male / front

| 上游组／子组 | 路径数 | 处理 |
| --- | ---: | --- |
| chest | 2 | 由 upperChest、lowerChest 子区替代（父区仅归档） |
| abs | 8 | 由 upperAbs、lowerAbs 子区替代（父区仅归档） |
| biceps | 2 | `biceps` |
| triceps | 2 | `triceps` |
| deltoids | 2 | `delt_side` |
| obliques | 16 | `obliques` |
| quadriceps | 6 | `quads` |
| calves | 4 | `calves` |
| adductors | 6 | `other` + `inert`（未跟踪／非肌肉） |
| trapezius | 2 | 由 upperTrapezius 子区替代（父区仅归档） |
| neck | 5 | `other` + `inert`（未跟踪／非肌肉） |
| forearm | 6 | `other` + `inert`（未跟踪／非肌肉） |
| hands | 12 | `other` + `inert`（未跟踪／非肌肉） |
| knees | 4 | `other` + `inert`（未跟踪／非肌肉） |
| tibialis | 2 | `other` + `inert`（未跟踪／非肌肉） |
| ankles | 4 | `other` + `inert`（未跟踪／非肌肉） |
| feet | 4 | `other` + `inert`（未跟踪／非肌肉） |
| serratus | 12 | `other` + `inert`（未跟踪／非肌肉） |
| hipFlexors | 2 | `other` + `inert`（未跟踪／非肌肉） |
| upperChest | 2 | `chest_up` |
| lowerChest | 2 | `chest` |
| innerQuad | 2 | `quads` |
| outerQuad | 2 | `quads` |
| upperAbs | 6 | `abs` |
| lowerAbs | 2 | `abs` |
| frontDeltoid | 2 | `delt_front` |
| head | 1 | `other` + `inert`（未跟踪／非肌肉） |
| hair | 1 | `other` + `inert`（未跟踪／非肌肉） |
| upperTrapezius | 2 | `other` + `inert`（未跟踪／非肌肉） |

## male / back

| 上游组／子组 | 路径数 | 处理 |
| --- | ---: | --- |
| neck | 2 | `other` + `inert`（未跟踪／非肌肉） |
| trapezius | 2 | 由 upperTrapezius 子区替代（父区仅归档） |
| deltoids | 2 | 由 rearDeltoid 子区替代（父区仅归档） |
| upperBack | 4 | `lats` |
| rotatorCuff | 2 | `other` + `inert`（未跟踪／非肌肉） |
| rhomboids | 2 | `mid_back` |
| triceps | 6 | `triceps` |
| lowerBack | 4 | `lower_back` |
| forearm | 8 | `other` + `inert`（未跟踪／非肌肉） |
| gluteal | 4 | `glutes` |
| adductors | 2 | `other` + `inert`（未跟踪／非肌肉） |
| hamstring | 8 | `hamstrings` |
| calves | 8 | `calves` |
| ankles | 2 | `other` + `inert`（未跟踪／非肌肉） |
| feet | 2 | `other` + `inert`（未跟踪／非肌肉） |
| hands | 12 | `other` + `inert`（未跟踪／非肌肉） |
| head | 1 | `other` + `inert`（未跟踪／非肌肉） |
| hair | 1 | `other` + `inert`（未跟踪／非肌肉） |
| upperTrapezius | 2 | `other` + `inert`（未跟踪／非肌肉） |
| lowerTrapezius | 2 | `mid_back` |
| rearDeltoid | 2 | `delt_rear` |

## female / front

| 上游组／子组 | 路径数 | 处理 |
| --- | ---: | --- |
| neck | 5 | `other` + `inert`（未跟踪／非肌肉） |
| trapezius | 2 | 由 upperTrapezius 子区替代（父区仅归档） |
| hair | 2 | `other` + `inert`（未跟踪／非肌肉） |
| deltoids | 4 | `delt_side` |
| head | 1 | `other` + `inert`（未跟踪／非肌肉） |
| chest | 2 | 由 upperChest、lowerChest 子区替代（父区仅归档） |
| biceps | 2 | `biceps` |
| triceps | 2 | `triceps` |
| obliques | 12 | `obliques` |
| abs | 8 | 由 upperAbs、lowerAbs 子区替代（父区仅归档） |
| forearm | 8 | `other` + `inert`（未跟踪／非肌肉） |
| hands | 12 | `other` + `inert`（未跟踪／非肌肉） |
| adductors | 6 | `other` + `inert`（未跟踪／非肌肉） |
| quadriceps | 6 | `quads` |
| knees | 6 | `other` + `inert`（未跟踪／非肌肉） |
| tibialis | 2 | `other` + `inert`（未跟踪／非肌肉） |
| calves | 4 | `calves` |
| ankles | 4 | `other` + `inert`（未跟踪／非肌肉） |
| serratus | 10 | `other` + `inert`（未跟踪／非肌肉） |
| hipFlexors | 2 | `other` + `inert`（未跟踪／非肌肉） |
| upperChest | 2 | `chest_up` |
| lowerChest | 2 | `chest` |
| innerQuad | 2 | `quads` |
| outerQuad | 2 | `quads` |
| upperAbs | 6 | `abs` |
| lowerAbs | 2 | `abs` |
| frontDeltoid | 2 | `delt_front` |
| feet | 4 | `other` + `inert`（未跟踪／非肌肉） |
| upperTrapezius | 2 | `other` + `inert`（未跟踪／非肌肉） |

## female / back

| 上游组／子组 | 路径数 | 处理 |
| --- | ---: | --- |
| hair | 2 | `other` + `inert`（未跟踪／非肌肉） |
| neck | 2 | `other` + `inert`（未跟踪／非肌肉） |
| trapezius | 2 | 由 upperTrapezius 子区替代（父区仅归档） |
| deltoids | 2 | 由 rearDeltoid 子区替代（父区仅归档） |
| upperBack | 2 | `lats` |
| rotatorCuff | 2 | `other` + `inert`（未跟踪／非肌肉） |
| rhomboids | 2 | `mid_back` |
| lowerBack | 4 | `lower_back` |
| triceps | 6 | `triceps` |
| forearm | 8 | `other` + `inert`（未跟踪／非肌肉） |
| hands | 12 | `other` + `inert`（未跟踪／非肌肉） |
| gluteal | 4 | `glutes` |
| adductors | 4 | `other` + `inert`（未跟踪／非肌肉） |
| hamstring | 6 | `hamstrings` |
| calves | 8 | `calves` |
| feet | 2 | `other` + `inert`（未跟踪／非肌肉） |
| upperTrapezius | 2 | `other` + `inert`（未跟踪／非肌肉） |
| lowerTrapezius | 2 | `mid_back` |
| rearDeltoid | 2 | `delt_rear` |
| ankles | 4 | `other` + `inert`（未跟踪／非肌肉） |

JSON 文件大小：**279,207 字节**（UTF-8，含原始 groups 归档）。
