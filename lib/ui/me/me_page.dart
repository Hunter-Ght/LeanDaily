import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_controller.dart';
import '../kit/menu.dart';
import '../../config/app_info.dart';
import '../../config/app_links.dart' as links;
import '../kit/form.dart';
import 'about_pages.dart';
import '../../app/routes.dart';
import '../../theme/theme.dart';
import '../kit/grouped.dart';
import '../kit/wordmark.dart';
import 'profile_card.dart';

class MePage extends StatelessWidget {
  const MePage({super.key, required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final latest = app.bodyEntries.lastOrNull;
    final plan = app.plans
        .where((e) => e['id'] == app.activePlanId)
        .firstOrNull;
    return SingleChildScrollView(
      key: const PageStorageKey('me-scroll'),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 52,
        bottom: wide ? 24 : 104 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: LText('我的', style: AppText.navDay(p)),
              ),
              const ProfileCard(),
              const GroupHeader('训练'),
              GroupCard(
                children: [
                  GroupRow(
                    label: '当前计划',
                    value: '${plan?['name'] ?? app.plan['name'] ?? '我的计划'}',
                    icon: 'calendar',
                    iconColor: p.tint,
                    onTap: () => openPlanEditor(context),
                  ),
                  GroupRow(
                    label: '浏览训练模板',
                    icon: 'train',
                    iconColor: p.ok,
                    onTap: () => openTemplateBrowser(context),
                  ),
                ],
              ),
              const GroupHeader('身体'),
              GroupCard(
                children: [
                  GroupRow(
                    label: '记体重和腰围',
                    value: latest == null
                        ? null
                        : '${(latest['weightKg'] as num).toStringAsFixed(1)} kg',
                    icon: 'chart',
                    iconColor: p.kcal,
                    onTap: () => openBodyLog(context),
                  ),
                  GroupRow(
                    label: '我的资料与目标',
                    icon: 'me',
                    iconColor: p.protein,
                    onTap: () => openProfile(context),
                  ),
                ],
              ),
              const GroupHeader('设置'),
              GroupCard(
                children: [
                  GroupRow(
                    label: '每日目标与休息',
                    icon: 'note',
                    iconColor: p.detrain,
                    onTap: () => openGoals(context),
                  ),
                  GroupRow(
                    label: '语言',
                    icon: 'language',
                    iconColor: p.tint,
                    value: switch (app.languagePreference) {
                      'en' => 'English',
                      'zh_Hans' => '简体中文',
                      'zh_Hant' => '繁體中文',
                      _ => '跟随系统',
                    },
                    onTap: () async {
                      final selected = await showActionMenu(
                        context,
                        title: '语言',
                        actions: const [
                          MenuAction(id: 'system', label: '跟随系统'),
                          MenuAction(id: 'en', label: 'English'),
                          MenuAction(id: 'zh_Hans', label: '简体中文'),
                          MenuAction(id: 'zh_Hant', label: '繁體中文'),
                        ],
                      );
                      if (selected != null) {
                        try {
                          await app.setLanguage(selected.id);
                        } catch (_) {
                          app.toast.show('语言设置未保存，请重试');
                        }
                      }
                    },
                  ),
                  GroupRow(
                    label: '提醒',
                    icon: 'calendar',
                    iconColor: p.protein,
                    onTap: () => openPlanEditor(context),
                  ),
                ],
              ),
              const GroupHeader('数据'),
              GroupCard(
                children: [
                  GroupRow(
                    label: '备份与高级',
                    sub: '备份恢复 · 拍照识别',
                    icon: 'note',
                    iconColor: p.kcal,
                    onTap: () => openAndroidSettings(context),
                  ),
                ],
              ),
              const GroupHeader('关于'),
              GroupCard(
                children: [
                  const GroupRow(label: '薄肌日课', value: appVersion),
                  GroupRow(
                    label: '检查更新',
                    value: app.updateStatus == UpdateStatus.available
                        ? '有新版本 ${app.updateInfo!.version}'
                        : app.updateUrl.isEmpty
                        ? (defaultTargetPlatform == TargetPlatform.iOS
                              ? '通过安装渠道更新'
                              : '未配置')
                        : app.updateStatus == UpdateStatus.checking
                        ? '正在检查…'
                        : app.updateStatus == UpdateStatus.upToDate
                        ? '已是最新版本'
                        : null,
                    trailing: app.hasUnseenUpdate ? const UpdateDot() : null,
                    onTap: () => handleUpdateTap(context),
                  ),
                  if (defaultTargetPlatform != TargetPlatform.iOS ||
                      app.updateUrl.isNotEmpty)
                    GroupRow(
                      label: '启动时自动检查更新',
                      trailing: FormSwitch(
                        label: '启动时自动检查更新',
                        value: app.settings.value['autoUpdateCheck'] != false,
                        onChanged: app.setAutoUpdateCheck,
                      ),
                    ),
                  GroupRow(label: '隐私政策', onTap: () => openPrivacy(context)),
                  GroupRow(
                    label: '帮助与支持',
                    onTap: () => openAboutUrl(
                      context,
                      links.localizedPage(links.supportUrl, app.messages.code),
                    ),
                  ),
                  GroupRow(label: '开源与致谢', onTap: () => openCredits(context)),
                  if (links.repoUrl.isNotEmpty)
                    GroupRow(
                      label: '项目主页',
                      onTap: () => openAboutUrl(context, links.repoUrl),
                    ),
                ],
              ),
              const GroupFooter('免费，没有广告。记录保存在本机；AI 识别需另行授权。'),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Center(child: Wordmark(fontSize: 22)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
