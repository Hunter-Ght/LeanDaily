import 'dart:convert';

import '../core/native.dart';
import '../domain/benchmarks.dart';

/// 小测试记录：独立的附加文档 `fw-benchmarks-v1`，不碰力量记录和金标。
/// 随备份的偏好一起导出导入；旧备份里没有它，恢复后就是「没有测试记录」。
///
/// 每个日期最多一条（同一天再测会覆盖）；读-改-写串行执行。
class BenchmarkStore {
  BenchmarkStore(this.native, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final Native native;
  final int Function() _now;
  static const key = 'fw-benchmarks-v1';
  Future<void> _lane = Future<void>.value();

  /// 全部记录，按日期升序。无效的单条会被跳过。
  Future<List<Map<String, dynamic>>> load() async {
    final raw = (await native.all())[key];
    if (raw == null) return [];
    final doc = jsonDecode(raw);
    // 备份恢复会把「没有这份数据」写成 JSON null。
    if (doc == null) return [];
    if (doc is! Map || doc['v'] != 1 || doc['entries'] is! List) {
      throw const FormatException('小测试记录格式无效');
    }
    return _byDate([
      for (final e in doc['entries'] as List) ?tryCleanBenchmark(e),
    ]);
  }

  /// 同一天只留最后写入的一条，按日期升序。
  static List<Map<String, dynamic>> _byDate(List<Map<String, dynamic>> rows) {
    final latest = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final old = latest['${r['date']}'];
      if (old == null ||
          ((r['ts'] ?? 0) as num).compareTo((old['ts'] ?? 0) as num) >= 0) {
        latest['${r['date']}'] = r;
      }
    }
    return latest.values.toList()
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
  }

  Future<List<Map<String, dynamic>>> _loadForWrite() async {
    try {
      return await load();
    } on FormatException {
      final raw = (await native.all())[key];
      if (raw != null) await native.put('$key-corrupt', raw);
      return [];
    }
  }

  Future<T> _write<T>(T Function(List<Map<String, dynamic>> rows) change) {
    final result = _lane.then((_) async {
      final rows = await _loadForWrite();
      final out = change(rows);
      await native.put(key, jsonEncode({'v': 1, 'entries': _byDate(rows)}));
      return out;
    });
    _lane = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// 保存一次测试；同一天已有记录就覆盖。
  Future<void> save({
    required String date,
    Object? pushup,
    bool pushupKnee = false,
    Object? plank,
    Object? pullType,
    Object? pull,
  }) async {
    final row = cleanBenchmark(
      date: date,
      pushup: pushup,
      pushupKnee: pushupKnee,
      plank: plank,
      pullType: pullType,
      pull: pull,
    );
    await _write((rows) {
      rows.removeWhere((e) => e['date'] == date);
      rows.add({...row, 'ts': _now()});
    });
  }

  Future<void> remove(String date) => _write((rows) {
    rows.removeWhere((e) => e['date'] == date);
  });
}
