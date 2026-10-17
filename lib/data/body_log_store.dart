import 'dart:convert';

import '../core/native.dart';

/// Serial, read-modify-write access to the additive body-measurement document.
/// Re-reads inside the lane so two queued records cannot lose one another.
class BodyLogStore {
  BodyLogStore(this.native);
  final Native native;
  static const key = 'fw-body-v1';
  Future<void> _lane = Future<void>.value();

  Future<List<Map<String, dynamic>>> load() async {
    final raw = (await native.all())[key];
    if (raw == null) return [];
    final doc = jsonDecode(raw);
    // 备份恢复会把“没有这份数据”写成 JSON null，等同于还没有记录。
    if (doc == null) return [];
    if (doc is! Map || doc['v'] != 1 || doc['entries'] is! List) {
      throw const FormatException('体重记录格式无效');
    }
    return [
      for (final entry in doc['entries'] as List)
        Map<String, dynamic>.from(entry as Map),
    ];
  }

  /// 写入前读取。文档损坏时，原样另存一份再从空白开始，
  /// 否则一份坏数据会让之后每一次“记体重”都失败。
  Future<List<Map<String, dynamic>>> _loadForWrite() async {
    try {
      return await load();
    } on FormatException {
      final raw = (await native.all())[key];
      if (raw != null) await native.put('$key-corrupt', raw);
      return [];
    }
  }

  Future<void> record({
    required String date,
    required num weightKg,
    num? waistCm,
  }) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null ||
        parsed.toIso8601String().substring(0, 10) != date ||
        !weightKg.isFinite ||
        weightKg < 30 ||
        weightKg > 250 ||
        (waistCm != null &&
            (!waistCm.isFinite || waistCm < 20 || waistCm > 200))) {
      return Future.error(const FormatException('请输入有效的日期、体重和腰围'));
    }
    final entry = <String, dynamic>{
      'date': date,
      'weightKg': weightKg,
      'waistCm': ?waistCm,
    };
    final result = _lane.then((_) async {
      final entries = await _loadForWrite();
      entries.removeWhere((e) => e['date'] == date);
      entries.add(entry);
      entries.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );
      await native.put(key, jsonEncode({'v': 1, 'entries': entries}));
    });
    _lane = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
