import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/profile_store.dart';
import 'package:leandaily/domain/body.dart';

class DelayedNative extends FakeNative {
  Completer<void>? gate;
  final writes = <String>[];
  @override
  Future<void> put(String key, String value) async {
    writes.add(key);
    await gate?.future;
    await super.put(key, value);
  }
}

void main() {
  test('首次/老用户读取不写入、不自动完成引导', () async {
    final native = FakeNative()..docs['fw-plan-v1'] = '{"legacy":true}';
    final store = ProfileStore(native);
    expect(await store.load(), isNull);
    expect(store.profile, isNull);
    expect(store.onboarded, false);
    expect(native.putCount, 0);
    expect(native.docs, {'fw-plan-v1': '{"legacy":true}'});
  });

  test('JSON 往返、规范化、隔离可变列表，保留其他文档', () async {
    final native = FakeNative()..docs['android-state'] = '{"version":1}';
    final store = ProfileStore(native);
    final input = {
      ...profileDefaults,
      'age': 100,
      'limits': ['膝'],
    };
    final saved = await store.save(input);
    expect(saved['age'], 90);
    expect(native.json(ProfileStore.profileKey), saved);
    expect(native.docs.containsKey(ProfileStore.onboardedKey), false);
    (input['limits'] as List).clear();
    (saved['limits'] as List).clear();
    (store.profile!['limits'] as List).clear();
    expect(store.profile!['limits'], ['膝']);
    await store.markOnboarded();
    expect(native.docs[ProfileStore.onboardedKey], '1');
    final reopened = ProfileStore(native);
    expect(await reopened.load(), store.profile);
    expect(reopened.onboarded, true);
    expect(native.docs['android-state'], '{"version":1}');
  });

  test('损坏或非对象文档安全降级，不覆盖原值', () async {
    for (final raw in ['{broken', 'null', '[]', '42', '"text"']) {
      final native = FakeNative()
        ..docs[ProfileStore.profileKey] = raw
        ..docs[ProfileStore.onboardedKey] = 'true';
      final store = ProfileStore(native);
      expect(await store.load(), isNull);
      expect(store.onboarded, false);
      expect(native.docs[ProfileStore.profileKey], raw);
      expect(native.putCount, 0);
    }
    final native = FakeNative()
      ..docs[ProfileStore.profileKey] = '{"age":1,"limits":null}';
    final loaded = await ProfileStore(native).load();
    expect(loaded!['age'], 10);
    expect(loaded['limits'], isEmpty);
  });

  test('失败时不更新内存或文档；之后的操作仍可成功', () async {
    final native = FakeNative();
    final store = ProfileStore(native);
    await store.save({...profileDefaults, 'age': 30});
    final before = Map.of(native.docs);
    native.failNextPut = StateError('disk full');
    await expectLater(
      store.save({...profileDefaults, 'age': 40}),
      throwsStateError,
    );
    expect(store.profile!['age'], 30);
    expect(native.docs, before);
    native.failNextPut = StateError('disk full');
    await expectLater(store.markOnboarded(), throwsStateError);
    expect(store.onboarded, false);
    expect(native.docs, before);
    await store.save({...profileDefaults, 'age': 50});
    await store.markOnboarded();
    expect(store.profile!['age'], 50);
    expect(store.onboarded, true);
  });

  test('save、标记、load 串行；排队时立即快照输入', () async {
    final native = DelayedNative()..gate = Completer<void>();
    final store = ProfileStore(native);
    final input = {
      ...profileDefaults,
      'age': 30,
      'limits': ['肩'],
    };
    final first = store.save(input);
    input['age'] = 90;
    (input['limits'] as List).clear();
    final second = store.save({...profileDefaults, 'age': 40});
    final third = store.markOnboarded();
    final loaded = store.load();
    await Future<void>.delayed(Duration.zero);
    expect(native.writes, [ProfileStore.profileKey]);
    expect(store.profile, isNull);
    expect(store.onboarded, false);
    native.gate!.complete();
    expect((await first)['age'], 30);
    expect((await first)['limits'], ['肩']);
    await second;
    await third;
    expect((await loaded)!['age'], 40);
    expect(store.onboarded, true);
    expect(native.writes, [
      ProfileStore.profileKey,
      ProfileStore.profileKey,
      ProfileStore.onboardedKey,
    ]);
    expect(jsonDecode(native.docs[ProfileStore.profileKey]!)['age'], 40);
  });

  test('排队写入失败后继续执行后一条，load 不会读到旧快照', () async {
    final native = DelayedNative()
      ..gate = Completer<void>()
      ..failNextPut = StateError('first write failed');
    final store = ProfileStore(native);
    final first = store.save({...profileDefaults, 'age': 30});
    final failure = expectLater(first, throwsStateError);
    final second = store.save({...profileDefaults, 'age': 40});
    final loaded = store.load();
    native.gate!.complete();
    await failure;
    await second;
    expect((await loaded)!['age'], 40);
  });
}
