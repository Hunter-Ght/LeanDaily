# 参与贡献

感谢你愿意帮助 LeanDaily 变得更好！

## 提 Issue

- **Bug**：请说明手机型号、Android 版本、App 版本（"我的 → 关于"里能看到），以及复现步骤；有截图更好。**不要在 Issue 里贴你的备份文件或 API 密钥。**
- **建议**：先说你要解决的问题，再说你想要的做法。
- **训练 / 饮食规则**的讨论请附上依据（指南、论文或你的实践经验）。规则文档见 [docs/PROGRESSION.md](docs/PROGRESSION.md)。

## 开发环境

需要 Flutter 3.47+、JDK 17+、Android SDK 与 NDK（用于 `llvm-strip`）。

```bash
flutter pub get
flutter analyze
bash tool/lint_tokens.sh
TZ=Asia/Shanghai flutter test     # 时区必须固定，否则与日期相关的测试会失败
```

截图测试会把图片写到 `out/shots-plain/`（带 `LEANDAILY_SAFE_AREA=1` 时写到 `out/shots/`，那是 README 展示图的素材）。README 里的展示图用下面的方法重新生成（macOS）：

```bash
python3 tool/readme_shots/extract_pingfang_sc.py        # 抽出苹方-简，截图字形才和真机一致
export LEANDAILY_SAFE_AREA=1                            # 模拟状态栏和手势条的安全区，界面才不会贴边
export LEANDAILY_TEST_FONT="$PWD/out/fonts/PingFangSC-Regular.ttf" TZ=Asia/Shanghai
flutter test                                            # 部分对位置敏感的测试在安全区下会失败，不影响出图
for s in light dark; do README_SCHEME=$s flutter test tool/readme_shots/readme_shots_test.dart; done
python3 tool/readme_shots/compose.py                    # 需要 Node + playwright-core、Chrome、ffmpeg
```

## 代码约定

- **业务规则写在 `lib/domain/`**，是纯 Dart、对 JSON 形状的 Map 做纯函数；界面里不写业务计算。
- **新规则必须有测试**；动到进阶规则要同时更新 [docs/PROGRESSION.md](docs/PROGRESSION.md) 和 `test/progression_sim_test.dart` 的相关断言。
- 界面不使用 Material 控件，**不写死颜色**（用 `context.pal`），所有可点元素用 `Pressable` 并带无障碍标签，点击目标不小于 44×44。
- 内容的出现、消失、展开必须有过渡（`lib/ui/kit/transitions.dart`），尊重"减弱动态效果"。
- 文案：中文、人话；**不评判身体**（不用"偏高/偏瘦/失败/偷懒"），见 [docs/DESIGN.md](docs/DESIGN.md)。
- 数据格式有兼容承诺：**不要改已有存储键的含义**；确需迁移请写迁移测试，旧备份必须仍可恢复。

## 提 PR

1. Fork 并新建分支；
2. 保持改动聚焦，一个 PR 做一件事；
3. 确认 `flutter analyze`、`tool/lint_tokens.sh` 和全量测试通过；
4. 涉及界面的 PR 请附亮色和暗色截图；
5. 在 PR 描述里说明改了什么、为什么。

## 安全与隐私

LeanDaily 的核心承诺是**不收集数据、不联网（除用户自己配置的拍照识别和检查更新）**。任何会引入网络请求、统计、第三方 SDK 或新权限的改动，都需要先开 Issue 讨论，并同步更新 [PRIVACY.md](PRIVACY.md)。

## 行为准则

请友善、尊重地交流。不接受对他人身材、体重、性别、年龄的评判或嘲讽。
