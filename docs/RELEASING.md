# 发布清单

## 已配置的项目资料

| 位置 | 当前内容 |
| --- | --- |
| `lib/config/app_links.dart` → `updateCheckUrl` | `https://api.github.com/repos/Hunter-Ght/LeanDaily/releases/latest` |
| `lib/config/app_links.dart` → `privacyPolicyUrl` | `https://github.com/Hunter-Ght/LeanDaily/blob/main/PRIVACY.md` |
| `lib/config/app_links.dart` → `repoUrl` | `https://github.com/Hunter-Ght/LeanDaily` |
| `assets/legal/privacy.md`、`PRIVACY.md`、`PRIVACY.en.md` 的联系方式 | `https://github.com/Hunter-Ght/LeanDaily/issues` |
| `README.md`、`README.en.md` 中的仓库用户名 | `Hunter-Ght` |
| `LICENSE` 版权署名 | `Hunter-Ght` |

### 隐私政策如何上线

当前使用 GitHub 自带的 Markdown 阅读页面。将 `PRIVACY.md` 提交并推送到远程 `main` 后，上面的在线地址即可展示文件内容；公开仓库的访问者无需登录。无需域名、服务器或 GitHub Pages。仓库需公开并启用 Issues，才能让所有用户阅读政策、提交问题。

如果以后想使用独立网页样式，可以再配置仓库 **Settings → Pages**，选择发布分支和目录，部署成功后将 `privacyPolicyUrl` 改为实际页面地址。仅推送文件不会自动启用 GitHub Pages。

`assets/legal/privacy.md` 是 App 内离线政策，修改它需要重新构建并安装 App；修改远程 `PRIVACY.md` 则会直接更新在线阅读内容。App 链接常量的修改也需要重新构建安装。

### 检查更新如何工作

App 请求 `updateCheckUrl`，读取正式 Release 的 `tag_name`、更新说明和附件地址。标签使用 `v2.3.0` 这样的格式。远程版本号高于已安装版本时才提示更新；仅增加 `pubspec.yaml` 的 build 数字，GitHub 的 latest 接口不会提供可用于比较的 build 字段，因此每次正式更新也要增加三段版本号。

发布时只附上适用的 arm64 APK（其他附件可为校验文件等），因为当前代码会选择第一个 `.apk` 附件，尚不按设备架构筛选。用户点击更新后打开下载地址，再由用户安装；并非静默安装。

首次正式 Release 发布前，latest 接口可能返回 404，App 会显示检查失败；Draft / Pre-release 不会作为正式最新版返回。只推送源码或标签不会创建可下载的 APK。当前 `.github/workflows/ci.yml` 只运行检查，没有自动打包上传流程。

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
5. 将本次源码提交并推送到 GitHub，确认 CI 通过。把 APK 改名为 `LeanDaily-<版本>-arm64.apk`，计算 SHA-256。首次发布前，如果已有旧版用户，需要找回原来的签名；更换签名无法覆盖安装旧版。
6. 按下文创建 Release 并上传 APK，先保存为草稿，检查版本、附件和说明，再发布正式版本。
7. 发布后打开 Release 页面，确认 **Assets** 中有 APK 且能下载。使用低版本 App 检查更新，确认能发现新版并打开 APK 下载链接；相同版本显示已是最新版本。

### 在 GitHub 网页上传安装包

1. 打开 <https://github.com/Hunter-Ght/LeanDaily/releases>，点击 **Draft a new release**。
2. Tag 填 `v<版本>`（例如当前版本 `v2.3.0`），Target 选择已推送且通过 CI 的发布提交。
3. 标题填 `LeanDaily <版本>`，正文写更新内容和 APK 的 SHA-256。
4. 在附件区域上传 `LeanDaily-<版本>-arm64.apk`，等待上传完成。自动生成的 **Source code (zip/tar.gz)** 是源码，不能作为 Android 安装包。
5. 先 **Save draft** 核对；确认后发布，正式版不要勾 **Pre-release**，并设为最新版。

发布完成后：

- 所有版本：<https://github.com/Hunter-Ght/LeanDaily/releases>
- 最新正式版：<https://github.com/Hunter-Ght/LeanDaily/releases/latest>
- 某个版本（示例）：`https://github.com/Hunter-Ght/LeanDaily/releases/tag/v2.3.0`
- 对应 APK（文件名需完全一致）：`https://github.com/Hunter-Ght/LeanDaily/releases/download/v2.3.0/LeanDaily-2.3.0-arm64.apk`

### 用 GitHub CLI 创建草稿（可选）

先安装 GitHub CLI，并运行 `gh auth login`。以下以 `2.3.0` 为例；后续发布必须替换版本号、文件名和标签，且先完成签名构建、检查、提交和推送。

```bash
cp build/app/outputs/flutter-apk/app-release.apk LeanDaily-2.3.0-arm64.apk
shasum -a 256 LeanDaily-2.3.0-arm64.apk
```

将本次更新说明和上面的 SHA-256 写入仓库外的 `/tmp/leandaily-release-notes.md`，然后：

```bash
# 获取已推送的发布提交，将标签绑定到这个明确的提交。
git fetch origin main
git rev-parse origin/main
# 用上一步输出的完整提交 SHA 替换下面的 <发布提交SHA>。
gh release create v2.3.0 LeanDaily-2.3.0-arm64.apk \
  --repo Hunter-Ght/LeanDaily \
  --target <发布提交SHA> \
  --title 'LeanDaily 2.3.0' \
  --notes-file /tmp/leandaily-release-notes.md \
  --draft
```

在 GitHub 草稿页面核对后点击发布；此时 APK 才对普通用户可见，并可被 App 的正式版更新检查发现。

## 签名与密钥

- **签名文件（`.jks`）和密码不要进仓库**（`.gitignore` 已忽略 `*.jks`）。丢失签名文件，已安装的用户就无法覆盖升级。
- 多备份几份签名文件，放在仓库之外。

## 不要做的事

- **不要打开 R8 混淆**（`isMinifyEnabled`）。Flutter 引擎按类名回调 `FlutterJNI`，被混淆后无法启动。
- 不要手动截断/改写引擎 `.so` 来"瘦身"：Android 7+ 要求 ELF 区段表存在，缺失会导致加载失败。体积优化走 NDK 的 `llvm-strip`（构建已配置），并用 `tool/check_apk.py` 检查。
