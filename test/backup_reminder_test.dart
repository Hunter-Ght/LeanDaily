import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/backup_reminder.dart';

const _day = 24 * 60 * 60 * 1000;
final _now = DateTime.utc(2026, 11, 12, 9).millisecondsSinceEpoch;
const _enough = BackupFacts(trainingDays: 12, spanDays: 20);
const _few = BackupFacts(trainingDays: 3, spanDays: 5);

bool _nudge({
  BackupFacts facts = _enough,
  int? last,
  int? snooze,
  bool system = false,
  int? now,
}) => shouldNudgeBackup(
  facts: facts,
  lastBackupMs: last,
  snoozeUntilMs: snooze,
  nowMs: now ?? _now,
  systemBackupOn: system,
);

void main() {
  group('backupFacts', () {
    test('counts distinct training days and the span to today', () {
      final f = backupFacts(
        trainDates: ['2026-10-01', '2026-10-01', '2026-10-03'],
        mealDates: ['2026-09-28'],
        today: '2026-11-12',
      );
      expect(f.trainingDays, 2);
      expect(f.spanDays, 45);
    });
    test('empty records are zero', () {
      final f = backupFacts(trainDates: [], mealDates: [], today: '2026-11-12');
      expect((f.trainingDays, f.spanDays), (0, 0));
      expect(f.worthBackingUp, isFalse);
    });
    test('a future-dated record never gives a negative span', () {
      final f = backupFacts(
        trainDates: ['2026-12-01'],
        mealDates: [],
        today: '2026-11-12',
      );
      expect(f.spanDays, 0);
    });
    test('worth backing up at 10 training days or 14 days of records', () {
      expect(
        const BackupFacts(trainingDays: 10, spanDays: 3).worthBackingUp,
        isTrue,
      );
      expect(
        const BackupFacts(trainingDays: 9, spanDays: 13).worthBackingUp,
        isFalse,
      );
      expect(
        const BackupFacts(trainingDays: 2, spanDays: 14).worthBackingUp,
        isTrue,
      );
    });
  });

  group('shouldNudgeBackup', () {
    test('never backed up with enough records', () {
      expect(_nudge(), isTrue);
    });
    test('few records stay quiet', () {
      expect(_nudge(facts: _few), isFalse);
    });
    test('recent backup stays quiet, stale one asks again', () {
      expect(_nudge(last: _now - 3 * _day), isFalse);
      expect(_nudge(last: _now - 30 * _day), isFalse);
      expect(_nudge(last: _now - 31 * _day), isTrue);
    });
    test('snooze lasts 14 days and then expires', () {
      final until = backupSnoozeUntil(_now);
      expect(until - _now, 14 * _day);
      expect(_nudge(snooze: until), isFalse);
      expect(_nudge(snooze: until, now: until - 1), isFalse);
      expect(_nudge(snooze: until, now: until), isTrue);
    });
    test('system backup turned on silences the card', () {
      expect(_nudge(system: true), isFalse);
    });
    test('a clock set backwards does not make a fresh backup look stale', () {
      expect(_nudge(last: _now + 90 * _day), isFalse);
    });
  });

  group('backupStatusText', () {
    String t(int? ago) => backupStatusText(
      lastBackupMs: ago == null ? null : _now - ago * _day,
      nowMs: _now,
    );
    test('plain wording, no alarm', () {
      expect(t(null), '还没备份过');
      expect(t(0), '今天已备份');
      expect(t(1), '昨天备份');
      expect(t(3), '3 天前备份');
      expect(t(59), '59 天前备份');
      expect(t(60), '2 个月前备份');
      expect(t(400), '13 个月前备份');
    });
  });
}
