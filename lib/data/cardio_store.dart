import 'dart:convert';

import '../core/native.dart';
import '../domain/cardio.dart';
import '../domain/records.dart' show DomainError;
import 'state_doc.dart' show newId;

/// 有氧记录：独立的附加文档 `fw-cardio-v1`，与力量记录（android-state）完全分开，
/// 所以不会碰到任何力量统计、肌肉恢复和金标。随备份的偏好一起导出导入；
/// 旧备份里没有它，恢复后就是「没有有氧记录」。
///
/// 读-改-写串行执行，两次连续保存不会互相覆盖。距离永远存公里。
class CardioStore {
  CardioStore(this.native, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);
  final Native native;
  final int Function() _now;
  static const key = 'fw-cardio-v1';
  Future<void> _lane = Future<void>.value();

  /// 全部记录，按日期、时间升序。无效的单条会被跳过。
  Future<List<Map<String, dynamic>>> load() async {
    final raw = (await native.all())[key];
    if (raw == null) return [];
    final doc = jsonDecode(raw);
    // 备份恢复会把「没有这份数据」写成 JSON null。
    if (doc == null) return [];
    if (doc is! Map || doc['v'] != 1 || doc['entries'] is! List) {
      throw const FormatException('有氧记录格式无效');
    }
    return _sorted([
      for (final e in doc['entries'] as List) ?tryCleanCardio(e),
    ]);
  }

  static List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> rows) =>
      rows..sort((a, b) {
        final d = '${a['date']}'.compareTo('${b['date']}');
        if (d != 0) return d;
        return ((a['ts'] ?? 0) as num).compareTo((b['ts'] ?? 0) as num);
      });

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
      await native.put(key, jsonEncode({'v': 1, 'entries': _sorted(rows)}));
      return out;
    });
    _lane = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// 新增一条，返回它的 id。
  Future<String> add({
    required String date,
    required String type,
    required int minutes,
    num? distanceKm,
    String? effort,
  }) {
    final row = cleanCardio(
      date: date,
      type: type,
      minutes: minutes,
      distanceKm: distanceKm,
      effort: effort,
    );
    return _write((rows) {
      final id = newId();
      rows.add({'id': id, ...row, 'ts': _now()});
      return id;
    });
  }

  /// 修改一条（日期不变）；不存在时抛 [DomainError]。
  Future<void> update(
    String id, {
    required String type,
    required int minutes,
    num? distanceKm,
    String? effort,
  }) => _write((rows) {
    final at = rows.indexWhere((e) => e['id'] == id);
    if (at < 0) throw const DomainError('记录不存在');
    final row = cleanCardio(
      date: '${rows[at]['date']}',
      type: type,
      minutes: minutes,
      distanceKm: distanceKm,
      effort: effort,
    );
    rows[at] = {
      'id': id,
      ...row,
      if (rows[at]['ts'] != null) 'ts': rows[at]['ts'],
    };
  });

  Future<void> remove(String id) => _write((rows) {
    rows.removeWhere((e) => e['id'] == id);
  });

  /// 撤销删除：用原来的 id 和内容放回去。
  Future<void> restore(Map<String, dynamic> entry) {
    final row = tryCleanCardio(entry);
    if (row == null) return Future.error(const DomainError('记录无效'));
    return _write((rows) {
      rows.removeWhere((e) => e['id'] == row['id']);
      rows.add(row);
    });
  }
}
