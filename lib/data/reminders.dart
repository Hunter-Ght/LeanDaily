import 'dart:async';

import '../core/native.dart';
import '../domain/records.dart';
import 'repository.dart' show Clock;

class PlanNote {
  const PlanNote({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });
  final int id;
  final String title, body;
  final DateTime at;
}

class Reminders {
  Reminders(this.native, {Clock? clock}) : clock = clock ?? DateTime.now;
  final Native native;
  final Clock clock;
  String Function(String) translate = (text) => text;
  Future<void> _lane = Future.value();
  Future<void> _enqueue(Future<void> Function() action) {
    final p = _lane.then((_) => action());
    _lane = p.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return p;
  }

  Future<void> enableReminders() => _enqueue(() async {
    if (!await native.requestNotify()) {
      throw const DomainError('通知权限未开启，将仅显示页面倒计时');
    }
    if (!(await native.notifyState()).exact) {
      await native.openExactAlarmSettings();
    }
  });
  Future<void> scheduleRest(int untilMs) => _enqueue(() async {
    await native.cancel([1]);
    if (untilMs <= clock().millisecondsSinceEpoch) return;
    if (!(await native.notifyState()).granted) {
      throw const DomainError('锁屏提醒未开启，可在 APP 设置中开启');
    }
    await native.schedule([
      ScheduledNote(
        id: 1,
        title: translate('休息好了'),
        body: translate('可以开始下一组训练了'),
        atMs: untilMs,
      ),
    ]);
  });
  Future<bool> planNotifyGranted() async =>
      (await native.notifyState()).granted;
  Future<void> enablePlanReminders() => _enqueue(() async {
    if (!await native.requestNotify()) {
      throw const DomainError('通知权限未开启，请在系统设置里允许「薄肌日课」发送通知');
    }
  });
  Future<void> applyPlan(List<PlanNote> list) => _enqueue(() async {
    final old = (await native.pendingIds()).where((id) => id >= 1000).toList();
    if (old.isNotEmpty) await native.cancel(old);
    if (list.isEmpty || !await planNotifyGranted()) return;
    await native.schedule([
      for (final n in list)
        ScheduledNote(
          id: n.id,
          title: n.title,
          body: n.body,
          atMs: n.at.millisecondsSinceEpoch,
          plan: true,
        ),
    ]);
  });
}
