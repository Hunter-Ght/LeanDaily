import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/backup.dart';
import 'package:leandaily/data/cardio_store.dart';
import 'package:leandaily/data/repository.dart';
import 'package:leandaily/domain/cardio.dart';
import 'package:leandaily/domain/records.dart';
import 'package:leandaily/domain/units.dart';
import 'package:leandaily/domain/week_achievement.dart';
import 'package:leandaily/domain/weekly_review.dart';

void main() {
  group('校验', () {
    test('合法记录只留需要的字段，距离存公里', () {
      expect(
        cleanCardio(
          date: '2026-10-15',
          type: 'run',
          minutes: '30',
          distanceKm: 5.2,
          effort: 'hard',
        ),
        {
          'date': '2026-10-15',
          'type': 'run',
          'minutes': 30,
          'distanceKm': 5.2,
          'effort': 'hard',
        },
      );
      expect(
        cleanCardio(
          date: '2026-10-15',
          type: 'walk',
          minutes: 20,
          distanceKm: '',
        ),
        {'date': '2026-10-15', 'type': 'walk', 'minutes': 20},
      );
    });
    test('无效输入抛错', () {
      DomainError? err(Map<String, Object?> a) {
        try {
          cleanCardio(
            date: (a['date'] ?? '2026-10-15') as String,
            type: a['type'] ?? 'walk',
            minutes: a['minutes'] ?? 20,
            distanceKm: a['km'],
            effort: a['effort'],
          );
        } on DomainError catch (e) {
          return e;
        }
        return null;
      }

      expect(err({'date': '2026-02-30'}), isNotNull);
      expect(err({'type': 'yoga'}), isNotNull);
      expect(err({'minutes': 0}), isNotNull);
      expect(err({'minutes': 601}), isNotNull);
      expect(err({'minutes': 20.5}), isNotNull);
      expect(err({'km': -1}), isNotNull);
      expect(err({'effort': 'max'}), isNotNull);
      expect(err({'minutes': 600}), isNull);
    });
  });

  group('坚持规则：有氧算活动日，不算完成力量训练', () {
    test('一天的活动：力量优先于有氧', () {
      expect(dayActivity(strength: false, cardio: false), DayActivity.none);
      expect(dayActivity(strength: false, cardio: true), DayActivity.cardio);
      expect(dayActivity(strength: true, cardio: true), DayActivity.strength);
      expect(dayActivity(strength: true, cardio: false), DayActivity.strength);
    });
    test('训练天数只数力量日', () {
      final week = weekActivity(
        weekDays: ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        strengthDates: {'a', 'c'},
        cardioDates: {'b', 'c', 'd'},
      );
      expect(week[1], DayActivity.cardio);
      expect(trainingDays(week), 2);
      expect(cardioOnlyDays(week), 2);
    });
    test('连续天数：有氧日不断，今天还没记从昨天数', () {
      const today = '2026-10-15';
      expect(
        activeStreak(
          today: today,
          strengthDates: {'2026-10-15', '2026-10-13'},
          cardioDates: {'2026-10-14'},
        ),
        3,
      );
      // 只有力量时，中间隔一天就断（原行为）。
      expect(
        activeStreak(
          today: today,
          strengthDates: {'2026-10-15', '2026-10-13'},
          cardioDates: {},
        ),
        1,
      );
      // 今天没记，昨天起算。
      expect(
        activeStreak(
          today: today,
          strengthDates: {'2026-10-13'},
          cardioDates: {'2026-10-14'},
        ),
        2,
      );
      expect(activeStreak(today: today, strengthDates: {}, cardioDates: {}), 0);
    });
    test('周达成：有氧日 train 仍为假', () {
      final hits = weekHits(
        weekDays: [
          {'iso': '2026-10-12', 'train': true, 'kcal': 0},
          {'iso': '2026-10-13', 'train': false, 'kcal': 0},
        ],
        meals: {},
        proteinGoal: 100,
        kcalGoal: 2000,
        cardioDates: {'2026-10-13'},
      );
      expect(hits.map((h) => h.train), [true, false]);
      expect(hits.map((h) => h.cardio), [false, true]);
      expect(hits[1].activity, DayActivity.cardio);
    });
  });

  group('距离单位', () {
    test('公制 km，英制 mi，存储一律公里', () {
      expect(Units.metric.distanceUnit, 'km');
      expect(Units.imperial.distanceUnit, 'mi');
      expect(Units.metric.distanceText(5.2), '5.2 km');
      expect(Units.imperial.distanceText(5), '3.1 mi');
      expect(Units.metric.distanceToKm(5.2), 5.2);
      final km = Units.imperial.distanceToKm(3.1);
      expect(km, closeTo(4.989, .001));
      expect(Units.imperial.distance(km), '3.1'); // 往返不漂移
    });
  });

  group('存储', () {
    test('往返、修改、删除与撤销', () async {
      final native = FakeNative();
      final store = CardioStore(native, now: () => 1000);
      final id = await store.add(
        date: '2026-10-15',
        type: 'bike',
        minutes: 40,
        distanceKm: 12.5,
        effort: 'easy',
      );
      await store.add(date: '2026-10-14', type: 'walk', minutes: 20);
      var rows = await CardioStore(native).load();
      expect(rows.map((r) => r['date']), ['2026-10-14', '2026-10-15']);
      expect(rows.last, {
        'id': id,
        'date': '2026-10-15',
        'type': 'bike',
        'minutes': 40,
        'distanceKm': 12.5,
        'effort': 'easy',
        'ts': 1000,
      });
      await store.update(id, type: 'run', minutes: 25);
      rows = await store.load();
      expect(rows.last['type'], 'run');
      expect(rows.last.containsKey('distanceKm'), false);
      expect(rows.last['date'], '2026-10-15');
      final removed = rows.last;
      await store.remove(id);
      expect(await store.load(), hasLength(1));
      await store.restore(removed);
      expect((await store.load()).last['id'], id);
      await expectLater(
        store.update('nope', type: 'run', minutes: 10),
        throwsA(isA<DomainError>()),
      );
    });
    test('并发保存互不覆盖；坏文档不挡写入；坏条目被跳过', () async {
      final native = FakeNative();
      final store = CardioStore(native);
      await Future.wait([
        for (var i = 1; i <= 5; i++)
          store.add(
            date: '2026-10-1$i'.substring(0, 10),
            type: 'walk',
            minutes: i,
          ),
      ]);
      expect(await store.load(), hasLength(5));
      native.docs[CardioStore.key] = jsonEncode({
        'v': 1,
        'entries': [
          {'id': 'x', 'date': '2026-10-15', 'type': 'walk', 'minutes': 10},
          {'id': 'y', 'date': 'bad', 'type': 'walk', 'minutes': 10},
          'junk',
        ],
      });
      expect(await store.load(), hasLength(1));
      native.docs[CardioStore.key] = '{broken';
      await expectLater(store.load(), throwsFormatException);
      await store.add(date: '2026-10-15', type: 'run', minutes: 30);
      expect(native.docs['${CardioStore.key}-corrupt'], '{broken');
      native.docs[CardioStore.key] = 'null';
      expect(await store.load(), isEmpty);
    });
    test('不碰力量记录文档', () async {
      final native = FakeNative();
      await CardioStore(native)
          .add(date: '2026-10-15', type: 'walk', minutes: 20);
      expect(native.docs.keys, [CardioStore.key]);
    });
  });

  group('备份', () {
    test('导出带上有氧，恢复后一致；旧备份恢复后没有有氧', () async {
      final source = FakeNative();
      final repo = Repository(source);
      await repo.load();
      await CardioStore(source).add(
        date: '2026-10-15',
        type: 'swim',
        minutes: 45,
        distanceKm: 1.5,
        effort: 'moderate',
      );
      final backup = await exportBackup(source, repo);
      final before = await CardioStore(source).load();
      expect(backup['preferences'][CardioStore.key], isA<String>());

      final target = FakeNative();
      final targetRepo = Repository(target);
      await targetRepo.load();
      await restoreBackup(target, targetRepo, backup);
      expect(await CardioStore(target).load(), before);

      // 旧备份没有这个键：恢复后清空有氧，不报错。
      final old = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
      (old['preferences'] as Map).remove(CardioStore.key);
      await restoreBackup(target, targetRepo, old);
      expect(await CardioStore(target).load(), isEmpty);
    });
  });

  group('每周回顾', () {
    Map<String, dynamic>? review(List<Map<String, dynamic>> cardio) =>
        weeklyReview(
          today: '2026-10-19',
          days: {},
          meals: (_) => {},
          bodyEntries: [],
          stage: null,
          kcalGoal: 2000,
          proteinGoal: 100,
          trainTarget: 3,
          kcalFloor: 1200,
          done: '',
          cardio: cardio,
        );
    test('有氧天数计入有记录的天数，并汇总分钟，不进训练天数', () {
      expect(review([]), isNull);
      final r = review([
        for (final (i, d) in ['2026-10-12', '2026-10-14', '2026-10-15'].indexed)
          {'id': '$i', 'date': d, 'type': 'walk', 'minutes': 20 + i * 10},
        {'id': 'x', 'date': '2026-10-19', 'type': 'walk', 'minutes': 99},
      ])!;
      expect(r['cardioMinutes'], 20 + 30 + 40);
      expect(r['trainDays'], 0);
    });
  });
}
