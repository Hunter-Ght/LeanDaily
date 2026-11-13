import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../course/course_widgets.dart' show CoursePhaseTip;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/exercise_thumb.dart';
import '../kit/grouped.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_hero.dart';
import 'today_model.dart';
import '../kit/units_scope.dart';

/// 今日动作：缩略图 + 名称 + 右侧大号「组×次」。
class TodayActions extends StatefulWidget {
  const TodayActions({
    super.key,
    required this.model,
    required this.onOpen,
    required this.onWarm,
    required this.onAdjust,
    required this.onFreeTraining,
  });
  final TodayModel model;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onWarm, onAdjust, onFreeTraining;
  @override
  State<TodayActions> createState() => _TodayActionsState();
}

class _TodayActionsState extends State<TodayActions> {
  bool rulesOpen = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.model, p = context.pal;
    final phase = m.course?.phase;
    // 有课程时，「每组留几次余力」由当前阶段的指引说明，这里不再重复一条旧的。
    final rules = [
      for (final r in m.workout['rules'] as List? ?? [])
        if (phase == null || !'$r'.contains('余力')) r,
    ];
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
          _Header(model: m, onAdjust: widget.onAdjust),
          if (phase != null) CoursePhaseTip(phase: phase),
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
                final weight = last.isNotEmpty
                    ? jsNumber(target['weight'] ?? e['weight'])
                    : context.units.suggestedLoad(
                        jsNumber(target['weight'] ?? e['weight']),
                      );
                final sec = e['unit'] == 'sec';
                final lastLine = !skipped && last.isNotEmpty
                    ? '上次 ${jsNumber(last['weight']) > 0 ? context.units.loadText(jsNumber(last['weight'])) : '自重'} × ${fmt(last['minReps'])}${sec ? ' 秒' : ''}'
                    : '';
                final sub = skipped
                    ? '精简版不练'
                    : [
                        if (weight > 0)
                          '${increased ? '↑ ' : ''}${context.units.loadText(weight)}',
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
          const SizedBox(height: 12),
          TodayLinkCard(
            children: [
              if (rules.isNotEmpty)
                Column(
                  children: [
                    GroupRow(
                      label: '今天要记住的 ${rules.length} 点',
                      icon: 'note',
                      onTap: () => setState(() => rulesOpen = !rulesOpen),
                      chevron: false,
                      trailing: _ExpandArrow(
                        open: rulesOpen,
                        onTap: () => setState(() => rulesOpen = !rulesOpen),
                      ),
                    ),
                    Reveal(
                      visible: rulesOpen,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(58, 0, 16, 14),
                        child: Align(
                          alignment: Alignment.centerLeft,
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
                    ),
                  ],
                ),
              TodayFreeTrainingRow(onTap: widget.onFreeTraining),
            ],
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

/// 「今日动作」标题；右侧是「调整」入口，当前状态（有点累 / 精简）用小标签标出。
class _Header extends StatelessWidget {
  const _Header({required this.model, required this.onAdjust});
  final TodayModel model;
  final VoidCallback onAdjust;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          LText('今日动作', style: AppText.title(p)),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: AppMessages.of(context).text(adjustmentSummary(model)),
            child: Pressable(
              onTap: onAdjust,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final part in adjustmentParts(model)) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: p.fill2,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: LText(
                          part,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    LText(
                      '调整',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AppIcon('right', size: 14, color: p.text),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandArrow extends StatelessWidget {
  const _ExpandArrow({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 44,
        child: Center(
          child: AnimatedRotation(
            turns: open ? .25 : 0,
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
            ),
            child: AppIcon('right', size: 14, color: context.pal.tertiary),
          ),
        ),
      ),
    ),
  );
}

/// 首页动作列表下方的入口行：一张分组卡，图标块用中性底色。
class TodayLinkCard extends StatelessWidget {
  const TodayLinkCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      GroupScope(child: GroupCard(children: children));
}

/// 自由练入口：不按计划时看现在能练什么，训练日和休息日都显示。
class TodayFreeTrainingRow extends StatelessWidget {
  const TodayFreeTrainingRow({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GroupRow(
    key: const ValueKey('free-training'),
    label: '自由练',
    sub: '现在能练什么',
    icon: 'spark',
    onTap: onTap,
  );
}
