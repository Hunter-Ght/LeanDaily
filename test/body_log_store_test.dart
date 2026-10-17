import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/body_log_store.dart';

void main() {
  test('same date replaces, queued dates survive and reload', () async {
    final native = FakeNative();
    final store = BodyLogStore(native);
    await Future.wait([
      store.record(date: '2026-10-15', weightKg: 70, waistCm: 80),
      store.record(date: '2026-10-16', weightKg: 69),
      store.record(date: '2026-10-15', weightKg: 68),
    ]);
    expect(await BodyLogStore(native).load(), [
      {'date': '2026-10-15', 'weightKg': 68},
      {'date': '2026-10-16', 'weightKg': 69},
    ]);
  });
  test(
    'invalid measurements and failed writes preserve data; lane recovers',
    () async {
      final native = FakeNative();
      final store = BodyLogStore(native);
      await expectLater(
        store.record(date: '2026-02-30', weightKg: 70),
        throwsFormatException,
      );
      await expectLater(
        store.record(date: '2026-10-15', weightKg: double.nan),
        throwsFormatException,
      );
      await expectLater(
        store.record(date: '2026-10-15', weightKg: 70, waistCm: 0),
        throwsFormatException,
      );
      native.failNextPut = StateError('disk');
      await expectLater(
        store.record(date: '2026-10-15', weightKg: 70),
        throwsStateError,
      );
      expect(await store.load(), isEmpty);
      await store.record(date: '2026-10-15', weightKg: 71);
      expect((await store.load()).single['weightKg'], 71);
      // 读取损坏的文档时仍报错（启动时据此当作没有记录）……
      native.docs[BodyLogStore.key] = '{broken';
      await expectLater(store.load(), throwsFormatException);
      // ……但写入不会被一份坏数据永远堵住：原文另存一份，再从空白记起。
      await store.record(date: '2026-10-16', weightKg: 70);
      expect(native.docs['${BodyLogStore.key}-corrupt'], '{broken');
      expect((await store.load()).single['weightKg'], 70);
      // JSON null（备份恢复写入的“没有数据”）等同没有记录，不算损坏。
      native.docs[BodyLogStore.key] = 'null';
      expect(await store.load(), isEmpty);
    },
  );
}
