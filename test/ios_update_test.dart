import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/update_check.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS ignores Android releases and only accepts Apple distribution links',
    () {
      String manifest(String url) =>
          jsonEncode({'version': '2.4.0', 'url': url, 'notes': '更新'});
      for (final url in [
        'https://example.test/app.apk',
        'https://github.com/Hunter-Ght/LeanDaily/releases/latest',
        'https://apps.apple.com.evil.test/app',
      ]) {
        expect(
          parseUpdate(manifest(url), platform: TargetPlatform.iOS),
          isNull,
        );
      }
      for (final url in [
        'https://apps.apple.com/app/id123',
        'https://testflight.apple.com/join/example',
      ]) {
        expect(
          parseUpdate(manifest(url), platform: TargetPlatform.iOS)?.url,
          url,
        );
      }
      expect(
        parseUpdate(
          jsonEncode({
            'tag_name': 'v2.4.0',
            'html_url': 'https://github.com/example/releases',
            'body': 'Android release',
            'assets': [
              {'browser_download_url': 'https://example.test/app.apk'},
            ],
          }),
          platform: TargetPlatform.iOS,
        ),
        isNull,
      );
      expect(
        parseUpdate(
          manifest('https://example.test/app.apk'),
          platform: TargetPlatform.android,
        ),
        isNotNull,
      );
    },
  );
  test('iOS defaults to no Android update traffic', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final native = FakeNative();
    final app = AppController(native: native);
    addTearDown(app.dispose);
    expect(app.updateUrl, isEmpty);
    await app.checkUpdate(manual: true);
    expect(app.updateStatus, UpdateStatus.unconfigured);
    expect(native.httpLog, isEmpty);
  });
}
