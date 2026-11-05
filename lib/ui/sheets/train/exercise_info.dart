import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../app/app_controller.dart';
import '../../../domain/format.dart';
import '../../../domain/movements.dart';
import '../../../domain/muscles.dart';
import '../../../theme/theme.dart';
import '../../kit/badge.dart';

/// 一个动作的主练肌肉和恢复状态，器械弹层与记组页头部共用。
class ExerciseInfo {
  const ExerciseInfo({
    this.muscles = '',
    this.plain = '',
    this.plainPro = '',
    this.ready,
    this.recovery = '',
  });

  /// 主练肌肉大白话位置（如“大腿前面”），最多两块，给空间紧的行用。
  final String plain;

  /// 同上，括号里带专业名（“大腿前面（股四头肌）”），给头部卡用。
  final String plainPro;

  /// 主练肌肉中文名（权重 ≥ 0.5），按界面语言连好；有氧或认不出的动作为空。
  final String muscles;

  /// 主肌肉是否已恢复；null 表示不显示恢复。
  final bool? ready;
  final String recovery;
}

/// 当前所有肌肉的恢复状态，和“从肌肉找动作”页同一口径。
Map<String, dynamic> recoveryStatus(AppController app) => muscleStatus(
  app.repo.allDays().map((k, v) => MapEntry(k, jsonMap(v))),
  app.clock().millisecondsSinceEpoch,
);

ExerciseInfo exerciseInfo(
  AppMessages messages,
  Map<String, dynamic> status,
  String name,
  String part,
) {
  final mv = musclesOf(name, part);
  // 有氧不算肌肉恢复；“part”是没认出的名字，按部位猜不准，不显示。
  if (mv == null || mv['matched'] == 'part') return const ExerciseInfo();
  final weights = (mv['muscles'] as Map).cast<String, num>();
  final ids =
      weights.entries.where((e) => e.value >= 0.5).map((e) => e.key).toList()
        ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
  if (ids.isEmpty) ids.add(mv['primary'] as String);
  final names = [for (final id in ids) messages.text('${MUSCLE[id]!['name']}')];
  final me = jsonMap(jsonMap(status['byMuscle'])[mv['primary']]);
  final ready = me['daysSince'] == null || me['recovered'] == true;
  final left = jsNumber(me['daysLeft']);
  final roles = muscleRoles(name, part);
  return ExerciseInfo(
    muscles: names.join(messages.code == 'en' ? ', ' : '、'),
    plain: muscleList(messages, roles.main, pro: false, max: 2),
    plainPro: muscleList(messages, roles.main),
    ready: ready,
    recovery: ready ? '可以练' : daysLeftText(left),
  );
}

const _plainEnough = {'chest_up', 'chest', 'calves', 'lower_back', 'mid_back'};

/// 肌肉的大白话位置，可选括号带专业名：“大腿前面（股四头肌）”。
String muscleLabel(AppMessages messages, String id, {bool pro = true}) {
  final plain = messages.text(MUSCLE_PLAIN[id] ?? '${MUSCLE[id]?['name']}');
  // 专业名和大白话差不多的（中下胸、小腿、下背、中背）不再重复加括号。
  if (!pro || MUSCLE_PLAIN[id] == null || _plainEnough.contains(id)) {
    return plain;
  }
  final name = messages.text('${MUSCLE[id]!['name']}');
  return messages.code == 'en' ? '$plain ($name)' : '$plain（$name）';
}

/// 一组肌肉连成一行文字；[max] 限制块数。
String muscleList(
  AppMessages messages,
  List<String> ids, {
  bool pro = true,
  int? max,
}) => [
  for (final id in (max == null ? ids : ids.take(max)))
    muscleLabel(messages, id, pro: pro),
].join(messages.code == 'en' ? ', ' : '、');

/// 主练肌肉的大白话位置（不带专业名），认不出的动作返回空。空间紧的行用。
String plainMusclesOf(
  AppMessages messages,
  String name,
  String part, {
  int max = 2,
}) {
  final mv = musclesOf(name, part);
  if (mv == null || mv['matched'] == 'part') return '';
  return muscleList(
    messages,
    muscleRoles(name, part).main,
    pro: false,
    max: max,
  );
}

/// 还要几天恢复：半天精度，不到 0.75 天写“不到 1”。
String daysLeftText(num left) =>
    left < .75 ? '不到 1 天恢复' : '约 ${fmt((left * 2).round() / 2)} 天恢复';

/// “上次 08/12 · 40×10  45×8”；没记录返回空。
String lastLineOf(Map? last) {
  if (last == null) return '';
  String f(Object? v) => '$v'.replaceFirst(RegExp(r'\.0$'), '');
  final sets = ((last['sets'] as List?) ?? []).cast<Map>();
  final desc = sets
      .map(
        (s) =>
            '${f(s['weight'])}×${s['reps']}${s['type'] != null && s['type'] != '正式' ? ' ${s['type']}' : ''}',
      )
      .join('  ');
  final side = sets.any((s) => '${s['notes']}'.contains('单边')) ? ' · 单边' : '';
  return '上次 ${'${last['date']}'.substring(5).replaceAll('-', '/')} · $desc$side';
}

/// 恢复小标签：可以练用成功色，还要等用警示色。
class RecoveryTag extends StatelessWidget {
  const RecoveryTag(this.info, {super.key});
  final ExerciseInfo info;
  @override
  Widget build(BuildContext context) {
    if (info.ready == null) return const SizedBox.shrink();
    final p = context.pal;
    final warn = ToneBadge.tone(p, 'shoulder', p.bg.computeLuminance() < 0.1);
    final ok = info.ready!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? p.ok.withValues(alpha: 0.14) : warn.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LText(
        info.recovery,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ok ? p.ok : warn.fg,
        ),
      ),
    );
  }
}
