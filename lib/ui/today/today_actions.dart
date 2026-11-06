import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_model.dart';
import 'today_widgets.dart';

/// 今日动作：缩略图 + 名称 + 右侧大号「组×次」。
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
    final warmItems = (jsonMap(m.workout['warmup'])['items'] as List? ?? [])
        .join('、');
    final warmDone = jsTruthy(m.state['warm']);
    Widget divider() => Container(
      height: .5,
      margin: const EdgeInsets.only(left: 68),
      color: p.sep,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: LText('今日动作', style: AppText.title(p)),
          ),
          Semantics(
            button: true,
            label: AppMessages.of(context)
                .text('热身 ${jsonMap(m.workout['warmup'])['minutes']} 分钟'),
            child: Pressable(
              onTap: widget.onWarm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: warmDone ? p.recoverSoft : p.fill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: FadeSwitcher(
                          child: AppIcon(
                            warmDone ? 'check' : 'flame',
                            key: ValueKey(warmDone),
                            size: 22,
                            color: warmDone ? p.recover : p.tertiary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LText(
                            '热身 ${jsonMap(m.workout['warmup'])['minutes']} 分钟',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                          if (warmItems.isNotEmpty)
                            LText(
                              warmItems,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: p.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final e in m.all) ...[
            divider(),
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
                    (jsNumber(target['weight']) > jsNumber(last['weight']) ||
                        jsNumber(target['reps']) > jsNumber(last['minReps']));
                final skipped = m.lite && item == null;
                final done = jsNumber(item?['done']);
                final complete = jsTruthy(item?['complete']);
                final sets = target['sets'] ?? e['sets'];
                final weight = jsNumber(target['weight'] ?? e['weight']);
                final sec = e['unit'] == 'sec';
                final lastLine = !skipped && last.isNotEmpty
                    ? '上次 ${jsNumber(last['weight']) > 0 ? '${fmt(last['weight'])} kg' : '自重'} × ${fmt(last['minReps'])}${sec ? ' 秒' : ''}'
                    : '';
                final sub = skipped
                    ? '精简版不练'
                    : [
                        if (weight > 0)
                          '${increased ? '↑ ' : ''}${fmt(weight)} kg',
                        if (done > 0 && !complete)
                          '已练 ${fmt(done)}/${fmt(sets)} 组',
                      ].join('  ');
                return Opacity(
                  opacity: skipped ? .5 : 1,
                  child: Semantics(
                    button: true,
                    label: AppMessages.of(context)
                        .text('${e['name']}，${m.started ? '进入训练' : '看示范'}'),
                    child: Pressable(
                      onTap: () => widget.onOpen(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            ExerciseThumb(ex: e),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LText(
                                    '${e['name']}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: p.text,
                                    ),
                                  ),
                                  if (sub.isNotEmpty)
                                    LText(
                                      sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: increased && !skipped
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: increased && !skipped
                                            ? p.text
                                            : p.secondary,
                                      ),
                                    ),
                                  if (lastLine.isNotEmpty)
                                    LText(
                                      lastLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.tertiary,
                                      ),
                                    ),
                                  if (jsTruthy(e['optional']))
                                    LText(
                                      '可选',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.tertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!skipped)
                              _StatusFade(
                                child: complete
                                    ? Container(
                                        key: const ValueKey('complete'),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: p.recoverSoft,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: AppIcon(
                                            'check',
                                            size: 16,
                                            color: p.recover,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        key: ValueKey('rx-$done-$sets'),
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '${fmt(sets)}×${fmt(target['reps'] ?? e['min'])}',
                                            style: AppText.num(p, 24),
                                          ),
                                          if (sec) ...[
                                            const SizedBox(width: 2),
                                            LText(
                                              '秒',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: p.secondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          if (rules.isNotEmpty)
            TodayButton(
              '今天要记住的 ${rules.length} 点 ›',
              onTap: () => setState(() => rulesOpen = !rulesOpen),
            ),
          Reveal(
            visible: rulesOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LText(
                rules.join('\n'),
                style: TextStyle(fontSize: 13, height: 1.6, color: p.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右侧状态（组×次 / 完成勾）切换时只淡入淡出，不做尺寸动画，避免过渡期溢出。
class _StatusFade extends StatelessWidget {
  const _StatusFade({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
}
