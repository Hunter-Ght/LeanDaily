# iOS 开发与验收

实现选择：保留 Flutter + `Native` 接口，增加 Swift 原生层。Android 实现和数据键保持兼容；没有引入第三方 iOS 插件、统计或云同步。

## 工具与运行

- macOS、项目指定的 Flutter 3.47.6 / Dart 3.13.5、Xcode 和已安装的 iOS Simulator。
- iOS 最低版本为 15.0；相册使用 PHPicker，只读取用户选择的照片。
- 不需要为本实现安装 CocoaPods。未来加入依赖 Pods 的插件时另行配置。

```sh
# 本机 SDK 位于此目录；终端找不到 flutter 时先设置当前终端的 PATH。
export PATH="$HOME/.local/share/flutter/bin:$PATH"
flutter pub get
flutter build ios --simulator --debug
flutter run -d <iPhone模拟器ID>
```

Xcode 打开 `ios/Runner.xcworkspace`。真机在 Signing & Capabilities 中选择自己的 Team；Bundle ID 默认为 `app.leandaily`，如已被占用需使用自己的 ID。连接 iPhone、信任电脑并启用开发者模式。仓库不包含个人 Team、证书或账号。

```sh
# 编译真机 Release，不签名，不会安装或上传
flutter build ios --release --no-codesign
# 选择自己的签名并准备好商店资料后，才可生成发行包
flutter build ipa --release
```

生成 unsigned build 不代表已完成真机验收、TestFlight 上传或 App Store 审核。

## 原生能力映射

| Native 接口 | iOS 实现 |
| --- | --- |
| all / put | Application Support/LeanDaily/fitness.db，SQLite WAL，串行访问 |
| secretsGet / secretsSet / pruneSecrets | Keychain，仅本设备、解锁可用、不进行同步；新安装清除遗留项 |
| photoWrite / photoRead | 私有 photos 目录、相对路径、原子写入、SHA-256、12MB 上限 |
| http / cancelHttp | 临时 URLSession、HTTPS、拒绝自动重定向、取消、总超时、16MB 响应上限 |
| pickImages | PHPicker / 系统相机；按方向纠正、最长边1600、JPEG 80% |
| exportDocument / importDocument | 系统文件选择器、UTF-8 JSON、100MB 上限 |
| clock / deviceTz / zonedMs / zonedDate | Foundation 公历与 IANA 时区；保持已有记录日期语义 |
| notifyState / requestNotify / schedule / cancel / pendingIds | UserNotifications，本地通知、容量预检、点击回调和冷启动载荷 |
| keepAwake / openUrl | 系统屏幕常亮与外部浏览器 |
| openExactAlarmSettings / minimize | iOS 无对应设置或不允许主动挂起；兼容接口直接完成 |

数据库和照片目录排除系统备份；API Key 不进入 JSON 备份。主动导出到 iCloud Drive 仍会产生用户自行保存的云端文件。照片返回相对路径，避免 iOS 升级造成容器路径变化后无法读取。

## 更新与隐私

- 默认不读取 Android GitHub Releases，不提供 APK 链接。
- 本机开发版重新构建安装；TestFlight 版通过 TestFlight 更新。
- 有独立 iOS 更新 JSON 服务时可用 `--dart-define=LEANDAILY_IOS_UPDATE_URL=https://...` 配置；清单字段沿用 `version/build/url/notes`，下载目标只接受 `apps.apple.com` 或 `testflight.apple.com` 的 HTTPS 链接。
- 相机说明位于 Info.plist；PrivacyInfo.xcprivacy 声明不追踪、不收集。可选识别会按用户操作把照片送往其配置的服务，应在提交商店时按实际发行行为核对隐私信息。
- 不加入 Android 的精确闹钟、开机广播或 iOS 后台常驻权限。锁屏提醒由系统通知投递，专注模式等可能影响显示。

## 自动验证

```sh
flutter analyze
bash tool/lint_tokens.sh
TZ=Asia/Shanghai flutter test
flutter build ios --simulator --debug
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,id=<模拟器ID>' \
  CODE_SIGN_IDENTITY=-
```

RunnerTests 验证真实 Swift SQLite、Keychain、照片与图片处理、网络输入限制、请求预取消、通知安排/查询/撤销；Flutter 测试保护已有业务和 iOS 更新策略。模拟器测试使用本地临时签名（`CODE_SIGN_IDENTITY=-`），不要关闭签名，否则测试宿主可能无法访问 Keychain。通知调度测试在未授权时明确跳过；先在 App 内授权再复验，不能将跳过当作通过。系统选择器交互、相机和实际锁屏投递还需人工/真机检查。

真实 Dart—Swift 通道检查仅允许显式启动的 Debug 模拟器构建：

```sh
flutter run --no-resident -d <模拟器ID> -t tool/ios_smoke.dart \
  --dart-define=LEANDAILY_IOS_SMOKE=true
```

该入口会请求测试通知权限，写入诊断记录和一张测试照片，不读取任何真机数据。运行后查看控制台的 `IOS_SMOKE_PASS`，或模拟器 SQLite 中的 `__ios_smoke_report__`。验证完后重新构建普通入口：`flutter build ios --simulator --debug -t lib/main.dart`。此入口不会被 `lib/main.dart` 或正式 App 自动执行。

## 真机发布前清单

- [ ] 全新安装走完引导，训练/饮食/体重记录关闭重开后仍在。
- [ ] 相机允许、拒绝、取消；HEIC/PNG/JPEG 多选、方向与大图。
- [ ] 从 Android 导出有照片备份，在 iOS 恢复并核对记录；再反向恢复。
- [ ] 文件选择器取消、iCloud Drive 文件下载、导入损坏备份与存储不足。
- [ ] API Key 保存、重启读取、清空；真实用户指定的识别接口及取消/超时。
- [ ] 通知拒绝/允许、锁屏休息提醒、训练提醒、通知点击冷启动及后台返回。
- [ ] iPhone 小屏/大屏、暗色、横屏、键盘、字体放大与减弱动态效果。
- [ ] iPad 布局、相机与文件选择器（若发行包含 iPad）。
- [ ] 真机 Release 启动、升级保留记录、自己的签名与证书。
- [ ] 正式图标、商店截图、支持链接、隐私申报、出口合规及发行渠道配置。

实际执行结果另见 [IOS_VALIDATION.md](IOS_VALIDATION.md)；未勾选的项目不代表已经验证。

当前图标复用 Android 启动图并去除透明通道；`swift tool/ios_icons.swift` 可重新生成。正式商店素材建议提供原始高分辨率图稿。
