// Simulator-only live platform-channel checks, never used by lib/main.dart.
// flutter run -d <simulator> -t tool/ios_smoke.dart --dart-define=LEANDAILY_IOS_SMOKE=true
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:leandaily/core/sha256.dart';
import 'package:leandaily/app/app.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/core/native_channel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isIOS || !const bool.fromEnvironment('LEANDAILY_IOS_SMOKE')) {
    throw StateError(
      'Run this explicit smoke entry only on an isolated iOS simulator.',
    );
  }
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xfff4f3f8),
        child: Center(
          child: Text(
            '正在验证 iOS 原生能力…',
            style: TextStyle(fontSize: 18, color: Color(0xff1b1e27)),
          ),
        ),
      ),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  const channel = MethodChannel('leandaily/native');
  if (await channel.invokeMethod<bool>('debugIsSimulator') != true) {
    throw StateError(
      'This diagnostic must run in a debug iOS simulator build.',
    );
  }
  final native = ChannelNative();
  final checks = <String>[];
  void check(bool value, String label) {
    if (!value) throw StateError(label);
    checks.add(label);
  }

  Future<void> rejects(Future<Object?> Function() action, String label) async {
    try {
      await action();
    } on NativeError {
      checks.add(label);
      return;
    }
    throw StateError('$label was unexpectedly accepted');
  }

  try {
    final tz = await native.deviceTz();
    check(tz.isNotEmpty, 'device timezone');
    final ms = await native.zonedMs('Asia/Shanghai', '2026-10-17');
    check(
      ms == DateTime.utc(2026, 10, 16, 16).millisecondsSinceEpoch,
      'IANA midnight conversion',
    );
    check(
      await native.zonedDate('Asia/Shanghai', ms) == '2026-10-17',
      'zoned date roundtrip',
    );
    final ny = await native.zonedMs('America/New_York', '2026-03-09');
    check(
      ny == DateTime.utc(2026, 3, 9, 4).millisecondsSinceEpoch,
      'DST conversion',
    );
    await rejects(
      () => native.clock('Invalid/Timezone'),
      'invalid timezone rejected',
    );
    await rejects(
      () => native.zonedMs('UTC', '2026-02-30'),
      'invalid date rejected',
    );
    final value = List.filled(100000, '中文🍊').join();
    await native.put('__ios_smoke_unicode__', value);
    check(
      (await native.all())['__ios_smoke_unicode__'] == value,
      'large SQLite Unicode roundtrip',
    );
    await native.put('__ios_smoke_unicode__', '{}');
    final before = await native.secretsGet();
    try {
      await native.secretsSet(
        const Secrets(modelKey: 'smoke-test-not-a-real-key'),
      );
      check(
        (await native.secretsGet()).modelKey == 'smoke-test-not-a-real-key',
        'Keychain typed channel roundtrip',
      );
      await native.pruneSecrets();
      check(
        (await native.secretsGet()).modelKey == 'smoke-test-not-a-real-key',
        'Keychain prune',
      );
    } finally {
      await native.secretsSet(before);
    }
    final bytes = Uint8List.fromList([255, 216, 255, 0, 1, 2]);
    final path = await native.photoWrite(bytes);
    final photo = await native.photoRead(path);
    check(
      path.startsWith('photos/') &&
          photo.size == bytes.length &&
          photo.bytes.join(',') == bytes.join(',') &&
          photo.sha256 == sha256(bytes),
      'photo bytes and metadata codec',
    );
    await rejects(
      () => native.photoRead('../outside.jpg'),
      'photo path traversal rejected',
    );
    await rejects(
      () => native.http(
        const HttpCall(id: 'insecure', url: 'http://example.test'),
      ),
      'insecure HTTP rejected',
    );
    await native.cancelHttp('pre-cancel');
    await rejects(
      () => native.http(
        const HttpCall(id: 'pre-cancel', url: 'https://example.test'),
      ),
      'request pre-cancel',
    );
    final notifyState = await native.notifyState();
    check(notifyState.exact, 'iOS notification capabilities');
    if (!notifyState.granted) {
      check(await native.requestNotify(), 'notification authorization');
    }
    await native.schedule([
      ScheduledNote(
        id: 880002,
        title: '测试',
        body: '本地通道验证',
        atMs: DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      ),
    ]);
    check(
      (await native.pendingIds()).contains(880002),
      'notification scheduling',
    );
    await native.cancel([880002]);
    check(
      !(await native.pendingIds()).contains(880002),
      'notification cancellation',
    );
    await native.keepAwake(true);
    await native.keepAwake(false);
    checks.add('screen awake calls');
    await native.put(
      '__ios_smoke_report__',
      jsonEncode({'passed': checks, 'ok': true}),
    );
    debugPrint('IOS_SMOKE_PASS ${checks.length} checks');
  } catch (e, st) {
    await native.put(
      '__ios_smoke_report__',
      jsonEncode({'passed': checks, 'ok': false, 'error': '$e'}),
    );
    debugPrint('IOS_SMOKE_FAIL $e\n$st');
    rethrow;
  }
  await runLeanDaily(native);
}
