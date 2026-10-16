
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/core/native_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('leandaily/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ChannelNative native;
  late List<MethodCall> calls;
  final bytes = Uint8List.fromList([255, 216, 255]);
  setUp(() {
    calls = [];
    native = ChannelNative();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'all' => {'a': '中文'},
        'secretsGet' => {'modelKey': 'm'},
        'photoWrite' => '/photos/a.jpg',
        'photoRead' => {'bytes': bytes, 'size': 3, 'sha256': 'hash'},
        'http' => {'status': 201, 'body': '中文'},
        'importDocument' => '备份',
        'pickImages' => [bytes],
        'clock' => {'today': '2026-10-15', 'now': '09:30'},
        'zonedMs' => 123,
        'zonedDate' => '2026-10-15',
        'notifyState' => {'granted': true, 'exact': false},
        'requestNotify' => true,
        'pendingIds' => [1, 1000],
        'takeLaunchPayload' => {'plan': true},
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('全部返回值解码', () async {
    expect(await native.all(), {'a': '中文'});
    expect((await native.secretsGet()).toMap(), {
      'modelKey': 'm',
    });
    expect(await native.photoWrite(bytes), '/photos/a.jpg');
    final photo = await native.photoRead('p');
    expect(photo.bytes, bytes);
    expect(photo.size, 3);
    expect(photo.sha256, 'hash');
    final reply = await native.http(
      const HttpCall(id: 'i', url: 'https://example.test'),
    );
    expect(reply.status, 201);
    expect(reply.body, '中文');
    expect(await native.importDocument(), '备份');
    expect(await native.pickImages(source: PickSource.gallery, limit: 2), [
      bytes,
    ]);
    expect(await native.clock('Asia/Shanghai'), (
      today: '2026-10-15',
      now: '09:30',
    ));
    expect(await native.zonedMs('UTC', '2026-10-15'), 123);
    expect(await native.zonedDate('UTC', 123), '2026-10-15');
    expect(await native.notifyState(), (granted: true, exact: false));
    expect(await native.requestNotify(), true);
    expect(await native.pendingIds(), [1, 1000]);
    expect((await native.takeLaunchPayload())!.plan, true);
  });

  test('每个方法的参数编码', () async {
    await native.all();
    await native.put('k', 'v');
    await native.pruneSecrets();
    await native.secretsGet();
    await native.secretsSet(const Secrets(modelKey: 'm'));
    await native.photoWrite(bytes);
    await native.photoRead('p');
    await native.http(
      HttpCall(
        id: 'i',
        url: 'https://example.test',
        method: 'POST',
        headers: const {'h': 'v'},
        body: 'b',
        multipart: MultipartBody(fields: const {'a': '中'}, bytes: bytes),
        timeoutMs: 2000,
      ),
    );
    await native.cancelHttp('i');
    await native.exportDocument('d', 'n');
    await native.importDocument();
    await native.pickImages(source: PickSource.camera, limit: 1);
    await native.clock('UTC');
    await native.zonedMs('UTC', '2026-01-01');
    await native.zonedDate('UTC', 123);
    await native.notifyState();
    await native.requestNotify();
    await native.openExactAlarmSettings();
    await native.schedule([
      const ScheduledNote(id: 1, title: 't', body: 'b', atMs: 123, plan: true),
    ]);
    await native.cancel([1]);
    await native.pendingIds();
    await native.takeLaunchPayload();
    await native.keepAwake(true);
    await native.openUrl('https://example.test');
    await native.minimize();
    expect(
      {for (final c in calls) c.method: c.arguments},
      {
        'all': null,
        'put': {'key': 'k', 'value': 'v'},
        'pruneSecrets': null,
        'secretsGet': null,
        'secretsSet': {'modelKey': 'm'},
        'photoWrite': {'bytes': bytes},
        'photoRead': {'path': 'p'},
        'http': {
          'id': 'i',
          'url': 'https://example.test',
          'method': 'POST',
          'headers': {'h': 'v'},
          'body': 'b',
          'multipart': {
            'fields': {'a': '中'},
            'bytes': bytes,
          },
          'timeout': 2000,
        },
        'cancelHttp': {'id': 'i'},
        'exportDocument': {'data': 'd', 'name': 'n'},
        'importDocument': null,
        'pickImages': {'source': 'camera', 'limit': 1},
        'clock': {'tz': 'UTC'},
        'zonedMs': {'tz': 'UTC', 'date': '2026-01-01'},
        'zonedDate': {'tz': 'UTC', 'ms': 123},
        'notifyState': null,
        'requestNotify': null,
        'openExactAlarmSettings': null,
        'schedule': [
          {'id': 1, 'title': 't', 'body': 'b', 'atMs': 123, 'plan': true},
        ],
        'cancel': [1],
        'pendingIds': null,
        'takeLaunchPayload': null,
        'keepAwake': true,
        'openUrl': {'url': 'https://example.test'},
        'minimize': null,
      },
    );
  });

  test('错误文案与通知回调、空冷启动', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'takeLaunchPayload') return null;
      throw PlatformException(code: 'native', message: '已取消导入');
    });
    expect(await native.takeLaunchPayload(), null);
    await expectLater(
      native.importDocument(),
      throwsA(isA<NativeError>().having((e) => e.message, 'message', '已取消导入')),
    );
    final tap = native.notificationTaps.first;
    await messenger.handlePlatformMessage(
      'leandaily/native',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('notificationTap', {'plan': false}),
      ),
      (_) {},
    );
    expect((await tap).plan, false);
  });

  test('FakeNative 基本存储、失败回滚、取消、时钟及通知', () async {
    final fake = FakeNative();
    await fake.put('a', '{"v":1}');
    final snapshot = await fake.all();
    snapshot.clear();
    expect(fake.json('a'), {'v': 1});
    fake.failNextPut = const NativeError('失败');
    await expectLater(fake.put('a', 'bad'), throwsA(isA<NativeError>()));
    expect(fake.json('a'), {'v': 1});
    await fake.secretsSet(const Secrets(modelKey: 'm'));
    expect((await fake.secretsGet()).modelKey, 'm');
    final path = await fake.photoWrite(bytes);
    expect((await fake.photoRead(path)).bytes, bytes);
    await expectLater(
      fake.photoWrite(Uint8List(0)),
      throwsA(isA<NativeError>()),
    );
    fake.onHttp = (_) => const HttpReply(200, 'ok');
    await fake.cancelHttp('i');
    await expectLater(
      fake.http(const HttpCall(id: 'i', url: 'https://example.test')),
      throwsA(isA<NativeError>()),
    );
    expect(
      (await fake.http(const HttpCall(id: 'i', url: 'https://example.test')))
          .body,
      'ok',
    );
    await fake.schedule([
      const ScheduledNote(id: 1, title: '', body: '', atMs: 1),
    ]);
    await fake.schedule([
      const ScheduledNote(id: 1, title: 'new', body: '', atMs: 2),
    ]);
    expect(await fake.pendingIds(), [1]);
    await fake.cancel([1]);
    expect(await fake.pendingIds(), isEmpty);
    fake.launchPayload = const NotificationTap(plan: true);
    expect((await fake.takeLaunchPayload())!.plan, true);
    expect(await fake.takeLaunchPayload(), null);
    final tap = fake.notificationTaps.first;
    fake.tapNotification();
    expect((await tap).plan, true);
    expect(await fake.clock('Asia/Shanghai'), (
      today: '2026-10-15',
      now: '09:30',
    ));
    final ms = await fake.zonedMs('Asia/Shanghai', '2026-10-15');
    expect(await fake.zonedDate('Asia/Shanghai', ms), '2026-10-15');
    fake.pickResult = [bytes, bytes];
    expect(
      await fake.pickImages(source: PickSource.gallery, limit: 1),
      hasLength(1),
    );
    await fake.exportDocument('data', 'n');
    expect(fake.exported, 'data');
    fake.importData = 'data';
    expect(await fake.importDocument(), 'data');
    await fake.keepAwake(true);
    expect(fake.awake, true);
    await fake.openUrl('u');
    expect(fake.opened, ['u']);
    expect(await fake.notifyState(), (granted: true, exact: true));
    expect(await fake.requestNotify(), true);
  });
}
