# 美区送审前检查 — 2026-10-18

结论：发行构建通路已打通，可以准备送审；仍有后台资料、AI 审核访问和真机验收未确认。此次检查不等于苹果已批准。

## 已核实或完成

- 源码检查基于 main `f3868df`；该提交 GitHub CI 已成功（run 39097266008）。
- 源版本为 2.3.3+24；最近成功上传的 IPA 为 2.3.2 (24)，源提交 cd16a41。后续改动不在这个 IPA 中。
- 已确认运营／发行主体 Skylance LLC，支持邮箱 2436759690@qq.com；README、三语言支持／隐私网页及包内政策已补齐。旧 IPA 的离线政策不会随网页更新，需要新包。
- 本轮关于页／隐私页与三语言回归测试：14 项通过；差异格式检查通过。
- App 内“我的 → 帮助与支持／隐私政策”已有入口。公开网址不要求 GitHub 登录，mailto 邮箱可直接复制或打开邮件客户端。
- Bundle ID com.leandaily.app；自动签名组织 T695TT4HT9；iOS 15+，声明支持 iPhone 和 iPad。
- 现有发行 IPA 签名有效，Xcode 26.3 / iOS 26.2 SDK 已实际上传成功。隐私清单、相机用途说明已在构建中验证；本地通知无需 APNs 权限，系统照片选择器不要求全相册访问。
- App 无登录、广告、统计 SDK 或 HealthKit；AI 需明确授权，可拒绝、撤回，手动记餐不依赖 AI。
- docs/store_metadata.json 三语言名称、标题、宣传文案、说明与关键词长度未超字段上限；此文件为草案，不代表已填到后台。

## 正式提交前必须确认

1. **新包**：包含当前代码和更新政策，使用尚未使用的 build number（下一包至少 25），建议 2.3.3 (25)。App Store Connect 的版本页面与包版本一致。先确认 Apple processing 成功，再选中该构建。
2. **商店链接**：Support URL 填 https://hunter-ght.github.io/LeanDaily/support/ ，Privacy Policy URL 填 https://hunter-ght.github.io/LeanDaily/privacy/ 。英文主链接适用于美区，各语言版本可填对应中文路径。README 并非被禁止，但独立支持页更直接。
3. **隐私问卷**：按 docs/STORE_DATA_SAFETY.md 和 APP_STORE_NEXT_STEPS.md 复核；可选 AI 的照片、说明、营养、服务商账号关联不能忽略。支持邮件是否符合可选披露条件需一并核实；包内隐私清单不会自动填写商店问卷。
4. **审核访问 AI**：核心无登录，但审核员应能测试所声明的 AI 功能。由运营方准备可用、限额、可撤销的审核测试方式，通过 App Review 私密信息提供；Key 不放网页、GitHub 或 IPA。真实请求、额度和模型可用性尚未验收。自定义兼容接口需核实服务条款和数据保护。
5. **真实截图与语言**：填 en-US、zh-Hans、zh-Hant 商店文案，截图对应当前界面。由于支持 iPad，还需按后台要求提供 iPad 截图并验收布局。英文长动作说明仍需逐项校对，避免草稿译文直接发布。不能把宣传动画当作全部设备规格的实际截图。
6. **后台必填**：年龄评级、Health & Fitness 类别、内容版权、组织版权主体、真实审核联系人姓名／电话／邮箱、免费价格、美区可售。由组织 Account Holder 处理待接受协议。确认发布方式，建议首次手动发布。
7. **真机**：至少验收启动／重开保留数据、离线建计划记训练记餐、体重保存、日历和手动输入布局、三语言、大字体、相机／相册允许和拒绝、锁屏提醒、备份导出恢复；恢复操作先备份。iPad 单独验收。不要把模拟器通过当作真机通过。

## 检查范围

本轮检查源码、公开网页内容和 GitHub CI；未登录核验 App Store Connect 当前已填字段、Apple processing 最终状态、年龄评级和隐私问卷答案，未实际操作 iPhone/iPad，也未发出真实 AI 请求。因此以上未知项必须在提交前核对。

## 官方依据

- 支持网址：https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- 审核规范（1.5 联系方式；2.1 完整性；5.1 隐私及 AI 共享授权）：https://developer.apple.com/app-store/review/guidelines/
- 隐私问卷与可选披露：https://developer.apple.com/app-store/app-privacy-details/
