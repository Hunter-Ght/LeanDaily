# 美区上架下一步：组织账号 + App Manager

核对日期：2026-10-17。本文是当前发行行为的准备说明，不表示已经签名、上传或得到苹果批准。用户已确认：使用朋友的组织开发者账号，自己的角色是 App Manager。

## 1. 先打通团队权限

登录 https://appstoreconnect.apple.com/ ，在组织团队下操作。请 Account Holder 或 Admin 在“Users and Access / 用户和访问”里确认：

- 你是 App Manager，并且能访问 LeanDaily；如果尚未创建 App，确认你能创建 App 记录。
- 额外授予 **Certificates, Identifiers & Profiles** 权限。App Manager 不一定默认拥有它。
- 如果 Xcode 上传提示需要 cloud-managed distribution certificate 权限，由管理员再授予相应权限，或由组织负责人完成签名上传；不要共享朋友的 Apple 密码。
- 协议如果显示待接受，由 Account Holder 接受。App Manager 不能代签全部法律协议。

使用这个团队发行，App 所属和商店销售者身份归该组织。不要以为加入团队后就成为自己个人名下的 App。

## 2. 创建 App 记录

在 Apple Developer 的 Certificates, Identifiers & Profiles 注册明确的 App ID / Bundle ID。项目初始值是 `app.leandaily`；以本机 Xcode 最终配置和组织实际注册的 ID 为准，先检查能否注册及是否属于该组织，不要直接假设可用。确定后，让 Xcode、App Store Connect、项目配置使用同一个 ID。

App Store Connect → My Apps / App → ＋ → New App：

- Platform：iOS。
- Name：从 `docs/store_metadata.json` 的英文草案开始，实际名称须可用。
- Primary language：English (U.S.)。
- Bundle ID：选刚注册的 ID。
- SKU：组织内部唯一编号，例如 `leandaily-ios`，不是商店展示名称。
- User access：按组织需要设置。

先创建 App 记录，再上传构建。可售地区之后设为 United States。App 的三种 UI 语言不限制销售地区。

### Register an App ID 的 Capabilities

当前代码不需要主动勾选额外 Capabilities，页面系统默认项保持默认。Push Notifications、iCloud、HealthKit、Sign in with Apple、App Groups、Keychain Sharing、Associated Domains、Background Modes 都无需为本版额外开启。提醒由本地 UserNotifications 安排，不向 APNs 注册。普通本设备 Keychain 存储不需要 Keychain Sharing。相机、系统照片选择器和 HTTPS AI 请求也不在这张列表申请权限；相机说明已在 Info.plist 配好，App 会在使用时申请相机/通知权限。

注册时使用 Explicit Bundle ID。以你最终注册的值为准，并确保与 Xcode 和 App Store Connect 一致；能力以后需要时可以再补，不必提前全开。

## 3. Xcode 签名与上传

1. Xcode → Settings → Accounts，添加你自己的 Apple Account，确认能看到朋友的组织 Team。
2. 打开 `ios/Runner.xcworkspace`，选择 Runner target → Signing & Capabilities。
3. 勾选 Automatically manage signing，Team 选组织，Bundle Identifier 与上一步相同。不要选择 Personal Team。
4. 发行前增加 build number；当前源版本为 `2.3.2+23`，每次新上传使用未用过的 build number。
5. 真机先跑核心流程。然后选 Any iOS Device (arm64) / Generic iOS Device，Product → Archive。
6. Organizer 中先 Validate App，查看 Generate Privacy Report，核对 App 和 Flutter 清单，再 Distribute App → App Store Connect → Upload。
7. 上传成功还需苹果 processing；完成后才会在 TestFlight 出现。

2026-10-17 已生成组织发行签名的 App Store IPA，并成功上传 `com.leandaily.app` 的 `2.3.2 (23)`；Xcode 确认 `Upload succeeded`。苹果服务器已开始 processing，处理完成和 TestFlight 真机安装仍需确认。此操作未提交公开上架审核。后续上传需使用新的 build number。

## 4. 先做内部 TestFlight

App Store Connect → LeanDaily → TestFlight → Internal Testing → 创建测试组，把你自己等有 App 访问权的团队成员加进去，选择已处理的 build。iPhone 安装苹果的 TestFlight，再接受邀请安装。

用你自己的 iPhone 操作：

1. 等 `2.3.2 (23)` 处理完成；如果处理失败，先查看苹果给出的具体错误，不要重复上传相同 build number。
2. 在 Internal Testing（内部测试）旁点 `+`，创建“个人测试”组。若已有只供你使用的组，可直接复用。
3. 点 Invite Testers（邀请测试员），选择你自己的 App Store Connect 用户；App Manager 且有本 App 访问权即可。再点 Add Builds（添加构建版本），选择 `2.3.2 (23)`。填写本轮测试内容后添加。
4. iPhone 从 App Store 安装苹果官方 TestFlight。在手机上打开发到你团队账号邮箱的测试邀请，接受后安装 LeanDaily。
5. TestFlight 不需要数据线、设备 UDID 注册或开发者模式。测试版本有效期 90 天；后续新版本通过 TestFlight 更新。

先检查启动、离线记训练/饮食、三语言、手动输入排版、相机与相册权限、锁屏提醒，以及关闭后重开数据是否保留。如果手机已有本 App 的重要记录，先导出备份，不要为测试直接删 App。AI 可最后用自己的 API Key 测试，不要把 Key 发给其他人。

普通朋友不需要加入开发团队；以后走 External Testing，填写测试信息并提交 Beta App Review。不要为了测试把所有朋友都变成 App Manager。

每种语言至少检查：新安装与重新打开、离线建计划、训练记组、份量计算、拍照/相册（含拒绝权限）、API 无 Key/无额度/超时、拒绝与撤回 AI 授权、切换地址后重新征求同意、备份导出恢复、锁屏提醒、横竖屏、大字体。当前声明支持 iPad，也需 iPad 验收。先备份；删除 App 会删除本机记录，TestFlight 不是数据同步服务。

使用自己合法可用的 OpenAI API Key 和 API 额度测试，不要把 Key 发到 GitHub、截图或聊天。App 的范例不是赠送服务，也不是实时可用性承诺。没有 Key 时可继续手动记餐。

## 5. 隐私问卷怎么填

位置：App Store Connect → App → App Privacy。隐私 URL 用 https://hunter-ght.github.io/LeanDaily/privacy/ 。支持 URL 用 https://hunter-ght.github.io/LeanDaily/support/ 。英文入口均公开可读，不需 GitHub 登录。

当前含可选 AI，不能直接选“Data Not Collected”。OpenAI 的默认滥用监测可能留存请求内容；`store=false` 不消除该留存。也不能因为 App 无账号，就填全部“不关联身份”：用户自己的 API Key 会关联服务商账号。

对目前按默认 OpenAI API 行为及可配置自定义服务发行的版本，准备以下保守申报，并在正式提交前结合审核用服务账号、实际数据政策复核：

| 类型 | 为什么 | 用途 | 与身份关联 | 追踪 |
| --- | --- | --- | --- | --- |
| User Content → Photos or Videos | 主动选择的饮食照片 | App Functionality | Yes，可能关联服务商账号 | No |
| User Content → Other User Content | 餐次、补充说明 | App Functionality | Yes | No |
| Health & Fitness → Health | 膳食营养信息及识别结果；不表示上传全部身体资料 | App Functionality | Yes | No |
| Identifiers → User ID | 服务商账号认证及关联；App 自己不创建账号 | App Functionality | Yes | No |
| Other Data Types | 服务商可能留存的 IP / 请求网络元数据；不推导位置 | App Functionality（服务安全） | Yes | No |

包内 PrivacyInfo.xcprivacy 与上表保持一致。不添加广告、营销、数据经纪人或跨 App 广告归因用途；当前不实施追踪。纯本机的体重、腰围和训练记录没有上传，不因本机保存而全部声明为收集。没有位置、通讯录、麦克风、HealthKit 权限；不为申报而新增权限。

上表不是法律结论或已提交的问卷。自定义服务如另做训练、营销或位置推断，必须重新审查；“OpenAI 兼容”不等于 OpenAI 官方，更不自动满足苹果要求。采用不同服务商或数据控制配置时，复核问卷、政策、包内清单和授权文案四者。

## 6. 上架资料

- 三语言商店文案草案：`docs/store_metadata.json`。UI 翻译和商店语言分别配置。
- 类别建议 Health & Fitness；定位一般健身记录，不做医疗诊断、治疗或准确率承诺。
- 按 App Store Connect 当前要求做实际界面截图，覆盖声明支持的 iPhone / iPad，展示训练、饮食和进度；README 宣传图不能直接当成所有尺寸的商店截图。
- 年龄评级按当前问卷如实填写，不把“不面向儿童”误当作年龄评级答案。未成年人及健康建议另行审查。
- 填组织真实版权主体、审核联系人姓名/电话/邮箱。现有公开 GitHub Issues 能提供支持，但建议另加专用支持邮箱，供不愿公开健康信息的人联系。尚未取得真实邮箱和主体资料，不要编造。
- 免费定价、美区可售、手动发布。确认隐私答案和数据政策一致。
- 审核说明写明：核心离线、无需 App 登录、AI 可选、配置路径、照片如何发送、如何拒绝及撤回授权。审核员需要可以测试全部声明功能；由组织确定安全的审核测试方式，例如独立、最小权限、可撤销并监控费用的测试服务账号，通过 App Review 的私密渠道提供必要信息，发布包不内置共用 Key。不得提供假的成功结果或仅对审核隐藏功能。
- 保留正式 OpenAI 和自定义服务条款核验、英文长训练说明人工校对、真机验收作为送审前门槛。范例配置与自动化测试不代表这些门槛已完成。

## 官方依据

- 组织 App Manager 与证书额外权限：https://developer.apple.com/help/glossary/app-manager/
- 角色和协议权限：https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/
- 创建 App：https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
- 上传构建：https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- 内部 TestFlight：https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/
- 隐私定义：https://developer.apple.com/app-store/app-privacy-details/
- 审核准则：https://developer.apple.com/app-store/review/guidelines/
- OpenAI API 数据控制：https://developers.openai.com/api/docs/guides/your-data
- 示例图片输入模型：https://developers.openai.com/api/docs/models/gpt-6-luna
