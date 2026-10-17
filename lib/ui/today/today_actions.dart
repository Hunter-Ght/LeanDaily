import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/exercise_thumb.dart';
import '../kit/grouped.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_model.dart';
import 'today_widgets.dart';

class TodayActions extends StatefulWidget {
  const TodayActions({
    super.key,
    required this.model,
    required this.onOpen,
    required this.onWarm,
  });
  final TodayModel model;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onWarm;
  @override
  State<TodayActions> createState() => _TodayActionsState();
}

class _TodayActionsState extends State<TodayActions> {
  bool rulesOpen = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.model, p = context.pal;
    final rules = m.workout['rules'] as List? ?? [];
    return GroupScope(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GroupHeader('今日动作'),
            GroupCard(
              children: [
                GroupRow(
                  label: '热身 ${jsonMap(m.workout['warmup'])['minutes']} 分钟',
                  sub: (jsonMap(m.workout['warmup'])['items'] as List? ?? [])
                      .join(' · '),
                  onTap: widget.onWarm,
                  chevron: false,
                  trailing: FadeSwitcher(
                    child: AppIcon(
                      jsTruthy(m.state['warm']) ? 'check' : 'flame',
                      key: ValueKey(jsTruthy(m.state['warm'])),
                      size: 20,
                      color: jsTruthy(m.state['warm']) ? p.ok : p.tertiary,
                    ),
                  ),
                ),
                for (final e in m.all)
                  Builder(
                    key: ValueKey(e['id']),
                    builder: (context) {
                      final item = m.items
                          .where((i) => jsonMap(i['ex'])['id'] == e['id'])
                          .firstOrNull;
                      final target = m.before['${e['id']}'] ?? e;
                      final last = jsonMap(target['last']);
                      final increased =
                          last.isNotEmpty &&
                          (jsNumber(target['weight']) >
                                  jsNumber(last['weight']) ||
                              jsNumber(target['reps']) >
                                  jsNumber(last['minReps']));
                      final skipped = m.lite && item == null;
                      final done = jsNumber(item?['done']);
                      return Semantics(
                        button: true,
                        label: AppMessages.of(context)
                            .text('${e['name']}，${m.started ? '进入训练' : '看示范'}'),
                        child: Pressable(
                          onTap: () => widget.onOpen(e),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ExerciseThumb(ex: e),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      LText(
                                        '${e['name']}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: p.text,
                                        ),
                                      ),
                                      LText(
                                        skipped
                                            ? '精简版不练'
                                            : '${fmt(target['sets'] ?? e['sets'])} 组 × ${fmt(target['reps'] ?? e['min'])} ${e['unit'] == 'sec' ? '秒' : '次'}${jsNumber(target['weight'] ?? e['weight']) > 0 ? ' · ${fmt(target['weight'] ?? e['weight'])} kg' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: increased && !skipped
                                              ? p.text
                                              : p.secondary,
                                          fontWeight: increased && !skipped
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      if (!skipped && last.isNotEmpty)
                                        LText(
                                          '上次 ${jsNumber(last['weight']) > 0 ? '${fmt(last['weight'])} kg' : '自重'} × ${fmt(last['minReps'])}${e['unit'] == 'sec' ? ' 秒' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: p.secondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                FadeSwitcher(
                                  child: jsTruthy(item?['complete'])
                                      ? AppIcon(
                                          'check',
                                          key: const ValueKey('complete'),
                                          size: 18,
                                          color: p.ok,
                                        )
                                      : LText(
                                          key: ValueKey(
                                            'progress-$done-${target['sets'] ?? e['sets']}',
                                          ),
                                          done > 0
                                              ? '${fmt(done)}/${fmt(target['sets'] ?? e['sets'])} 组'
                                              : '未开始',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: p.secondary,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (rules.isNotEmpty)
              TodayButton(
                '今天要记住的 ${rules.length} 点 ›',
                onTap: () => setState(() => rulesOpen = !rulesOpen),
              ),
            Reveal(
              visible: rulesOpen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LText(
                  rules.join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: p.secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
