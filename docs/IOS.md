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

Xcode 打开 `ios/Runner.xcworkspace`。当前发行 Bundle ID 为 `com.leandaily.app`，必须与 Apple Developer 和 App Store Connect 一致；Signing & Capabilities 中选择已获授权的组织 Team，并启用自动签名。证书私钥和账号凭据不入库。使用 Xcode 直连开发测试时，连接 iPhone、信任电脑并启用开发者模式；通过 TestFlight 安装不需要这些步骤。

```sh
# 编译真机 Release，不签名，不会安装或上传
flutter build ios --release --no-codesign
# 选择自己的签名并准备好商店资料后，才可生成发行包
flutter build ipa --release
```

生成 unsigned build 不代表已完成真机验收、TestFlight 上传或 App Store 审核。

## 团队尚无测试设备时生成 App Store IPA

如果 `flutter build ipa --release` 提示团队没有设备、无法生成 iOS App Development 描述文件，可以直接使用两阶段发行流程，无需虚构设备或更换团队：

```sh
python3 tool/build_ios_app_store.py
```

脚本先以 Release 生成未签名归档，再调用 Xcode 的 App Store Connect 自动发行签名导出；只导出，不上传。签名使用 Xcode 已登录账号，Team 默认读取 Runner Release 配置，也可显式传入 `--team-id`。需要该组织的发行签名权限。API 密钥、证书私钥和账号密码均不写入脚本。

输出为 `build/ios/ipa/leandaily.ipa`，归档为 `build/ios/archive/Runner.xcarchive`。中间未签名归档本身不能直接发布，以最终经过发行签名的 IPA 为准。上传成功与 App Store 审核仍需另外完成；每次新上传使用尚未使用的 build number。

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
- 相机说明位于 Info.plist；PrivacyInfo.xcprivacy 声明不追踪，并覆盖可选 AI 的照片、补充说明、膳食营养及服务商账号关联。普通本机资料和训练记录不上传。正式商店问卷仍需按实际发行行为核对，不能填写“完全不收集”。
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

## iOS 26 底部原生标签栏

- iOS 手机底栏相对原位置下移 8pt（底部边距为 `max(10, safe.bottom - 8)`），休息条沿用同一基准同步下移；无底部安全区时保留 10pt 最小边距，Android/Web 不变。

- 只有手机布局的底部四标签 Dock 使用 `IosDockGlass`。宽屏竖栏、顶部圆按钮、休息条、训练页按钮及通用 `GlassSurface` 保持原实现。
- Swift 使用 `#available(iOS 26.0, *)` 返回能力；Dart 通过 UIKit Platform View 嵌入完整的系统 `UITabBar`，保留系统默认外观和选中交互。没有自绘选中块或给系统标签栏覆盖自定义玻璃背景。不解析系统版本字符串、不加插件，部署目标仍为 iOS 15。
- Android/Web 不调用原生探测。旧 iOS、原生桥不可用或探测失败继续使用原来的 `GlassSurface`；Android 的静态玻璃策略不变。
- 原生标签栏负责按钮、选中效果、触感和系统无障碍。四个图标复用 Flutter `AppIcon` 的同一绘制器，输出普通／选中两套 3x 透明 PNG 模板给 UIKit 着色；不使用 SF Symbols 替换原图标。Flutter 管理当前页面，并同步四个本地化标题、选中索引、主题色、深浅色及“我的”更新提示。每个平台视图有独立 MethodChannel，销毁时移除回调。
- 冷启动时必须在创建 `UITabBarItem` 时就带上本地化标题，再将 items 安装到标签栏。先安装空标题、随后修改 `title` 会让未选中项缓存为仅图标布局，文字偏低，直到点击才恢复。原生回归测试模拟零尺寸创建后再挂载，并在没有点击的情况下检查四个标题的底边对齐。
- Flutter 弹窗会对底层场景做缩放与模糊；原生视图叠加该过程可能出现矩形亮块。`sheetDepth > 0` 的完整弹窗动画期间回退原有 Dock，完全关闭后以当前选中页重建原生标签栏。
- 这是嵌入现有 Flutter 页面导航的原生标签栏，没有接入 UIKit 滚动收缩导航模式。实际折射和交互表现由系统、背景及辅助功能设置决定。
- 编译需要 iOS 26 SDK（当前 Xcode 26.3 / SDK 26.2）。旧系统路径通过能力响应回归测试覆盖，实际 iOS 15–25 和 iPhone 真机外观／性能仍需验收。底栏效果已随 2.3.4 (26) 上传；动作图片加载修复包含在 2.3.5 (27) 中，需安装对应构建体验。

## 动作示范冷加载

手机 `SheetGuideBody` 和宽屏 `GuideBody` 复用 `GuideImage`：首次解码前保持 3:2 占位，预加载两帧，等待下一帧时保留旧图，仅第一帧淡入。切换不同动作时重置旧图，避免显示上一动作。

`test/guide_image_loading_test.dart` 独立延迟两张真实图片，覆盖 Android/iOS、深浅色和两种页面，检查加载前后占位、文字相对位置与下一帧等待期间的可见图片。不能用预先缓存全部图片的截图测试替代这组验证。
