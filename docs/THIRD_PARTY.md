# 第三方内容与许可

LeanDaily 本身使用 [MIT 许可证](../LICENSE)。以下是随应用分发的第三方内容：

| 内容 | 位置 | 来源与许可 |
| --- | --- | --- |
| 动作示范图与 3D 动画（77 个动作） | `assets/exercises/`、`assets/motion3d/` | 本项目用 `tool/motion3d/` 离线渲染生成，随项目 MIT 许可。人体模型为 [Quaternius Universal Base Characters](https://quaternius.itch.io/universal-base-characters)，**CC0**（不随仓库分发，只分发渲染结果）。 |
| 数字字体 | `assets/fonts/BarlowSemiCondensed-*.ttf` | [Barlow](https://github.com/jpt/barlow)，**SIL Open Font License 1.1**，许可见 `assets/fonts/Barlow-OFL.txt`。 |
| 字标字体子集（仅"薄肌日课"4 个字） | `assets/fonts/SmileySans-Wordmark.ttf` | [得意黑 Smiley Sans](https://github.com/atelier-anchor/smiley-sans)，**SIL Open Font License 1.1**，允许商用与嵌入分发。说明见 `assets/fonts/NOTICE.txt`。 |
| MuscleMap 人体肌群路径 | `assets/muscle_map.json` | [MuscleMap](https://github.com/melihcolpan/MuscleMap)，Melih Colpan，**MIT**。固定提交与逐组映射见 [映射报告](musclemap-mapping.md)，完整许可见 `assets/legal/MuscleMap-LICENSE.txt`。 |
| 图标 | `assets/icons.json` | 项目自绘（SVG 路径），随项目 MIT 许可。 |
| 食物库（约 300 种常见食物） | `assets/foods.json` | 项目整理的常见量级**估算值**，不是官方营养数据。 |
| Flutter 框架 | 依赖 | BSD-3-Clause |
| `path_drawing`（解析 SVG 路径） | 依赖 | BSD-3-Clause |

App 内"我的 → 关于 → 开源与致谢 → 查看开源许可证"可以看到 Flutter 汇总的全部依赖许可证。

## 你自己再发布时

- 保留 `LICENSE`、`assets/fonts/NOTICE.txt` 和本文件；
- 如果替换了示范图，请在这里补充新图片的来源与许可；
- 应用商店上架时，"开源与致谢"页要继续保留。

## 历史：早期实拍示范图

2026-11 之前的版本曾使用 [free-exercise-db](https://github.com/yuhonas/free-exercise-db) 的实拍图，现已全部替换为 3D 渲染。当时硬拉、引体向上、反向划船的原图来源版本、上游路径和 SHA-256 见 [exercise-demo-sources.json](exercise-demo-sources.json)。许可为上游 [Unlicense](https://github.com/yuhonas/free-exercise-db/blob/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/LICENSE.md)。反向划船图片展示固定横杆版本，应用在图片下方说明它与居家桌下版本的器械差异。
