import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/wordmark.dart';
import 'workout_title.dart';
import '../stats/weekly_review_card.dart';
import '../kit/menu.dart';
import '../kit/grouped.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import '../kit/segments.dart';
import 'guide_body.dart';
import 'today_model.dart';
import 'today_widgets.dart';
import '../kit/sheet.dart';
import 'today_hero.dart';
import 'venue_controls.dart';
import 'today_rest_card.dart';
import 'today_week_card.dart';
import 'today_tip_card.dart';
import 'today_actions.dart';
import 'today_nutrition_strip.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.wide, required this.two});
  final bool wide, two;
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _scroll = ScrollController();
  String _focus = '';
  bool _showSuggestions = false;
  bool _enteringTraining = false;
  bool _notifyOk = true, _notifyChecked = false;
  AppController? _app;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = context.app;
    if (!_notifyChecked) {
      _notifyChecked = true;
      _app!.reminders
          .planNotifyGranted()
          .then((ok) {
            if (mounted) setState(() => _notifyOk = ok);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _scroll.dispose();

    super.dispose();
  }

  Future<void> patch(Map<String, dynamic> value) async {
    try {
      await _app!.patchDayState(_app!.today, value);
    } on Object catch (e) {
      _app!.toast.show(AppController.message(e));
    }
  }

  Future<void> swap(TodayModel m) async {
    final picked = await showActionMenu(
      context,
      actions: [
        for (final id in m.app.plan['order'] as List)
          MenuAction(
            id: '$id',
            label: workoutTitle('${m.app.plan['workouts'][id]['name']}'),
            icon: 'train',
          ),
        const MenuAction(id: 'rest', label: '今天休息', icon: 'moon'),
      ],
    );
    if (picked != null) {
      await patch({'override': picked.id});
    }
  }

  bool _switchingVenue = false;

  Future<void> chooseVenue(TodayModel m) async {
    final picked = await showActionMenu(
      context,
      title: '今天在哪练',
      actions: [
        for (final v in const {'home': '居家', 'gym': '健身房'}.entries)
          MenuAction(
            id: v.key,
            label: v.value,
            icon: m.workout['venue'] == v.key ? 'check' : null,
          ),
      ],
    );
    if (picked != null && mounted) await venue(m, picked.id);
  }

  Future<void> venue(TodayModel m, String v) async {
    if (_switchingVenue || v == m.workout['venue']) return;
    _switchingVenue = true;
    try {
      if (jsonRows(m.day['sets']).any((s) => s['type'] != '热身') &&
          !await showConfirm(
            context,
            title: '改成${v == 'gym' ? '健身房' : '居家'}版？',
            message: '今天已经记过训练，切换不会删除已记的组。两个版本不要叠加着做，训练量会翻倍。',
            confirm: '切换',
          )) {
        return;
      }
      if (!mounted) return;
      await m.app.patchDayState(m.iso, {
        'venue': v,
        'swaps': {},
        'started': false,
      });
      m.app.toast.show(v == 'gym' ? '已切换到健身房版' : '已切换到居家版');
      if (!mounted || !m.app.shouldAskVenueDefault(m.iso, v)) return;
      final day = weekday(m.iso);
      final label = v == 'gym' ? '健身房' : '居家';
      final remember = await showVenueDefaultConfirm(
        context,
        title: '以后每$day都在$label练？',
      );
      if (remember == true) {
        await m.app.setWeekdayVenue(plan.dow(m.iso), v);
        m.app.toast.show('已设置：每$day默认$label');
      } else if (remember == false) {
        await m.app.declineVenueHint(plan.dow(m.iso));
      }
    } on Object catch (e) {
      m.app.toast.show(AppController.message(e));
    } finally {
      _switchingVenue = false;
    }
  }

  Future<void> accept(Map<String, dynamic> s) async {
    if (jsonMap(s['accept'])['type'] == 'ladder' &&
        !await showConfirm(
          context,
          title: '${s['acceptLabel']}？',
          message: '记录会换成新的动作名，旧记录都保留。',
          confirm: '确定',
        )) {
      return;
    }
    try {
      await _app!.acceptSuggestion(s);
      _app!.toast.show(
        s['kind'] == 'deload' ? '本周已减量，下周自动恢复' : '已更新：${s['ex']}',
      );
    } on Object catch (e) {
      _app!.toast.show(AppController.message(e));
    }
  }

  void guide(Map<String, dynamic> e, String iso) {
    if (widget.two) {
      setState(() => _focus = '${e['id']}');
    } else {
      openGuide(context, '${e['name']}', iso: iso);
    }
  }

  Widget text(
    String s, {
    double size = 14,
    bool bold = false,
    Color? color,
    double height = 1.45,
  }) => LText(
    s,
    style: TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      height: height,
      color: color ?? context.pal.secondary,
    ),
  );
  Widget title(String s) =>
      text(s, size: 17, bold: true, color: context.pal.text);
  Widget segment(List<String> labels, int selected, ValueChanged<int> onTap) =>
      AppSegments(labels: labels, selected: selected, onChanged: onTap);

  Widget recovery(TodayModel m) {
    final p = context.pal;
    final tired = m.recovery
        .where((e) => !jsTruthy(e['recovered']) && jsNumber(e['daysLeft']) >= 1)
        .toList();
    String left(Object? days) {
      final d = jsNumber(days);
      return d < .75 ? '不到 1 天' : '约 ${fmt((d * 2).round() / 2)} 天';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text('今天练到的肌肉', size: 12, bold: true),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in m.recovery)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tired.contains(e) ? p.tintSoft : p.fill2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: LText.rich(
                    TextSpan(
                      text: '${e['name']}  ',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: jsTruthy(e['recovered'])
                              ? '已恢复'
                              : '还需${left(e['daysLeft'])}',
                          style: TextStyle(fontSize: 12, color: p.secondary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (tired.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: text(
                '${tired.map((e) => e['name']).join('、')}还没完全恢复。感觉累就每个动作少做 1 组或把重量降一点；不舒服就选 30 分钟精简版，别硬撑。',
                size: 12,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> start(TodayModel m) async {
    if (!m.train || m.complete || _enteringTraining) return;
    _enteringTraining = true;
    try {
      if (mounted) {
        await openTrainingMode(context, exerciseId: m.firstOpen, haptic: true);
      }
    } on Object catch (error) {
      if (mounted) _app!.toast.show(AppController.message(error));
    } finally {
      _enteringTraining = false;
    }
  }

  void adjust() {
    showAppSheet<void>(
      context,
      (sheetContext) => ListenableBuilder(
        listenable: _app!,
        builder: (context, _) {
          final m = TodayModel(_app!);
          return AppSheet(
            title: '调整今天的训练',
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      text('今天状态', size: 13),
                      const SizedBox(height: 8),
                      segment(
                        ['正常', '有点累', '不舒服'],
                        const [
                          'ok',
                          'tired',
                          'bad',
                        ].indexOf(m.ready).clamp(0, 2),
                        (i) => patch({
                          'ready': i == 0
                              ? null
                              : const ['ok', 'tired', 'bad'][i],
                        }),
                      ),
                      const SizedBox(height: 16),
                      segment(
                        ['完整', '精简'],
                        m.lite ? 1 : 0,
                        (i) => patch({'lite': i == 1}),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                GroupCard(
                  children: [
                    GroupRow(label: '改练别的', onTap: () => swap(m)),
                    if (jsTruthy(m.slot['overridden']))
                      GroupRow(
                        label: '恢复原计划',
                        onTap: () => patch({'override': null}),
                      ),
                    if (m.recovery.isNotEmpty)
                      _RecoveryPanel(content: recovery(m)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.app,
    builder: (context, _) {
      final app = context.app, p = context.pal;
      if (app.plan.isEmpty || app.today.isEmpty) return const SizedBox.shrink();
      final m = TodayModel(app);

      final sideList = m.train
          ? m.all
          : m.next != null
          ? plan.exercisesFor(
              app.plan,
              jsonMap(m.next!['workout']),
              '${m.next!['iso']}',
            )
          : <Map<String, dynamic>>[];
      final focus =
          sideList.where((e) => e['id'] == _focus).firstOrNull ??
          sideList.where((e) => e['id'] == m.firstOpen).firstOrNull ??
          sideList.firstOrNull;
      final review = weeklyReviewFor(app);
      final tips = <TodayTipCard>[
        if (m.ready == 'bad')
          TodayTipCard(
            model: m,
            key: const ValueKey('safety'),
            heading: '身体不舒服就别硬练',
            priority: 0,
            body: '出现疼痛（不是普通的酸）、异常无力、肌肉剧痛肿胀或尿色很深时，请停止训练，尽快看医生。今天这次不计入进度，不会影响明天的目标。',
            actions: [
              if (m.train)
                TodayButton(
                  '今天休息',

                  onTap: () {
                    patch({'override': 'rest', 'ready': 'bad'});
                    app.toast.show('今天休息，好好恢复');
                  },
                ),
            ],
            warn: true,
          )
        else if (m.ready == 'tired' && m.train)
          TodayTipCard(
            model: m,
            key: const ValueKey('fatigue'),
            heading: '今天有点累',
            priority: 1,
            body: '每个动作可以少做 1 组、重量降一点，或选精简版。按今天的状态练就好。',
            actions: const [],
          ),
        if (review != null)
          TodayTipCard(
            model: m,
            key: const ValueKey('weekly-review'),
            heading: '上周回顾',
            body: '',
            actions: const [],
            priority: 2,
            content: WeeklyReviewCard(review: review, compact: true),
          ),
        if (m.missed != null)
          TodayTipCard(
            model: m,
            key: ValueKey('missed-${m.missed!['iso']}'),
            heading:
                '${weekday('${m.missed!['iso']}')}的「${workoutTitle('${m.missed!['workout']['name']}')}」没练',
            body: '今天本来是休息日，要不要补上？',
            priority: 3,
            actions: [
              TodayButton(
                '今天补练',

                onTap: () => patch({'override': m.missed!['id']}),
              ),
            ],
          ),
        for (final s in m.suggestions)
          TodayTipCard(
            model: m,
            key: ValueKey('suggestion-${s['key']}'),
            heading: '${s['title']}',
            priority: s['kind'] == 'pain'
                ? 0
                : s['kind'] == 'deload'
                ? 3
                : 4,
            body: '${s['body']}',
            actions: [
              if (s['accept'] != null)
                TodayButton(
                  todayTipWording('${s['acceptLabel']}'),
                  onTap: () => accept(s),
                ),
              TodayButton(
                jsTruthy(s['info'])
                    ? '知道了'
                    : s['kind'] == 'deload'
                    ? '先不'
                    : '先保持',
                neutral: true,
                onTap: () async {
                  await app.declineSuggestion(s);
                  app.toast.show(jsTruthy(s['info']) ? '知道了' : '先保持，两周内不再提这一条');
                },
              ),
            ],
            good: s['kind'] == 'load',
            warn: s['kind'] == 'pain',
            extra: s['kind'] == 'load' && s['step'] != null
                ? Row(
                    children: [
                      text('最小一档'),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 68,
                        child: TodayInput(
                          value: fmt(s['step']),
                          numeric: true,
                          label: '最小一档',
                          onChanged: (v) {
                            final n = num.tryParse(v);
                            if (n != null && n > 0 && n <= 50) {
                              app.setStep('${s['ex']}', n);
                            }
                          },
                        ),
                      ),
                      text('kg'),
                    ],
                  )
                : null,
          ),
        if (!_notifyOk && jsTruthy(jsonMap(app.plan['reminder'])['enabled']))
          TodayTipCard(
            model: m,
            key: const ValueKey('notifications'),
            heading: '开启每日训练提醒',
            priority: 5,
            body:
                '每天 ${app.plan['reminder']['time']} 通知你今天练什么、练多少组；没练的话晚点再提醒一次。',
            actions: [
              TodayButton(
                '允许通知',

                onTap: () async {
                  try {
                    await app.reminders.enablePlanReminders();
                    app.refreshRemindersNow();
                    if (mounted) setState(() => _notifyOk = true);
                    app.toast.show('已开启每日提醒');
                  } on Object catch (e) {
                    app.toast.show(
                      AppController.message(e),
                      duration: const Duration(milliseconds: 3500),
                    );
                  }
                },
              ),
            ],
          ),
        if (app.shouldNudgeWeight)
          TodayTipCard(
            model: m,
            key: const ValueKey('weight-nudge'),
            heading: '该称体重了',
            body: '记一次体重，趋势会更准',
            priority: 6,
            actions: const [],
            content: TodayNudgeRow(
              icon: 'weight',
              title: '该称体重了',
              subtitle: '记一次，趋势会更准',
              actionLabel: '记一次',
              onAction: () async {
                openBodyLog(context);
                await app.snoozeWeightNudge(7);
              },
              onDismiss: () => app.snoozeWeightNudge(3),
            ),
          ),
      ];
      // Stable priority: keep the domain's order inside each category.
      final orderedTips = tips.indexed.toList()
        ..sort((a, b) {
          final rank = a.$2.priority.compareTo(b.$2.priority);
          return rank == 0 ? a.$1.compareTo(b.$1) : rank;
        });
      final visibleTips = orderedTips.map((e) => e.$2).toList();
      final blocks = <Widget>[
        FadeSwitcher(
          key: const ValueKey('hero'),
          child: m.train
              ? TodayHero(
                  key: const ValueKey('training'),
                  model: m,
                  onStart: () => start(m),
                  onAdjust: adjust,
                )
              : TodayRestCard(
                  key: const ValueKey('rest'),
                  model: m,
                  onSwap: () => swap(m),
                  onRestore: () => patch({'override': null}),
                ),
        ),
        Column(
          key: const ValueKey('tips'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: visibleTips.isNotEmpty,
              child: FadeSwitcher(
                child:
                    visibleTips.firstOrNull ??
                    const SizedBox.shrink(key: ValueKey('no-tip')),
              ),
            ),
            Reveal(
              visible: _showSuggestions && visibleTips.length > 1,
              child: MotionList(children: visibleTips.skip(1).toList()),
            ),
            Reveal(
              visible: tips.length > 1,
              child: TodayButton(
                _showSuggestions ? '收起提示' : '还有 ${tips.length - 1} 条提示 ›',
                onTap: () =>
                    setState(() => _showSuggestions = !_showSuggestions),
              ),
            ),
          ],
        ),
        Reveal(
          key: const ValueKey('action-slot'),
          visible: m.train,
          child: TodayActions(
            key: const ValueKey('actions'),
            model: m,
            onOpen: (e) {
              if (widget.two || !m.started) {
                guide(e, m.iso);
              } else {
                openTrainingMode(context, exerciseId: '${e['id']}');
              }
            },
            onWarm: () => patch({'warm': !jsTruthy(m.state['warm'])}),
          ),
        ),
        TodayNutritionStrip(key: const ValueKey('nutrition'), model: m),
        TodayWeekCard(key: const ValueKey('week'), model: m),
      ];
      final header = Padding(
        key: const ValueKey('header'),
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const Expanded(child: Wordmark()),
                  Semantics(
                    button: true,
                    label: AppMessages.of(context).text('计划与提醒设置'),
                    child: Pressable(
                      onTap: () => openPlanEditor(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.card,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AppIcon('note', size: 22, color: p.tint),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LText(
                  '${dateLabel(m.iso)} · 第 ${plan.weekNumber(app.plan, m.iso)} 周',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: p.secondary,
                  ),
                ),
                // 只要这一练有健身房版本就给切换，不看引导页选了什么。
                if (m.train && m.workout['hasGym'] == true) ...[
                  const SizedBox(width: 8),
                  VenueChip(
                    gym: m.workout['venue'] == 'gym',
                    onTap: () => chooseVenue(m),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
      final top = MediaQuery.paddingOf(context).top + 8;
      if (widget.two && focus != null) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 16),
          child: Column(
            children: [
              header,
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final sideWidth = (box.maxWidth * .4).clamp(280.0, 380.0);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: blocks.length,
                            itemBuilder: (_, i) => blocks[i],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: sideWidth,
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: GuideBody(
                                exercise: focus,
                                iso: m.train ? m.iso : '${m.next!['iso']}',
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(16, top, 16, 120),
        itemCount: blocks.length + 1,
        itemBuilder: (_, i) => i == 0 ? header : blocks[i - 1],
      );
    },
  );
}

class _RecoveryPanel extends StatefulWidget {
  const _RecoveryPanel({required this.content});
  final Widget content;
  @override
  State<_RecoveryPanel> createState() => _RecoveryPanelState();
}

class _RecoveryPanelState extends State<_RecoveryPanel> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      GroupRow(
        label: expanded ? '收起恢复情况' : '肌肉恢复情况',
        onTap: () => setState(() => expanded = !expanded),
      ),
      Reveal(visible: expanded, child: widget.content),
    ],
  );
}
