# 发布清单

## 第一次发布前：要你自己填的地方

| 位置 | 内容 |
| --- | --- |
| `lib/config/app_links.dart` → `updateCheckUrl` | 检查更新地址。GitHub 用：`https://api.github.com/repos/<用户名>/<仓库名>/releases/latest`；或自托管 JSON：`{"version":"2.4.0","build":25,"url":"https://…","notes":"更新说明"}` |
| `lib/config/app_links.dart` → `privacyPolicyUrl` | 隐私政策在线页面：GitHub Pages 页面，或 `PRIVACY.md` 在 GitHub 上的链接 |
| `lib/config/app_links.dart` → `repoUrl` | 项目主页：`https://github.com/<用户名>/<仓库名>` |
| `assets/legal/privacy.md`、`PRIVACY.md`、`PRIVACY.en.md` 末尾的"联系我们" | 项目主页或 Issues 链接 |
| `README.md`、`README.en.md` 里的 `<你的用户名>` / `<your-username>` | 你的 GitHub 用户名 |
| `LICENSE` | 版权署名（目前是 `Hunter-Ght`） |

留空的链接对应功能会显示"未配置"，不会发出请求，所以这些可以分步填。

## 每次发布

1. 修改 `pubspec.yaml` 的 `version:`（如 `2.4.0+25`），`lib/config/app_info.dart` 里的 `appVersion` / `appBuild` 与之保持一致（有测试检查）。
2. 更新 `CHANGELOG.md`。
3. 跑检查：
   ```bash
   flutter analyze && bash tool/lint_tokens.sh && TZ=Asia/Shanghai flutter test
   ```
4. 用**你自己的签名**构建（保持同一把签名，用户才能覆盖安装升级）：
   ```bash
   export LEANDAILY_STORE_FILE=/path/to/release.jks
   export LEANDAILY_SIGNING_PASSWORD=...
   export LEANDAILY_KEY_ALIAS=...
   flutter build apk --release --target-platform android-arm64
   python3 tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk
   ```
5. 把 APK 改名为 `LeanDaily-<版本>-arm64.apk`，计算 SHA-256，在 GitHub 创建 Release：Tag 用 `v<版本>`，上传 APK，说明里写更新内容和 SHA-256。
6. 检查更新读取的是 Releases 接口时，发 Release 后 App 就能发现新版（"我的"图标上出现小红点）。

## 签名与密钥

- **签名文件（`.jks`）和密码不要进仓库**（`.gitignore` 已忽略 `*.jks`）。丢失签名文件，已安装的用户就无法覆盖升级。
- 多备份几份签名文件，放在仓库之外。

## 不要做的事

- **不要打开 R8 混淆**（`isMinifyEnabled`）。Flutter 引擎按类名回调 `FlutterJNI`，被混淆后无法启动。
- 不要手动截断/改写引擎 `.so` 来"瘦身"：Android 7+ 要求 ELF 区段表存在，缺失会导致加载失败。体积优化走 NDK 的 `llvm-strip`（构建已配置），并用 `tool/check_apk.py` 检查。
