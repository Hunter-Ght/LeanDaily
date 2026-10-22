# 第三方内容与许可

LeanDaily 本身使用 [MIT 许可证](../LICENSE)。以下是随应用分发的第三方内容：

| 内容 | 位置 | 来源与许可 |
| --- | --- | --- |
| 动作示范图（58 个动作，每个 2 帧） | `assets/exercises/` | [free-exercise-db](https://github.com/yuhonas/free-exercise-db)，**Unlicense（公共领域）**。原有图片已缩小后打包，新增三组保留原图，离线使用。 |
| 字标字体子集（仅"薄肌日课"4 个字） | `assets/fonts/SmileySans-Wordmark.ttf` | [得意黑 Smiley Sans](https://github.com/atelier-anchor/smiley-sans)，**SIL Open Font License 1.1**，允许商用与嵌入分发。说明见 `assets/fonts/NOTICE.txt`。 |
| 人体肌肉示意图路径 | `assets/body_paths.json` | 项目自绘（SVG 路径），随项目 MIT 许可。 |
| 图标 | `assets/icons.json` | 项目自绘（SVG 路径），随项目 MIT 许可。 |
| 食物库（约 300 种常见食物） | `assets/foods.json` | 项目整理的常见量级**估算值**，不是官方营养数据。 |
| Flutter 框架 | 依赖 | BSD-3-Clause |
| `path_drawing`（解析 SVG 路径） | 依赖 | BSD-3-Clause |

App 内"我的 → 关于 → 开源与致谢 → 查看开源许可证"可以看到 Flutter 汇总的全部依赖许可证。

## 你自己再发布时

- 保留 `LICENSE`、`assets/fonts/NOTICE.txt` 和本文件；
- 如果替换了示范图，请在这里补充新图片的来源与许可；
- 应用商店上架时，"开源与致谢"页要继续保留。

## 新增动作示范

硬拉、引体向上、反向划船的原图来源版本、上游路径和 SHA-256 见 [exercise-demo-sources.json](exercise-demo-sources.json)。许可为上游 [Unlicense](https://github.com/yuhonas/free-exercise-db/blob/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/LICENSE.md)。反向划船图片展示固定横杆版本，应用在图片下方说明它与居家桌下版本的器械差异。
