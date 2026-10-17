# iOS 首版验证记录

日期：2026-10-17。工作分支：`codex/ios-native`。

结论：方案 A 的 iOS 工程和 Swift 原生层已实现，普通入口可以在 iPhone 模拟器运行；无签名真机 Release 编译通过。尚未完成真实 iPhone 验收和正式发行。

## 环境

- Flutter 3.47.6 / Dart 3.13.5，与项目锁定版本一致。
- Xcode 26.3（17C529），构建使用安装的 iPhoneOS / iPhoneSimulator SDK。
- 运行：iOS 26.3.1（23D8133），专用 iPhone 16e 模拟器 `LeanDaily iOS Test`。
- 设备 ID：`05D10134-15E6-4810-93F9-F08A3098BB96`。
- 最低部署版本：iOS 15.0。没有配置个人开发者 Team、证书或 App Store 账号。

## 已执行

| 项目 | 结果 | 本机证据（out/ios 不入库） |
| --- | --- | --- |
| Dart 静态分析 | 无问题 | dart-analyze.log |
| 设计令牌检查 | 通过 | lint.log |
| Flutter 全量回归，固定上海时区、并发2 | 1137 项全部通过 | flutter-test-final.log |
| Swift 原生 XCTest，模拟器临时签名 | 12 项全部通过，无跳过 | native-tests-final.log / native-tests-final.xcresult |
| 实际 Dart—Swift 平台通道 | 18 项全部通过 | smoke-report.json |
| 普通入口 Debug 模拟器构建 | 通过 | build-simulator-final.log |
| 普通入口真机 Release，不签名 | 通过，工具报告22.6MB | build-device-release-final.log |
| 发布工具原有 Python 测试 | 5 项通过 | release-tools-test.log |
| Info.plist、隐私清单、工程配置格式 | 通过 | plutil 本机检查 |
| 普通版本覆盖安装前后数据 | 5 份核心文档与1张照片 SHA-256 完全一致 | persistence-before.json / persistence-after.json |

原生 XCTest 覆盖大段中文与 Emoji 数据重开、拒绝未来数据库版本、Keychain 更新/清空/重装隔离、照片相对路径及容器迁移、图片缩放，以及 HTTPS 输入限制、multipart 编码、响应与响应大小限制、总超时、预取消、授权后的通知安排和撤销。

网络成功响应、multipart、大小限制和超时用 URLProtocol 提供可控响应；这验证原生传输代码，不等于已经接通用户的识别服务。

18项真实通道检查包括 IANA/DST 换算、非法日期和时区、SQLite 大段中文读写、Keychain、照片字节和跨语言 SHA-256、路径越界拒绝、HTTP 拒绝/取消、系统通知授权与调度/撤销、屏幕常亮调用。诊断入口仅限显式开启的 Debug 模拟器构建；验证后已经恢复 `lib/main.dart` 普通入口。

## 已实际操作的界面

- 完整四步新手引导，创建推荐训练计划。
- 今日、记录、进度、我的四页；浅色和深色首页。
- 选择食物并保存示例饮食记录；首页和记录页显示111千卡、蛋白25.5g。
- 系统 PHPicker 选择测试图片，回到 App 预览，保存到饮食记录；普通构建重装后仍可显示照片。
- 相机权限弹窗显示正确用途说明；拒绝权限后 App 提示原因，原有记录与界面继续可用。实际拍摄仍待真机验证。
- 系统文件选择器导出含照片备份到模拟器“我的 iPhone”，再选中该文件恢复。
- 导出文件格式为 `leandaily-backup`，包含1条饮食、1张照片；照片哈希全部正确，普通设置不含 API Key。
- 恢复后照片改用新的本地相对路径；替换为普通构建、关闭重开后记录和照片仍在。

这些记录和照片是专用模拟器里的测试数据，不是用户的真实身体/饮食资料。

截图：`out/ios/onboarding.png`、`today.png`、`today-dark.png`、`log.png`、`stats.png`、`me.png`、`photo.png`。

## 尚未验证 / 尚未发行

- 真实 iPhone 的相机权限允许/拒绝、实际拍摄与 HEIC/大图组合。
- 真机锁屏、专注模式、重启后的实际提醒呈现，以及通知点击的完整系统链路。Flutter 冷/热启动通知路由已有自动测试。
- 用户真实识别服务的端到端请求（没有用户提供的接口密钥）。
- Android 与 iOS 两台真实设备的双向备份迁移；现有备份格式、业务测试及 iOS 自身导出/恢复已经验证。
- iPad 真机/模拟器、不同真实 iOS 版本、存储不足、iCloud 文件下载及真实升级发行路径。
- 个人签名、TestFlight 上传、商店隐私表、商店截图及审核。

## 本机工具问题及处理

- `flutter analyze` 在本机包含中文的路径下，分析服务初始化出现 JSON 消息截断；同一 SDK 的 `dart analyze` 完整通过。未改动 SDK 来绕过检查。
- 首次原生测试关闭了签名，Keychain 因而无法访问；改为模拟器本地临时签名后通过。CI 和开发说明已经采用该方式。
- 通知未授权时系统调度测试明确跳过；本次先通过系统弹窗授权，再执行最终12项测试，最终没有跳过。
- 原有模拟器安装服务一度无响应；没有清除原设备数据，改用专用新模拟器完成验证。首次系统初始化用时约3分钟。

构建与后续真机清单见 [IOS.md](IOS.md)。
