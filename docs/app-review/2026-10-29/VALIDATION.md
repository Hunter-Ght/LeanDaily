# 验证记录

日期：2026-10-29（Asia/Shanghai）。候选版本 2.3.7（32），基于远端 4bb255d。

## 已确认

- Dart 分析：No issues found。
- 全量 Flutter 测试：1282 项通过；新增最后一轮 UI/设置/动画相关测试：51 项通过。
- 5 项 Python 发布脚本测试通过；设计 token lint、git diff --check 通过。
- iPad 820×1180、1180×820 和 iPhone 393×852 的 iOS 界面测试通过。从 AI 页直接进入配置，测试拒绝/同意连接、保存、返回后识别按钮刷新、旧授权仍弹出确认、取消不发送、同意后返回营养结果。
- Mock 响应仅用于自动化；不等于真实服务商识别。连接测试仅为固定文字；不等于支持图像输入的保证。
- iOS 接收方限制在 UI 和数据发送层均执行；Android 兼容选择保持。域名仿冒、HTTP、带账号/查询参数的 URL 不按 OpenAI 官方接口处理。
- Xcode 为 iPad Simulator 编译成功，并在独立 iPad Air 11-inch（M3）/iPadOS 26.3.1 模拟器安装启动 App。
- 独立 iPad 原生 XCTest 最终结果：13 项通过、0 失败、1 跳过；跳过项为 testNotificationSchedulePendingAndCancel（模拟器未授权通知），不计作通过。结果包：Test-Runner-2026.10.29_02-04-15-+0800.xcresult。
- Apple 已于 2026-10-29 02:07:39（Asia/Shanghai）确认上传成功，并开始 processing；尚未确认处理完成或 TestFlight 安装。
- 已生成并校验 App Store IPA 2.3.7（32），SHA-256 6eb0404b5d3f29035d640d69ed5751ac6770e72fe8c6829f6c4d5c24e8045d0f，包内三语言隐私政策与源码一致；支持 iPhone/iPad。
- 三个公开隐私页均实际返回 HTTP 200，响应正文与 website/privacy/ 的新版源文件字节一致。
- 截图：out/shots-plain/review-ai-consent-820.png、review-ai-consent-1180.png、review-ai-consent-393.png（测试数据）。

## 不能据此宣称已通过

- 没有实际 iPad Air M4 / iPadOS 27.0.1 或真实 iPad 验收。
- 没有读取私密 API Key，未发起真实提供商的付费识别；审核专用账号、模型权限、地区、额度和图片能力仍需实测。
- 首次 Xcode 原生测试等待模拟器初始化、一次重试宿主在连接前终止；最终在初始化完毕的独立 iPad 串行复验通过。通知调度因未授权跳过，仍需真机允许通知后检查锁屏投递。
- IPA 导出、上传、Apple processing、TestFlight 安装与公开审核提交是独立状态；发行结果见 build/ios/ipa/verification.json 和 build/ios/AppStore-build-report.md，以实际日志为准。
- 没有自动发送审核回复、填入密钥或重新提交 App Review。

## 依据

- https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
- https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- https://developers.openai.com/api/docs/guides/your-data

第三方保护条款、数据留存和账号可用性需按实际发行配置核对；没有承诺零留存或保证审核通过。
