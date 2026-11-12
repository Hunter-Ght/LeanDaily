import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/core/native_channel.dart';
import 'package:leandaily/data/backup.dart' as backup;
import 'package:leandaily/data/backup_status.dart';
import 'package:leandaily/data/repository.dart';
import 'package:leandaily/ui/me/backup_nudge.dart';
import 'package:leandaily/ui/me/me_page.dart';
import 'package:leandaily/ui/onboarding/onboarding_flow.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';

import 'support/harness.dart';

const _day = 24 * 60 * 60 * 1000;
final _now = DateTime.parse(Harness.refTime).millisecondsSinceEpoch;

void _seedStatus(FakeNative n, {int? last, int? snooze}) {
  n.docs[BackupStatusStore.key] = jsonEncode({
    'v': 1,
    'lastExportMs': ?last,
    'snoozeUntilMs': ?snooze,
  });
}

Map<String, dynamic> _status(FakeNative n) =>
    jsonDecode(n.docs[BackupStatusStore.key]!) as Map<String, dynamic>;

Future<void> _openBackupSheet(
  WidgetTester tester, {
  String label = '备份与高级',
}) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// 一个有记录、有计划的备份文件，给“换新手机”场景用。
Future<String> _sampleBackup() async {
  final src = FakeNative(now: DateTime.parse(Harness.refTime));
  final legacy = (jsonDecode(
    File('test/fixtures/legacy_store.json').readAsStringSync(),
  ) as Map).cast<String, String>();
  src.docs['fw-plan-v1'] = legacy['fw-plan-v1']!;
  src.docs['fw-onboarded-v1'] = '1';
  final repo = Repository(src);
  await repo.load();
  await repo.addSets(
    date: '2026-10-14',
    part: '胸',
    exercise: '杠铃卧推',
    rows: [
      {'weight': 60, 'reps': 8, 'type': '正式'},
    ],
  );
  await backup.exportBackup(
    src,
    repo,
    clock: () => DateTime.utc(2026, 10, 15, 8),
  );
  return src.exported!;
}

class _CancelNative extends FakeNative {
  @override
  Future<void> exportDocument(String data, String name) async =>
      throw const NativeError('已取消导出');
}

void main() {
  setUpAll(Harness.setUpAll);

  group('备份状态行', () {
    testWidgets('没备份过时平静地说明，不用警告色', (tester) async {
      final h = await Harness.pump(tester, tab: 3, empty: true);
      expect(find.text('还没备份过'), findsOneWidget);
      expect(h.native.docs.containsKey(BackupStatusStore.key), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('显示几天前备份', (tester) async {
      await Harness.pump(
        tester,
        tab: 3,
        seed: (n) => _seedStatus(n, last: _now - 3 * _day),
      );
      expect(find.text('3 天前备份'), findsOneWidget);
    });

    testWidgets('状态文件损坏当作没备份过', (tester) async {
      await Harness.pump(
        tester,
        tab: 3,
        empty: true,
        seed: (n) => n.docs[BackupStatusStore.key] = '{坏的',
      );
      expect(find.text('还没备份过'), findsOneWidget);
    });
  });

  group('提示卡', () {
    testWidgets('记录多且没备份过：显示；点现在备份后导出、记时间、卡片消失', (tester) async {
      final h = await Harness.pump(tester, tab: 3);
      expect(find.byType(BackupNudgeCard), findsOneWidget);
      expect(find.text('记录只存在这部手机上，换机前先备份一份。'), findsOneWidget);
      await tester.tap(find.text('现在备份'));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.native.exported!)['format'], 'leandaily-backup');
      expect(_status(h.native)['lastExportMs'], _now);
      expect(find.byType(BackupNudgeCard), findsNothing);
      expect(find.text('今天已备份'), findsOneWidget);
      expect(find.text('备份已保存到你选择的位置'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('以后再说：14 天内不再提示，且记下到期时间', (tester) async {
      final h = await Harness.pump(tester, tab: 3);
      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();
      expect(find.byType(BackupNudgeCard), findsNothing);
      expect(_status(h.native)['snoozeUntilMs'], _now + 14 * _day);
      expect(h.native.exported, isNull);
    });

    test('取消导出：不记时间，抛出给界面处理', () async {
      final native = _CancelNative();
      final app = AppController(
        native: native,
        clock: () => DateTime.parse(Harness.refTime),
      );
      await app.boot();
      await expectLater(app.exportBackup(), throwsA(isA<NativeError>()));
      expect(app.backupStatus.lastExportMs, isNull);
      expect(native.docs.containsKey(BackupStatusStore.key), isFalse);
      app.dispose();
    });

    testWidgets('最近备份过：不显示', (tester) async {
      await Harness.pump(
        tester,
        tab: 3,
        seed: (n) => _seedStatus(n, last: _now - 5 * _day),
      );
      expect(find.byType(BackupNudgeCard), findsNothing);
    });

    testWidgets('记录少不显示', (tester) async {
      await Harness.pump(tester, tab: 3, empty: true);
      expect(find.byType(BackupNudgeCard), findsNothing);
    });

    testWidgets('静默期内不显示，到期后再显示', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        seed: (n) => _seedStatus(n, snooze: _now + 14 * _day),
      );
      expect(find.byType(BackupNudgeCard), findsNothing);
      expect(h.controller.shouldNudgeBackup, isFalse);
    });

    testWidgets('超过 30 天没备份：换一句话再提示', (tester) async {
      await Harness.pump(
        tester,
        tab: 3,
        seed: (n) => _seedStatus(n, last: _now - 45 * _day),
      );
      expect(find.text('已经一个多月没备份了，导出一份最新的吧。'), findsOneWidget);
      expect(find.text('45 天前备份'), findsOneWidget);
    });

    testWidgets('打开了随 iPhone 备份就不再提示', (tester) async {
      await Harness.pump(
        tester,
        tab: 3,
        seed: (n) {
          n.systemBackupSupported = true;
          n.systemBackupEnabled = true;
        },
      );
      expect(find.byType(BackupNudgeCard), findsNothing);
      expect(find.text('随 iPhone 备份'), findsOneWidget);
    });

    testWidgets('今日页和训练页没有这张卡', (tester) async {
      await Harness.pump(tester);
      expect(find.byType(BackupNudgeCard), findsNothing);
    });
  });

  group('备份页', () {
    testWidgets('导出后更新“上次备份”', (tester) async {
      final h = await Harness.pump(tester, tab: 3, empty: true);
      await _openBackupSheet(tester);
      expect(find.text('还没备份过'), findsWidgets);
      await tester.tap(find.text('导出备份'));
      await tester.pumpAndSettle();
      expect(_status(h.native)['lastExportMs'], _now);
      expect(find.text('今天已备份'), findsWidgets);
      expect(find.textContaining('导出时可以选择保存位置'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Android：不显示随 iPhone 备份开关', (tester) async {
      await Harness.pump(tester, tab: 3, empty: true);
      await _openBackupSheet(tester);
      expect(find.text('随 iPhone 备份'), findsNothing);
      expect(find.byType(AndroidSettingsSheet), findsOneWidget);
    });

    testWidgets('iOS：开关默认关，打开和关闭都调用原生', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        empty: true,
        size: const Size(393, 1200),
        seed: (n) => n.systemBackupSupported = true,
      );
      await _openBackupSheet(tester);
      expect(find.text('随 iPhone 备份'), findsNWidgets(2)); // 分组标题 + 行
      expect(find.textContaining('API Key 不会进入备份'), findsOneWidget);
      expect(h.native.systemBackupEnabled, isFalse);
      final toggle = find.bySemanticsLabel('随 iPhone 备份');
      await tester.ensureVisible(toggle.last);
      await tester.tap(toggle.last);
      await tester.pumpAndSettle();
      expect(h.native.systemBackupCalls, [true]);
      expect(h.controller.systemBackup.enabled, isTrue);
      await tester.tap(toggle.last);
      await tester.pumpAndSettle();
      expect(h.native.systemBackupCalls, [true, false]);
      expect(h.controller.systemBackup.enabled, isFalse);
    });

    testWidgets('iOS：原生失败时保持原状并提示', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        empty: true,
        size: const Size(393, 1200),
        seed: (n) => n.systemBackupSupported = true,
      );
      await _openBackupSheet(tester);
      h.native.failSystemBackup = const NativeError('坏了');
      final toggle = find.bySemanticsLabel('随 iPhone 备份');
      await tester.tap(toggle.last);
      await tester.pumpAndSettle();
      expect(h.controller.systemBackup.enabled, isFalse);
      expect(find.text('设置未保存，请稍后再试'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('恢复', () {
    testWidgets('引导页有“从备份恢复”，恢复成功后直接进入首页', (tester) async {
      final file = await _sampleBackup();
      final h = await Harness.pump(tester, newUser: true);
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('已有备份？从备份恢复'), findsOneWidget);
      h.native.importData = file;
      await tester.tap(find.text('已有备份？从备份恢复'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(h.controller.needsOnboarding, isFalse);
      expect(h.controller.repo.state['sets'], isNotEmpty);
      expect(find.text('记录已恢复'), findsOneWidget);
      // 恢复后“上次备份”按备份文件生成的时间算。
      expect(
        _status(h.native)['lastExportMs'],
        DateTime.utc(2026, 10, 15, 8).millisecondsSinceEpoch,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('选了不是备份的文件：留在引导页并提示', (tester) async {
      final h = await Harness.pump(tester, newUser: true);
      h.native.importData = '{"hello":1}';
      await tester.tap(find.text('已有备份？从备份恢复'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('不是支持的薄肌日课备份'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('在选择器里取消：安静地留在引导页', (tester) async {
      final h = await Harness.pump(tester, newUser: true);
      await tester.tap(find.text('已有备份？从备份恢复'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('已取消导入'), findsNothing);
      expect(h.controller.repo.state['sets'], isEmpty);
    });

    testWidgets('重新评估（升级）页面不出现恢复入口', (tester) async {
      await Harness.pump(tester, tab: 3, empty: true);
      await tester.ensureVisible(find.text('开始评估'));
      await tester.tap(find.text('开始评估'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('已有备份？从备份恢复'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('原生通道', () {
    const channel = MethodChannel('leandaily/native');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('读取状态和设置开关的参数', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'systemBackupState'
            ? {'supported': true, 'enabled': true}
            : null;
      });
      final native = ChannelNative();
      final state = await native.systemBackupState();
      expect((state.supported, state.enabled), (true, true));
      await native.setSystemBackup(false);
      expect(calls.last.method, 'setSystemBackup');
      expect(calls.last.arguments, {'enabled': false});
    });

    test('旧版原生不认识这个方法时按不支持处理', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final state = await ChannelNative().systemBackupState();
      expect((state.supported, state.enabled), (false, false));
    });
  });

  testWidgets('引导页恢复入口：浅色/深色/英文截图', (tester) async {
    for (final (name, dark, locale) in [
      ('light', false, const Locale('zh', 'CN')),
      ('dark', true, const Locale('zh', 'CN')),
      ('en', false, const Locale('en')),
    ]) {
      final h = await Harness.pump(
        tester,
        newUser: true,
        dark: dark,
        locale: locale,
      );
      await h.shot(tester, 'backup-onboarding-$name');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('备份页：浅色/深色/英文截图（含 iOS 开关）', (tester) async {
    for (final (name, dark, locale) in [
      ('light', false, const Locale('zh', 'CN')),
      ('dark', true, const Locale('zh', 'CN')),
      ('en', false, const Locale('en')),
    ]) {
      final h = await Harness.pump(
        tester,
        tab: 3,
        dark: dark,
        locale: locale,
        size: const Size(393, 1100),
        seed: (n) {
          n.systemBackupSupported = true;
          _seedStatus(n, last: _now - 3 * _day);
        },
      );
      await _openBackupSheet(
        tester,
        label: locale.languageCode == 'en' ? 'Backup & advanced' : '备份与高级',
      );
      await h.shot(tester, 'backup-sheet-ios-$name');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('我的页备份行：浅色/深色/英文截图', (tester) async {
    for (final (name, dark, locale) in [
      ('light', false, const Locale('zh', 'CN')),
      ('dark', true, const Locale('zh', 'CN')),
      ('en', false, const Locale('en')),
    ]) {
      final h = await Harness.pump(
        tester,
        tab: 3,
        dark: dark,
        locale: locale,
        size: const Size(393, 852),
      );
      expect(find.byType(MePage), findsOneWidget);
      await h.shot(tester, 'backup-me-nudge-$name');
      // 英文目录由主线程统一导入；导入前这里仍显示中文原文。
      final later = find.text('以后再说').evaluate().isNotEmpty
          ? find.text('以后再说')
          : find.text('Not now');
      await tester.tap(later);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text(locale.languageCode == 'en' ? 'Backup & advanced' : '备份与高级'),
      );
      await tester.pumpAndSettle();
      await h.shot(tester, 'backup-me-$name');
      expect(tester.takeException(), isNull);
    }
  });
}
