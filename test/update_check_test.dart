import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/config/app_info.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/update_check.dart';
import 'package:leandaily/app/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://example.test/latest';
  String payload([String version = '2.4.0']) => jsonEncode({
    'version': version,
    'build': 25,
    'url': 'https://example.test/app.apk',
    'notes': '改进训练体验',
  });
  test('版本与 pubspec 一致', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: $appVersion+$appBuild'),
    );
  });
  test('两种格式与非法输入', () {
    expect(parseUpdate(payload())?.build, 25);
    expect(
      parseUpdate(
        jsonEncode({
          'tag_name': 'v2.10.0',
          'html_url': url,
          'body': '说明',
          'assets': [
            {'browser_download_url': 'https://example.test/a.apk'},
          ],
        }),
      )?.url,
      'https://example.test/a.apk',
    );
    expect(
      parseUpdate(
        jsonEncode({'tag_name': 'v2.4.0', 'html_url': url, 'body': '说明'}),
      )?.url,
      url,
    );
    for (final input in [
      'oops',
      '[]',
      '{}',
      '{"version":4}',
      payload().replaceAll('https:', 'http:'),
      payload().replaceAll('25', '"25"'),
    ]) {
      expect(parseUpdate(input), isNull);
    }
  });
  test('数字版本、build 和后缀', () {
    expect(isNewer('2.10.0', '2.9.0'), isTrue);
    expect(isNewer('2.4.0', '2.4.0', remoteBuild: 22, localBuild: 21), isTrue);
    expect(isNewer('2.4.0', '2.4.0', remoteBuild: 20, localBuild: 21), isFalse);
    expect(isNewer('3.0.0-beta', '2.4.0'), isFalse);
    expect(isNewer('2.4.0', '2.4.0-beta'), isTrue);
    expect(isNewer('2.3.0', '2.4.0'), isFalse);
    expect(isNewer('bad', '2.4.0'), isFalse);
  });
  test('空地址、HTTPS 限制、请求只带 UA 与八秒超时', () async {
    final n = FakeNative()..onHttp = (_) => HttpReply(200, payload());
    expect(await fetchUpdate(n, ''), isNull);
    expect(await fetchUpdate(n, 'http://example.test'), isNull);
    expect(n.httpLog, isEmpty);
    await fetchUpdate(n, url);
    expect(n.httpLog.single.headers, {'User-Agent': 'LeanDaily'});
    expect(n.httpLog.single.method, 'GET');
    expect(n.httpLog.single.body, isNull);
    expect(n.httpLog.single.timeoutMs, 8000);
  });
  test('启动节流、红点查看与重启持久化、保留其他 hints', () async {
    var now = DateTime(2026, 10, 16);
    final n = FakeNative()..onHttp = (_) => HttpReply(200, payload());
    n.docs['fw-hints-v1'] = jsonEncode({'weightNudgeUntil': '2026-10-20'});
    AppController make() =>
        AppController(native: n, clock: () => now, updateUrl: url);
    final a = make();
    await a.boot();
    while (a.updateStatus == UpdateStatus.checking) {
      await Future<void>.delayed(Duration.zero);
    }
    await a.checkUpdate();
    expect(n.httpLog, hasLength(1));
    expect(a.hasUnseenUpdate, isTrue);
    final unseenRestart = make();
    await unseenRestart.boot();
    expect(unseenRestart.hasUnseenUpdate, isTrue);
    unseenRestart.dispose();
    await a.markUpdateSeen();
    expect(a.hasUnseenUpdate, isFalse);
    expect(
      jsonDecode(n.docs['fw-hints-v1']!)['weightNudgeUntil'],
      '2026-10-20',
    );
    a.dispose();
    final b = make();
    await b.boot();
    while (b.updateStatus == UpdateStatus.checking) {
      await Future<void>.delayed(Duration.zero);
    }
    await b.checkUpdate();
    expect(n.httpLog, hasLength(1));
    expect(b.hasUnseenUpdate, isFalse);
    now = now.add(const Duration(hours: 24));
    await b.checkUpdate();
    expect(n.httpLog, hasLength(2));
    expect(b.hasUnseenUpdate, isFalse);
    n.onHttp = (_) => HttpReply(200, payload('2.5.0'));
    await b.checkUpdate(manual: true);
    expect(b.hasUnseenUpdate, isTrue);
    b.dispose();
  });
  test('未配置、关闭自动检查、失败静默与手动提示', () async {
    final n = FakeNative();
    final a = AppController(native: n, updateUrl: '');
    await a.boot();
    await a.checkUpdate(manual: true);
    expect(n.httpLog, isEmpty);
    expect(a.updateStatus, UpdateStatus.unconfigured);
    a.dispose();
    n.docs['android-settings'] = '{"autoUpdateCheck":false}';
    final b = AppController(native: n, updateUrl: url);
    await b.boot();
    while (b.updateStatus == UpdateStatus.checking) {
      await Future<void>.delayed(Duration.zero);
    }
    await b.checkUpdate();
    expect(n.httpLog, isEmpty);
    await b.setAutoUpdateCheck(true);
    await b.checkUpdate();
    expect(b.updateStatus, UpdateStatus.failed);
    expect(b.toast.text, isNull);
    await b.checkUpdate(manual: true);
    expect(b.toast.text, '暂时无法检查，请稍后再试');
    b.dispose();
  });
}
