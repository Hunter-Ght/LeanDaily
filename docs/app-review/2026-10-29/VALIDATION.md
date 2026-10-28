# 验证记录

日期：2026-10-29（Asia/Shanghai）。候选版本 2.3.7（32），基于远端 4bb255d。

## 已确认

- Dart 分析：No issues found。
- 全量 Flutter 测试：1282 项通过；新增最后一轮 UI/设置/动画相关测试：51 项通过。
- 5 项 Python 发布脚本测试通过；设计 token lint、git diff --check 通过。
- iPad 820×1180、1180×820 和 iPhone 393×852 的 iOS 界面测试通过。从 AI 页直接进入配置，测试拒绝/同意连接、保存、返回后识别按钮刷新、旧授权仍弹出确认、取消不发送、同意后返回营养结果。
- Mock 响应仅用于自动化；不等于真实服务商识别。连接测试仅为固定文字；不等于支持图像输入的保证。
- iOS 接收方限制在 UI 和数据发送层均执行；Android 兼容选择保持。域名仿冒、HTTP、带账号/查询参数的 URL 不按 OpenAI 官方接口处理。
- Xcode 为 iPad Simulator 编译成功，并在独立 iPad Air 11-inch（M3）/iPadOS 26.3 模拟器安装启动 App。
- 截图：out/shots-plain/review-ai-consent-820.png、review-ai-consent-1180.png、review-ai-consent-393.png（测试数据）。

## 不能据此宣称已通过

- 没有实际 iPad Air M4 / iPadOS 27.0.1 或真实 iPad 验收。
- 没有读取私密 API Key，未发起真实提供商的付费识别；审核专用账号、模型权限、地区、额度和图片能力仍需实测。
- 本地 Xcode 原生 XCTest 首次等待模拟器初始化，串行重试的宿主在建立测试连接前退出（signal kill / never finished bootstrapping）；未通过，不能把编译成功或 App 启动替代原生测试通过。正在空闲模拟器上独立复验。
- IPA 导出、上传、Apple processing、TestFlight 安装与公开审核提交是独立状态；发行结果见 build/ios/ipa/verification.json 和 build/ios/AppStore-build-report.md，以实际日志为准。
- 没有自动发送审核回复、填入密钥或重新提交 App Review。

## 依据

- https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
- https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing
- https://developers.openai.com/api/docs/guides/your-data

第三方保护条款、数据留存和账号可用性需按实际发行配置核对；没有承诺零留存或保证审核通过。
