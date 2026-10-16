import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// 原生能力的门面。契约见 MIGRATION.md 第 2 节。
/// 真实实现 [ChannelNative]走 MethodChannel；测试用 [FakeNative]。
abstract interface class Native {
  // ---- 文档存储（SQLite documents 表）----
  Future<Map<String, String>> all();
  Future<void> put(String key, String value);

  // ---- 密钥（Keystore）----
  Future<Secrets> secretsGet();
  Future<void> secretsSet(Secrets values);
  /// 重写当前支持的密钥，丢弃旧版本遗留项。
  Future<void> pruneSecrets();

  // ---- 照片（filesDir/photos）----
  Future<String> photoWrite(Uint8List bytes);
  Future<PhotoData> photoRead(String path);

  // ---- 网络（仅 HTTPS，可取消）----
  Future<HttpReply> http(HttpCall call);
  Future<void> cancelHttp(String id);

  // ---- 文档选择器 ----
  Future<void> exportDocument(String data, String name);
  Future<String> importDocument();

  // ---- 相机 / 相册 ----
  Future<List<Uint8List>> pickImages({required PickSource source, required int limit});

  // ---- 时区 ----
  Future<({String today, String now})> clock(String tz);
  /// 手机当前的时区名（IANA）。
  Future<String> deviceTz();
  Future<int> zonedMs(String tz, String isoDate);
  Future<String> zonedDate(String tz, int ms);

  // ---- 通知 ----
  Future<({bool granted, bool exact})> notifyState();
  Future<bool> requestNotify();
  Future<void> openExactAlarmSettings();
  Future<void> schedule(List<ScheduledNote> notes);
  Future<void> cancel(List<int> ids);
  Future<List<int>> pendingIds();

  /// 点了通知。冷启动时由 [takeLaunchPayload] 取。
  Stream<NotificationTap> get notificationTaps;
  Future<NotificationTap?> takeLaunchPayload();

  // ---- 杂项 ----
  Future<void> keepAwake(bool on);
  Future<void> openUrl(String url);
  Future<void> minimize();
}

enum PickSource { camera, gallery }

class Secrets {
  const Secrets({this.modelKey = ''});
  final String modelKey;
  Map<String, String> toMap() => {'modelKey': modelKey};
  static Secrets fromMap(Map<Object?, Object?>? m) =>
      Secrets(modelKey: '${m?['modelKey'] ?? ''}');
}

class PhotoData {
  const PhotoData({required this.bytes, required this.size, required this.sha256});
  final Uint8List bytes;
  final int size;
  final String sha256;
}

class MultipartBody {
  const MultipartBody({required this.fields, required this.bytes});
  final Map<String, String> fields;
  final Uint8List bytes;
}

class HttpCall {
  const HttpCall({
    required this.id,
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.multipart,
    this.timeoutMs = 120000,
  });
  final String id;
  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final MultipartBody? multipart;
  final int timeoutMs;
}

class HttpReply {
  const HttpReply(this.status, this.body);
  final int status;
  final String body;
}

class ScheduledNote {
  const ScheduledNote({required this.id, required this.title, required this.body, required this.atMs, this.plan = false});
  final int id;
  final String title;
  final String body;
  final int atMs;
  final bool plan;
}

class NotificationTap {
  const NotificationTap({required this.plan});
  final bool plan;
}

/// 原生层抛出的错误，message 已是面向用户的中文。
class NativeError implements Exception {
  const NativeError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 内存实现：给单测用。时钟、HTTP 响应、选图结果都可以编排。
class FakeNative implements Native {
  FakeNative({DateTime? now, this.tz = 'Asia/Shanghai'}) : _now = now ?? DateTime(2026, 10, 15, 9, 30);

  final Map<String, String> docs = {};
  Secrets secrets = const Secrets();
  final Map<String, Uint8List> photos = {};
  final List<HttpCall> httpLog = [];
  final List<ScheduledNote> scheduled = [];
  final List<String> opened = [];
  final Set<String> cancelledHttp = {};
  String tz;
  DateTime _now;
  bool notifyGranted = true;
  bool exactGranted = true;
  bool awake = false;
  String? exported;
  String? importData;
  List<Uint8List> pickResult = [];
  NotificationTap? launchPayload;
  int _photoSeq = 0;
  int putCount = 0;

  /// 返回 null 表示这条请求没编排——会抛错，方便发现漏测。
  FutureOr<HttpReply> Function(HttpCall call)? onHttp;
  Object? failNextPut;

  set now(DateTime v) => _now = v;

  final StreamController<NotificationTap> _taps = StreamController.broadcast();
  void tapNotification({bool plan = true}) => _taps.add(NotificationTap(plan: plan));

  @override
  Future<Map<String, String>> all() async => Map.of(docs);

  @override
  Future<void> put(String key, String value) async {
    final err = failNextPut;
    if (err != null) {
      failNextPut = null;
      throw err;
    }
    putCount++;
    docs[key] = value;
  }

  @override
  Future<Secrets> secretsGet() async => secrets;
  int pruneSecretsCalls = 0;
  @override
  Future<void> pruneSecrets() async {
    pruneSecretsCalls++;
  }
  @override
  Future<void> secretsSet(Secrets values) async => secrets = values;

  @override
  Future<String> photoWrite(Uint8List bytes) async {
    if (bytes.length < 3 || bytes[0] != 0xff || bytes[1] != 0xd8) throw const NativeError('操作失败：仅支持有效 JPEG 照片');
    final path = '/fake/photos/${(_photoSeq++).toRadixString(16).padLeft(8, '0')}-0000-4000-8000-000000000000.jpg';
    photos[path] = bytes;
    return path;
  }

  @override
  Future<PhotoData> photoRead(String path) async {
    final b = photos[path];
    if (b == null) throw const NativeError('操作失败：文件或网络不可用，请检查后重试');
    return PhotoData(bytes: b, size: b.length, sha256: _fakeSha(b));
  }

  /// 测试里不引入 crypto：用确定性的 64 位十六进制摘要代替。
  static String _fakeSha(Uint8List b) {
    var h = 1469598103934665603;
    for (final x in b) {
      h = ((h ^ x) * 1099511628211) & 0x7fffffffffffffff;
    }
    return h.toRadixString(16).padLeft(16, '0') * 4;
  }

  static String fakeSha(Uint8List b) => _fakeSha(b);

  @override
  Future<HttpReply> http(HttpCall call) async {
    httpLog.add(call);
    if (cancelledHttp.remove(call.id)) throw const NativeError('请求已取消');
    final h = onHttp;
    if (h == null) throw StateError('FakeNative.onHttp 未设置：${call.method} ${call.url}');
    return await h(call);
  }

  @override
  Future<void> cancelHttp(String id) async => cancelledHttp.add(id);

  @override
  Future<void> exportDocument(String data, String name) async {
    if (exported == null && importData == null && data.isEmpty) throw const NativeError('已取消导出');
    exported = data;
  }

  @override
  Future<String> importDocument() async {
    final d = importData;
    if (d == null) throw const NativeError('已取消导入');
    return d;
  }

  @override
  Future<List<Uint8List>> pickImages({required PickSource source, required int limit}) async => pickResult.take(limit).toList();

  @override
  Future<({String today, String now})> clock(String tz) async {
    String p(int n) => n.toString().padLeft(2, '0');
    return (today: '${_now.year}-${p(_now.month)}-${p(_now.day)}', now: '${p(_now.hour)}:${p(_now.minute)}');
  }

  /// 假时钟的时区换算：把 tz 当作固定的 UTC+8。
  @override
  Future<int> zonedMs(String tz, String isoDate) async {
    final d = DateTime.parse('${isoDate}T00:00:00Z');
    return d.millisecondsSinceEpoch - 8 * 3600000;
  }

  @override
  Future<String> zonedDate(String tz, int ms) async {
    final d = DateTime.fromMillisecondsSinceEpoch(ms + 8 * 3600000, isUtc: true);
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  @override
  Future<String> deviceTz() async => tz;

  @override
  Future<({bool granted, bool exact})> notifyState() async => (granted: notifyGranted, exact: exactGranted);
  @override
  Future<bool> requestNotify() async => notifyGranted;
  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> schedule(List<ScheduledNote> notes) async {
    for (final n in notes) {
      scheduled.removeWhere((x) => x.id == n.id);
      scheduled.add(n);
    }
  }

  @override
  Future<void> cancel(List<int> ids) async => scheduled.removeWhere((n) => ids.contains(n.id));
  @override
  Future<List<int>> pendingIds() async => [for (final n in scheduled) n.id];

  @override
  Stream<NotificationTap> get notificationTaps => _taps.stream;
  @override
  Future<NotificationTap?> takeLaunchPayload() async {
    final p = launchPayload;
    launchPayload = null;
    return p;
  }

  @override
  Future<void> keepAwake(bool on) async => awake = on;
  @override
  Future<void> openUrl(String url) async => opened.add(url);
  @override
  Future<void> minimize() async {}

  /// 便捷：读 JSON 文档。
  Object? json(String key) => docs[key] == null ? null : jsonDecode(docs[key]!);
}
