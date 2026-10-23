import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../config/app_info.dart';
import '../../config/app_links.dart' as links;
import '../../data/update_check.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/markdown_lite.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';

class UpdateDot extends StatelessWidget {
  const UpdateDot({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppMessages.of(context).text('有未查看的新版本'),
    child: Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: context.pal.err,
        shape: BoxShape.circle,
        border: Border.all(color: context.pal.card, width: 2),
      ),
    ),
  );
}

Future<void> handleUpdateTap(BuildContext context) async {
  final app = context.app;
  if (app.updateStatus != UpdateStatus.available) {
    await app.checkUpdate(manual: true);
  }
  if (!context.mounted) return;
  if (app.updateStatus == UpdateStatus.unconfigured) {
    await showAppSheet<void>(context, (_) => const _UpdateUnavailableSheet());
  } else if (app.updateStatus == UpdateStatus.available &&
      app.updateInfo != null) {
    await openUpdateDetails(context);
  }
}

class _UpdateUnavailableSheet extends StatelessWidget {
  const _UpdateUnavailableSheet();
  @override
  Widget build(BuildContext context) => AppSheet(
    title: '检查更新',
    child: Column(
      children: [
        GroupFooter(
          defaultTargetPlatform == TargetPlatform.iOS
              ? '此版本请通过原安装渠道更新。TestFlight 测试版在 TestFlight 中更新，本机开发版需重新安装。'
              : '暂未提供在线更新',
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FormButton(
            '知道了',
            onTap: () => SheetController.of(context).close(),
          ),
        ),
      ],
    ),
  );
}

class UpdateDetailsSheet extends StatelessWidget {
  const UpdateDetailsSheet({super.key, required this.info});
  final UpdateInfo info;
  @override
  Widget build(BuildContext context) => AppSheet(
    title: '更新详情',
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText('新版本 ${info.version}', style: AppText.sect(context.pal)),
          const SizedBox(height: 6),
          LText('当前版本 $appVersion', style: AppText.hint(context.pal)),
          const SizedBox(height: 16),
          MarkdownLite(
            info.notes.isEmpty
                ? AppMessages.of(context).text('此版本暂无更新说明。')
                : info.notes,
            localize: false,
          ),
          const SizedBox(height: 12),
          FormButton(
            '去下载',
            filled: true,
            onTap: () async {
              final app = context.app;
              try {
                await app.native.openUrl(info.url);
              } on Object {
                app.toast.show('暂时无法打开下载页面');
              }
            },
          ),
          const SizedBox(height: 8),
          FormButton('稍后', onTap: () => SheetController.of(context).close()),
        ],
      ),
    ),
  );
}

class AboutPageFrame extends StatelessWidget {
  const AboutPageFrame({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.pal.bg,
    child: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: AppMessages.of(context).text('返回'),
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: Center(
                        child: LText(
                          '‹ 返回',
                          style: TextStyle(
                            fontSize: 17,
                            color: context.pal.tint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LText(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.sect(context.pal),
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, this.onlineUrl = links.privacyPolicyUrl});
  final String onlineUrl;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  Future<String>? _policy;
  String? _language;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = AppMessages.of(context).code;
    if (_language != language) {
      _language = language;
      _policy = rootBundle.loadString('assets/legal/privacy_$language.md');
    }
  }

  @override
  Widget build(BuildContext context) => AboutPageFrame(
    title: '隐私政策',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<String>(
          future: _policy,
          builder: (context, snapshot) => snapshot.hasData
              ? MarkdownLite(snapshot.data!, localize: false)
              : LText(
                  snapshot.hasError ? '暂时无法读取隐私政策，请重新打开。' : '正在读取…',
                  style: AppText.hint(context.pal),
                ),
        ),
        if (widget.onlineUrl.isNotEmpty)
          GroupScope(
            child: GroupCard(
              children: [
                GroupRow(
                  label: '在线查看',
                  onTap: () => openAboutUrl(
                    context,
                    widget.onlineUrl == links.privacyPolicyUrl
                        ? links.localizedPage(
                            widget.onlineUrl,
                            AppMessages.of(context).code,
                          )
                        : widget.onlineUrl,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Future<void> openAboutUrl(BuildContext context, String url) async {
  final app = context.app;
  try {
    await app.native.openUrl(url);
  } on Object {
    app.toast.show('暂时无法打开页面');
  }
}

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});
  @override
  Widget build(BuildContext context) => AboutPageFrame(
    title: '开源与致谢',
    child: GroupScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GroupHeader('感谢这些开源项目'),
          const GroupCard(
            children: [
              GroupRow(
                label: 'free-exercise-db',
                sub: '动作示范图 · Unlicense（公共领域）',
              ),
              GroupRow(label: 'MuscleMap', sub: '人体肌肉图 · Melih Colpan · MIT'),
              GroupRow(label: '得意黑', sub: '字标字体 · SIL OFL 1.1'),
              GroupRow(label: 'Flutter', sub: '界面框架 · BSD 3-Clause'),
              GroupRow(label: '薄肌日课', sub: '本项目 · MIT'),
            ],
          ),
          const GroupHeader('许可证'),
          GroupCard(
            children: [
              GroupRow(
                label: '查看开源许可证',
                onTap: () => openOpenSourceLicenses(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class OpenSourceLicensesPage extends StatefulWidget {
  const OpenSourceLicensesPage({super.key});
  @override
  State<OpenSourceLicensesPage> createState() => _OpenSourceLicensesPageState();
}

class _OpenSourceLicensesPageState extends State<OpenSourceLicensesPage> {
  late final _licenses = LicenseRegistry.licenses.toList();
  @override
  Widget build(BuildContext context) => AboutPageFrame(
    title: '开源许可证',
    child: FutureBuilder<List<LicenseEntry>>(
      future: _licenses,
      builder: (context, snapshot) => snapshot.hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final license in snapshot.data!) ...[
                  LText(
                    license.packages.join(' · '),
                    style: AppText.sect(context.pal),
                  ),
                  const SizedBox(height: 12),
                  for (final paragraph in license.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LText(
                        paragraph.text,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: context.pal.text,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ],
            )
          : LText(
              snapshot.hasError ? '暂时无法读取许可证。' : '正在读取…',
              style: AppText.hint(context.pal),
            ),
    ),
  );
}
