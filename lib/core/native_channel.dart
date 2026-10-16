import 'dart:async';

import 'package:flutter/services.dart';

import 'native.dart';

/// Android SDK 实现的原生能力，所有字节直接使用 StandardMethodCodec。
class ChannelNative implements Native {
  ChannelNative({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('leandaily/native') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationTap') {
        final map = call.arguments as Map<Object?, Object?>;
        _taps.add(NotificationTap(plan: map['plan'] == true));
      }
    });
  }

  final MethodChannel _channel;
  final _taps = StreamController<NotificationTap>.broadcast();

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      final limit = const {'exportDocument', 'importDocument', 'pickImages', 'requestNotify', 'http'}.contains(method) ? null : const Duration(seconds: 20);
      final call = _channel.invokeMethod<T>(method, arguments);
      return await (limit == null ? call : call.timeout(limit, onTimeout: () => throw NativeError('原生功能无响应（$method）')));
    } on PlatformException catch (e) {
      throw NativeError(e.message ?? e.code);
    } on MissingPluginException catch (e) {
      throw NativeError(e.message ?? '原生功能不可用');
    }
  }

  @override
  Future<Map<String, String>> all() async =>
      Map<String, String>.from((await _call<Map<Object?, Object?>>('all'))!);
  @override
  Future<void> put(String key, String value) =>
      _call<void>('put', {'key': key, 'value': value});
  @override
  Future<void> pruneSecrets() => _call<void>('pruneSecrets');
  @override
  Future<Secrets> secretsGet() async =>
      Secrets.fromMap(await _call<Map<Object?, Object?>>('secretsGet'));
  @override
  Future<void> secretsSet(Secrets values) =>
      _call<void>('secretsSet', values.toMap());
  @override
  Future<String> photoWrite(Uint8List bytes) async =>
      (await _call<String>('photoWrite', {'bytes': bytes}))!;
  @override
  Future<PhotoData> photoRead(String path) async {
    final m = (await _call<Map<Object?, Object?>>('photoRead', {
      'path': path,
    }))!;
    return PhotoData(
      bytes: m['bytes'] as Uint8List,
      size: m['size'] as int,
      sha256: m['sha256'] as String,
    );
  }

  @override
  Future<HttpReply> http(HttpCall call) async {
    final m = (await _call<Map<Object?, Object?>>('http', {
      'id': call.id,
      'url': call.url,
      'method': call.method,
      'headers': call.headers,
      'timeout': call.timeoutMs,
      if (call.body != null) 'body': call.body,
      if (call.multipart case final multipart?)
        'multipart': {'fields': multipart.fields, 'bytes': multipart.bytes},
    }))!;
    return HttpReply(m['status'] as int, m['body'] as String);
  }

  @override
  Future<void> cancelHttp(String id) => _call<void>('cancelHttp', {'id': id});
  @override
  Future<void> exportDocument(String data, String name) =>
      _call<void>('exportDocument', {'data': data, 'name': name});
  @override
  Future<String> importDocument() async =>
      (await _call<String>('importDocument'))!;
  @override
  Future<List<Uint8List>> pickImages({
    required PickSource source,
    required int limit,
  }) async => (await _call<List<Object?>>('pickImages', {
    'source': source.name,
    'limit': limit,
  }))!.cast<Uint8List>();
  @override
  Future<({String today, String now})> clock(String tz) async {
    final m = (await _call<Map<Object?, Object?>>('clock', {'tz': tz}))!;
    return (today: m['today'] as String, now: m['now'] as String);
  }

  @override
  Future<String> deviceTz() async => (await _call<String>('deviceTz')) ?? 'Asia/Shanghai';

  @override
  Future<int> zonedMs(String tz, String isoDate) async =>
      (await _call<int>('zonedMs', {'tz': tz, 'date': isoDate}))!;
  @override
  Future<String> zonedDate(String tz, int ms) async =>
      (await _call<String>('zonedDate', {'tz': tz, 'ms': ms}))!;
  @override
  Future<({bool granted, bool exact})> notifyState() async {
    final m = (await _call<Map<Object?, Object?>>('notifyState'))!;
    return (granted: m['granted'] == true, exact: m['exact'] == true);
  }

  @override
  Future<bool> requestNotify() async => (await _call<bool>('requestNotify'))!;
  @override
  Future<void> openExactAlarmSettings() =>
      _call<void>('openExactAlarmSettings');
  @override
  Future<void> schedule(List<ScheduledNote> notes) => _call<void>('schedule', [
    for (final n in notes)
      {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'atMs': n.atMs,
        'plan': n.plan,
      },
  ]);
  @override
  Future<void> cancel(List<int> ids) => _call<void>('cancel', ids);
  @override
  Future<List<int>> pendingIds() async =>
      (await _call<List<Object?>>('pendingIds'))!.cast<int>();
  @override
  Stream<NotificationTap> get notificationTaps => _taps.stream;
  @override
  Future<NotificationTap?> takeLaunchPayload() async {
    final m = await _call<Map<Object?, Object?>>('takeLaunchPayload');
    return m == null ? null : NotificationTap(plan: m['plan'] == true);
  }

  @override
  Future<void> keepAwake(bool on) => _call<void>('keepAwake', on);
  @override
  Future<void> openUrl(String url) => _call<void>('openUrl', {'url': url});
  @override
  Future<void> minimize() => _call<void>('minimize');
}
