# 架构

LeanDaily 是一个 **Flutter + 极薄 Android 原生层** 的本地优先应用。目标：业务规则是纯 Dart、可单测；界面不含业务计算；原生代码只做平台能力。

## 分层

```
┌────────────────────────────────────────────────────┐
│ ui/        界面（Widget）。只读 AppController，调用其方法 │
├────────────────────────────────────────────────────┤
│ app/       AppController（ChangeNotifier）、路由、外壳     │
├──────────────────────┬─────────────────────────────┤
│ data/      存储与服务    │ domain/   纯 Dart 业务规则        │
│ 仓库、备份、提醒、识别…  │ 计划/进阶/肌肉/饮食/趋势/回顾     │
├──────────────────────┴─────────────────────────────┤
│ core/      Native 接口（MethodChannel）+ FakeNative（测试）   │
├────────────────────────────────────────────────────┤
│ android/   Java：SQLite 文档存储、通知闹钟、照片、HTTP、密钥     │
└────────────────────────────────────────────────────┘
```

- **`domain/`**：全部是对 `Map<String, dynamic>`（JSON 形状）做纯函数计算，不依赖 Flutter、不碰磁盘。例如 `progress.dart`（进阶）、`body.dart`（热量/蛋白/体脂路线）、`plan_insight.dart`（一周条与人体图所需数据）、`weekly_review.dart`。
- **`data/`**：`Repository` 是本地优先的记录仓库（串行写入，写前读最新）；`PlanStore`/`ProfileStore`/`BodyLogStore` 各管一份文档；`backup.dart` 负责导出导入；`update_check.dart` 检查更新；`vision.dart` 是可选的拍照识别。
- **`app/AppController`**：把各存储、当前日期/标签、计划库、资料与目标、体重记录、更新状态汇总成一个 `ChangeNotifier`，界面只监听它。
- **`ui/`**：`kit/` 是通用控件（`Pressable`、`GlassSurface`、分组列表 `GroupCard/GroupRow`、方案卡 `PlanCard`、转场 `Reveal/PushSwitcher/FadeSwitcher`…），其余按页面分目录。界面不使用 Material 控件，颜色全部来自 `theme/tokens.dart`（`tool/lint_tokens.sh` 强制检查）。
- **`core/native.dart`**：原生能力的接口；测试里用 `FakeNative` 完全替换，所以全部测试都不需要真机。

## 数据存储

SQLite 里一张 `documents(key, value)` 表，一个键一份 JSON 文档：

| 键 | 内容 |
| --- | --- |
| `android-state` | 训练组、饮食、每日摘要等记录 |
| `android-settings` | 时区、触感、拍照识别配置（密钥另存加密） |
| `fw-plans-v1` | 计划库（多份计划，使用中的一份） |
| `fw-plan-v1` | 使用中计划的副本（兼容旧版读取） |
| `fw-plan-day-v1` | 每天的临时调整（状态、精简、改练、场地、替换动作） |
| `fw-progress-v1` | 进阶状态：锚点、升阶、已拒绝建议、减载记录 |
| `fw-profile-v1` / `fw-targets-v1` | 个人资料；目标体脂/热量/蛋白覆盖与评估起点 |
| `fw-body-v1` | 体重与腰围记录 |
| `fw-goals-v1` / `fw-rest-v1` | 每日目标；休息计时偏好 |
| `fw-review-v1` / `fw-hints-v1` | 周回顾已处理的周；各类一次性提示（场地、体重提醒、更新检查） |
| `fw-onboarded-v1` / `fw-plan-legacy-v1` | 是否完成引导；升级前计划快照 |

导出备份时把这些文档和照片打成一个 JSON（格式标识 `leandaily-backup`，导入同时接受旧标识 `lianchiji-backup`）。**照片和密钥不进云备份**（`allowBackup=false`）。

写入原则：记录读-改-写在同一个串行队列里；计划库多文档写入失败会回滚；不能原子写多文档的地方（原生层不提供事务）在代码里有注释说明。

## 为什么用"金标"测试

早期版本有一套经过实机验证的 JS 实现。移植到 Dart 时，用旧实现生成了一批输入输出对照数据放在 [`test/golden/`](../test/golden)，Dart 实现必须逐项一致（数值误差 1e-6 内）。这让大规模改界面时领域规则不会悄悄漂移。后来新增的规则（经验分档、减载、器材步长…）都用选项显式开启，**不传选项时行为与金标逐位一致**，新行为由单独的测试和 26 周模拟覆盖。

## 测试

```bash
TZ=Asia/Shanghai flutter test       # 全量；必须固定时区
flutter test test/progression_sim_test.dart
```

- 域规则：单元测试 + 金标；
- 界面：`test/support/harness.dart` 用 `FakeNative` 拉起完整 App，支持亮/暗、不同尺寸、新老用户数据，并能写出 `out/shots/*.png` 截图；
- 动画：`test/motion_*` 检查转场的中间帧不是瞬切、减弱动态效果下直接切换；
- 安卓包：`tool/check_apk.py` 发布前检查（ELF 区段表完整、没有夹带调试信息、体积上限）。

## Android 原生层

[`android/app/src/main/java/app/leandaily`](../android/app/src/main/java/app/leandaily)：`Storage`（SQLite 文档）、`Secrets`（Keystore 加密 API 密钥）、`Photos`（私有目录照片）、`Notifier`/`AlarmReceiver`/`BootReceiver`（精确闹钟提醒与开机恢复）、`Http`（强制 HTTPS）、`Images`（压缩缩放）、`NativeChannel`（MethodChannel `leandaily/native`）。

**注意**：发布构建必须关闭 R8 混淆。Flutter 引擎按类名回调 `FlutterJNI`，被混淆后引擎无法启动，表现为一直停在启动图。
