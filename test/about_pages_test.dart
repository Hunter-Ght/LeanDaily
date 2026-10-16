import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/data/update_check.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/kit/grouped.dart';
import 'package:leandaily/ui/kit/markdown_lite.dart';
import 'package:leandaily/ui/me/about_pages.dart';
import 'package:leandaily/ui/me/me_page.dart';

import 'support/harness.dart';

const constUpdate = UpdateInfo(
  version: '2.4.0',
  build: 25,
  url: 'https://example.test/app.apk',
  notes: '## 本次更新\n\n- 训练记录更清晰\n- 改进离线体验',
);
void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await rootBundle.loadString('assets/legal/privacy.md');
  });
  Future<void> tapVisible(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('关于/更新/隐私/致谢截图 $mode', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        dark: dark,
        size: const Size(393, 852),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode({
            'age': 30,
            'weightKg': 72,
            'bodyFatPct': 20,
            'bodyFatMethod': 'manual',
          });
        },
      );
      // 测试种子只模拟已发现的更新，不触发网络。
      h.controller.updateInfo = constUpdate;
      h.controller.updateStatus = UpdateStatus.available;
      h.controller.setTab(0);
      h.controller.setTab(3);
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDot), findsNWidgets(2));
      await h.shot(tester, 'r-dock-dot-$mode');
      await tester.ensureVisible(find.text('开源与致谢'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GroupRow, '薄肌日课'), findsOneWidget);
      for (final label in ['检查更新', '启动时自动检查更新', '隐私政策', '开源与致谢']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('项目主页'), findsNothing);
      await h.shot(tester, 'r-about-$mode');
      await tapVisible(tester, '检查更新');
      expect(h.controller.hasUnseenUpdate, isFalse);
      expect(find.byType(UpdateDot), findsNothing);
      expect(find.text('新版本 2.4.0'), findsOneWidget);
      await h.shot(tester, 'r-update-sheet-$mode');
      await tester.tap(find.text('去下载'));
      await tester.pumpAndSettle();
      expect(h.native.opened, ['https://example.test/app.apk']);
      await tapVisible(tester, '稍后');
      await tapVisible(tester, '隐私政策');
      expect(find.byType(PrivacyPage), findsOneWidget);
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/legal/privacy.md');
      });
      await tester.pumpAndSettle();
      expect(find.text('一句话版本'), findsOneWidget);
      expect(find.text('在线查看'), findsNothing);
      expect(find.byType(GroupCard), findsWidgets);
      await h.shot(tester, 'r-privacy-$mode');
      final table = find.text('权限');
      await tester.ensureVisible(table);
      await tester.pumpAndSettle();
      expect(find.text('网络'), findsOneWidget);
      await h.shot(tester, 'r-privacy-table-$mode');
      await tapVisible(tester, '‹ 返回');
      await tapVisible(tester, '开源与致谢');
      expect(find.text('free-exercise-db'), findsOneWidget);
      expect(find.text('得意黑'), findsOneWidget);
      await h.shot(tester, 'r-license-$mode');
      await tapVisible(tester, '查看开源许可证');
      expect(find.byType(OpenSourceLicensesPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('未配置说明、自动检查开关和引导入口', (tester) async {
    final h = await Harness.pump(tester, tab: 3);
    await tapVisible(tester, '检查更新');
    expect(find.text('暂未提供在线更新'), findsOneWidget);
    expect(h.native.httpLog, isEmpty);
    await tapVisible(tester, '知道了');
    final toggle = find.byWidgetPredicate(
      (w) => w is FormSwitch && w.label == '启动时自动检查更新',
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(h.controller.settings.value['autoUpdateCheck'], isFalse);
    openOnboarding(tester.element(find.byType(MePage)));
    await tester.pumpAndSettle();
    expect(find.text('继续即表示你了解 '), findsOneWidget);
    await tapVisible(tester, '隐私政策 ›');
    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('在线查看配置与 Markdown 段落/列表/粗体/代码/表格', (tester) async {
    final h = await Harness.pump(tester, tab: 3);
    Navigator.of(tester.element(find.byType(MePage)), rootNavigator: true).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            const PrivacyPage(onlineUrl: 'https://example.test/privacy'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/legal/privacy.md');
    });
    await tester.pumpAndSettle();
    await tapVisible(tester, '在线查看');
    expect(h.native.opened, ['https://example.test/privacy']);
    expect(find.byType(MarkdownLite), findsOneWidget);
    final richTexts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(MarkdownLite),
        matching: find.byType(Text),
      ),
    );
    expect(
      richTexts.any(
        (t) => t.data == null && t.textSpan!.toPlainText().contains('不需要注册账号'),
      ),
      isTrue,
    );
    expect(
      richTexts.any(
        (t) => t.textSpan?.toPlainText().contains('allowBackup=false') == true,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
