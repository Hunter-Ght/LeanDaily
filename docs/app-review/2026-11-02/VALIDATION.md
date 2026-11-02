# 验证记录（2026-11-02）

候选：2.3.7（33），基于 c0b180a 加本次改动。

## 已确认

- `dart analyze lib test`：No issues found。（`flutter analyze` 在本机因路径含中文“略”导致分析服务崩溃，属于工具问题，与代码无关；CI 在 Linux 上运行该命令。）
- 全量 Flutter 测试（TZ=Asia/Shanghai）：1282 项全部通过，含 iPad 820×1180 / 1180×820 与 iPhone 的 AI 配置、连接测试、授权、取消不发送流程。
- 设计 token lint、Python 发布脚本测试、`git diff --check` 通过。
- OpenAI 预填模型 gpt-6-luna：经 OpenAI 官方文档核实存在，支持图片输入、`/v1/responses`。App 发送格式为 `input_image` + `store:false`。
- Release 归档成功：CFBundleShortVersionString 2.3.7，CFBundleVersion 33，UIDeviceFamily [1,2]，App.framework 为 AOT（无 kernel_blob），四份内置隐私政策与源码逐字节一致，新文案已编译进二进制。

## 未完成 / 不能据此宣称

- **未上传 33**：本机 Xcode 账号凭据失效（`missing Xcode-Username`），只有开发证书，`-exportArchive` 报 `No Accounts` / `No signing certificate "iOS Distribution"`。需用户重新登录 Xcode 后上传。
- 未用真实 API Key 做云端识别；未在 iPadOS 27.0.1 真机验收。
- 在 America/Los_Angeles 时区（2026-11-01 夏令时结束后）运行时，domain_plan_test / domain_models_test 共 14 项失败；未改动的 c0b180a 同样失败，与本次改动无关，待单独排查。
- 公开隐私网页的发布结果见提交后的检查。
- 没有发送审核回复、填写凭据或重新提交审核。
