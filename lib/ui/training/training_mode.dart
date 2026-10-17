import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';
import '../../core/haptics.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart' show openGuide, openEditSet;
import '../../domain/format.dart';
import '../../domain/movements.dart' show musclesOf;
import '../../domain/progress.dart' as progress;
import '../../theme/theme.dart';
import '../kit/exercise_thumb.dart';
import '../kit/exercise_demo.dart';
import '../sheets/edit_set_sheet.dart' show SetFeedbackChip;
import '../log/set_display.dart';
import '../kit/transitions.dart';
import '../kit/app_icon.dart';
import '../kit/grouped.dart';
import '../kit/glass.dart';
import '../kit/menu.dart';
import '../kit/pressable.dart';
import '../today/today_model.dart';
import '../today/workout_title.dart';
import 'training_logic.dart';

Future<void> openTrainingMode(
  BuildContext context, {
  String? exerciseId,
  bool haptic = false,
}) async {
  final app = context.app;
  final model = TodayModel(app);
  if (!model.started) await app.patchDayState(model.iso, {'started': true});
  if (!context.mounted) return;
  await app.native.keepAwake(true);
  try {
    if (!context.mounted) return;
    if (haptic) app.haptics.saved();
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => TrainingMode(exerciseId: exerciseId),
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
        ),
        transitionsBuilder: (context, a, _, child) =>
            MediaQuery.disableAnimationsOf(context)
            ? child
            : SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: a,
                        curve: const _TrainingSpring(),
                        reverseCurve: Curves.easeIn,
                      ),
                    ),
                child: child,
              ),
      ),
    );
  } finally {
    await app.native.keepAwake(false);
  }
}

class _TrainingSpring extends Curve {
  const _TrainingSpring();
  static final _spring = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 240, damping: 25),
    0,
    1,
    0,
  );
  @override
  double transformInternal(double t) => _spring.x(t * .48) / _spring.x(.48);
}

class TrainingMode extends StatefulWidget {
  const TrainingMode({super.key, this.exerciseId});
  final String? exerciseId;
  @override
  State<TrainingMode> createState() => _TrainingModeState();
}

class _TrainingModeState extends State<TrainingMode>
    with TickerProviderStateMixin {
  AppController? _app;
  late final PageController _pages;
  final _dragOrigin = ValueNotifier<double>(0);
  int _page = 0;
  bool _manualPage = false;
  bool get hasWarm => jsonMap(model.workout['warmup']).isNotEmpty;
  int get warmOffset => hasWarm ? 1 : 0;

  void goPage(int page) {
    _manualPage = false;
    FocusScope.of(context).unfocus();
    _advance?.cancel();
    _dragOrigin.value = page * _pages.position.viewportDimension;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 480),
        curve: const _TrainingSpring(),
      );
    }
  }

  void pageChanged(int page) {
    if (_manualPage && page != _page) _app!.haptics.selection();
    _advance?.cancel();
    setState(() {
      clearFeedback();
      _page = page;
      _warm = hasWarm && page == 0;
      _summary = page == model.items.length + warmOffset;
      if (!_warm && !_summary) {
        _id = '${model.items[page - warmOffset]['ex']['id']}';
        _skipped.remove(_id);
      }
      _reps = null;
      _weight = null;
    });
  }

  String? _id, _feedbackId;
  final _skipped = <String>{};
  final _numbersKeys = <String, GlobalKey>{};
  bool _warm = false, _summary = false, _saving = false;
  bool _feedbackExpanded = false, _inputFocused = false;
  String? _pbLabel;
  num? _reps, _weight;
  int? _remaining;
  String? _flag;
  Timer? _feedbackTimer, _advance;
  final _elapsed = Stopwatch()..start();
  late final _pulse = AnimationController.unbounded(vsync: this, value: 1);
  late final _feedbackMotion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 320),
  );
  Future<void> hideFeedback() async {
    final id = _feedbackId;
    if (MediaQuery.disableAnimationsOf(context)) {
      _feedbackMotion.value = 0;
    } else {
      await _feedbackMotion.reverse();
    }
    if (mounted && _feedbackId == id) setState(() => _feedbackExpanded = false);
  }

  TodayModel get model => TodayModel(_app!);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app != null) return;
    _app = context.app;
    final m = model;
    _id = widget.exerciseId ?? m.firstOpen;
    if (!m.items.any((i) => i['ex']['id'] == _id) && m.items.isNotEmpty) {
      _id = '${m.items.first['ex']['id']}';
    }
    _warm =
        !jsTruthy(m.state['warm']) && jsonMap(m.workout['warmup']).isNotEmpty;
    _summary = m.items.isEmpty || m.complete && widget.exerciseId == null;
    _page = _summary
        ? m.items.length + warmOffset
        : _warm
        ? 0
        : warmOffset + m.items.indexWhere((i) => i['ex']['id'] == _id);
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _advance?.cancel();
    _pages.dispose();
    _dragOrigin.dispose();
    _pulse.dispose();
    _feedbackMotion.dispose();
    _elapsed.stop();
    super.dispose();
  }

  void clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackId = null;
    _feedbackExpanded = false;
    _feedbackMotion.value = 0;
  }

  void expandFeedback() {
    setState(() => _feedbackExpanded = true);
    _feedbackMotion.forward();
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 6), hideFeedback);
  }

  void select(String id) {
    final index = model.items.indexWhere((i) => i['ex']['id'] == id);
    if (index < 0) return;
    if (_page == index + warmOffset) {
      pageChanged(_page);
    } else {
      goPage(index + warmOffset);
    }
  }

  void next() {
    final m = model;
    final pending = m.items
        .where(
          (i) =>
              !jsTruthy(i['complete']) &&
              !_skipped.contains('${i['ex']['id']}'),
        )
        .toList();
    if (pending.isEmpty) {
      goPage(m.items.length + warmOffset);
    } else {
      final index = m.items.indexWhere((i) => i['ex']['id'] == _id);
      final later = pending
          .where((i) => m.items.indexOf(i) > index)
          .firstOrNull;
      select('${(later ?? pending.first)['ex']['id']}');
    }
  }

  Future<void> finishWarmup(TodayModel m) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!jsTruthy(model.state['warm'])) {
        await _app!.patchDayState(m.iso, {'warm': true});
        if (!mounted) return;
        _app!.haptics.saved();
      }
      if (!mounted) return;
      final items = model.items;
      goPage(
        warmOffset +
            items
                .indexWhere((i) => i['ex']['id'] == _id)
                .clamp(0, math.max(0, items.length - 1)),
      );
    } on Object catch (error) {
      if (mounted) _app!.toast.show(AppController.message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> save(
    Map<String, dynamic> e,
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> target,
  ) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final app = _app!;
    final m = model;
    final r = _reps ?? trainingReps(e, target, sets);
    final w = trainingHasLoad(e, sets)
        ? _weight ?? trainingWeight(e, target, sets)
        : 0;
    try {
      final pb = progress.isPersonalBest(
        m.history,
        '${e['name']}',
        r.round(),
        w,
      );
      final id = await saveTrainingSet(app, m, e, r, w);
      if (!mounted) return;
      setState(() {
        _feedbackId = id;
        _feedbackExpanded = true;
        _remaining = null;
        _flag = null;
        if (pb) {
          _pbLabel =
              '${e['name']} · ${w > 0 ? '${fmt(w)} kg × ' : '自重 '}${fmt(r)} ${e['unit'] == 'sec' ? '秒' : '次'}';
        }
      });
      _feedbackMotion.forward(
        from: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      );
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) hideFeedback();
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        _pulse.value = .96;
        _pulse.animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 260, damping: 19),
            .96,
            1,
            0,
          ),
        );
      }
      if (sets.length + 1 >= jsNumber(e['target'])) {
        _advance?.cancel();
        _advance = Timer(const Duration(milliseconds: 600), () {
          if (mounted) next();
        });
      }
    } on Object catch (error) {
      app.toast.show(AppController.message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> feedback({int? remaining, String? flag}) async {
    final id = _feedbackId;
    if (id == null) return;
    try {
      if (remaining == _remaining && flag == null) return;
      await trainingFeedback(_app!, id, remaining: remaining, flag: flag);
      if (flag != null || remaining != _remaining) _app!.haptics.selection();
      if (!mounted) return;
      setState(() {
        if (remaining != null) _remaining = remaining;
        if (flag != null) _flag = flag;
      });
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) hideFeedback();
      });
    } on Object catch (error) {
      _app!.toast.show(AppController.message(error));
    }
  }

  Future<void> list() async {
    final m = model;
    final pick = await showActionMenu(
      context,
      actions: [
        for (final i in m.items)
          MenuAction(
            id: '${i['ex']['id']}',
            label:
                '${i['ex']['name']} · ${_skipped.contains('${i['ex']['id']}')
                    ? '已跳过'
                    : i['complete'] == true
                    ? '✓'
                    : '${jsonRows(i['sets']).length}/${i['ex']['target']} 组'}',
            icon: 'train',
          ),
      ],
    );
    if (pick != null && mounted) select(pick.id);
  }

  Future<void> more(
    Map<String, dynamic> e,
    List<Map<String, dynamic>> sets,
  ) async {
    final m = model;
    final pick = await showActionMenu(
      context,
      actions: [
        if (jsonRows(e['alts']).isNotEmpty || jsTruthy(e['swapped']))
          const MenuAction(id: 'swap', label: '换动作', icon: 'repeat'),
        const MenuAction(id: 'skip', label: '跳过这个动作', icon: 'right'),
        const MenuAction(id: 'lite', label: '改成精简', icon: 'train'),
      ],
    );
    if (!mounted || pick == null) return;
    if (pick.id == 'skip') {
      _skipped.add('${e['id']}');
      next();
      return;
    }
    if (pick.id == 'lite') {
      await _app!.patchDayState(m.iso, {'lite': true});
      if (mounted) next();
      return;
    }
    final alt = await showActionMenu(
      context,
      actions: [
        if (jsTruthy(e['swapped']))
          MenuAction(
            id: '__orig',
            label: '恢复原动作：${e['origName']}',
            icon: 'undo',
          ),
        for (final a in jsonRows(
          e['alts'],
        ).where((a) => a['name'] != e['name']))
          MenuAction(id: '${a['name']}', label: '${a['name']}', icon: 'repeat'),
      ],
    );
    if (alt == null || !mounted) return;
    if (sets.isNotEmpty &&
        !await showConfirm(
          context,
          title: '换动作？',
          message: '已记的 ${sets.length} 组会保留在「${e['name']}」下，新动作的进度从 0 开始。',
          confirm: '换',
        )) {
      return;
    }
    final swaps = jsonMap(m.state['swaps']);
    if (alt.id == '__orig') {
      swaps.remove(e['id']);
    } else {
      swaps['${e['id']}'] = alt.id;
    }
    await _app!.patchDayState(m.iso, {'swaps': swaps});
    if (mounted) select('${e['id']}');
  }

  Widget text(
    String s, {
    double size = 15,
    bool bold = false,
    bool secondary = false,
  }) => LText(
    s,
    style: TextStyle(
      fontSize: size,
      height: 1.3,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: secondary ? context.pal.secondary : context.pal.text,
    ),
  );
  Widget button(
    String label,
    VoidCallback? tap, {
    bool primary = false,
    bool selected = false,
    bool secondary = false,
  }) => Semantics(
    button: true,
    label: AppMessages.of(context).text(label),
    selected: selected,
    child: Pressable(
      scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
      onTap: tap,
      child: Container(
        constraints: BoxConstraints(minHeight: primary ? 58 : 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? context.pal.tint
              : selected
              ? context.pal.tintSoft
              : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: LText(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: primary ? 17 : 13,
            fontWeight: FontWeight.w600,
            color: primary
                ? context.pal.onTint
                : secondary
                ? context.pal.secondary
                : context.pal.tint,
          ),
        ),
      ),
    ),
  );
  Widget feedbackChip(String label, VoidCallback tap, bool selected) =>
      Expanded(
        child: SetFeedbackChip(
          label: label,
          onTap: tap,
          selected: selected,
          haptic: false,
        ),
      );

  Widget feedbackBar() {
    final row = jsonRows(model.day['sets'])
        .where((s) => s['id'] == _feedbackId)
        .firstOrNull;
    final detail = row == null ? '' : setFeedbackLabel(row);
    return button(
      '第 ${row?['no'] ?? 1} 组 · ${detail.isEmpty ? '补充感受 ›' : '$detail ✎'}',
      () {
        _remaining = row?['rpe'] == null
            ? null
            : (10 - jsNumber(row?['rpe'])).round();
        _flag = row?['flag'] as String?;
        expandFeedback();
      },
      secondary: true,
    );
  }

  Widget feedbackView() => SizeTransition(
    sizeFactor: _feedbackMotion,
    alignment: Alignment.bottomCenter,
    child: FadeTransition(
      opacity: _feedbackMotion,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          key: const ValueKey('training-feedback'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                text('刚才这组还能做几次', size: 12, secondary: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      for (final n in [0, 1, 2, 3]) ...[
                        if (n > 0) const SizedBox(width: 4),
                        feedbackChip(
                          n == 3 ? '3+' : '$n',
                          () => feedback(remaining: n),
                          _remaining == n,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                text('有不舒服吗', size: 12, secondary: true),
                const SizedBox(width: 8),
                feedbackChip(
                  '动作变形',
                  () => feedback(flag: _flag == 'form' ? '' : 'form'),
                  _flag == 'form',
                ),
                const SizedBox(width: 8),
                feedbackChip(
                  '有点痛',
                  () => feedback(flag: _flag == 'pain' ? '' : 'pain'),
                  _flag == 'pain',
                ),
              ],
            ),
            if (_flag == 'pain')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LText(
                  '疼痛请停止，先休息并确认身体情况。',
                  style: TextStyle(color: context.pal.err, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget headerButton(String label, String icon, VoidCallback tap) => Semantics(
    button: true,
    label: AppMessages.of(context).text(label),
    child: Pressable(
      scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
      onTap: tap,
      child: GlassSurface(
        radius: 22,
        shadow: false,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AppIcon(icon, size: 20, color: context.pal.text),
          ),
        ),
      ),
    ),
  );
  Widget warmView(TodayModel m) {
    final warm = jsonMap(m.workout['warmup']);
    final items = warm['items'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 35),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: text('热身 ${warm['minutes']} 分钟', size: 34, bold: true),
        ),
        const SizedBox(height: 24),
        GroupCard(
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.pal.fill2,
                        shape: BoxShape.circle,
                      ),
                      child: text('${i + 1}', size: 13, secondary: true),
                    ),
                  ),
                  Expanded(
                    child: GroupRow(label: '${items[i]}', chevron: false),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: text('${warm['note'] ?? ''}', size: 13, secondary: true),
        ),
      ],
    );
  }

  Widget summaryView(TodayModel m) {
    final names = m.all.map((e) => e['name']).toSet();
    final rows = jsonRows(m.day['sets'])
        .where((s) => names.contains(s['ex']) && s['type'] != '热身')
        .toList();
    num bodyReps = 0, bodySeconds = 0;
    for (final row in rows) {
      final ex = m.all.where((e) => e['name'] == row['ex']).firstOrNull;
      if (ex != null && !trainingHasLoad(ex, [row])) {
        if (ex['unit'] == 'sec') {
          bodySeconds += jsNumber(row['reps']);
        } else {
          bodyReps += jsNumber(row['reps']);
        }
      }
    }
    final volume = rows.fold<num>(
      0,
      (sum, s) =>
          sum +
          (musclesOf(s['ex'], '${s['part']}')?['kind'] == 'bw'
              ? 0
              : jsNumber(s['w']) * jsNumber(s['reps'])),
    );
    final allBody =
        rows.isNotEmpty &&
        rows.every((row) {
          final ex = m.all.where((e) => e['name'] == row['ex']).firstOrNull;
          return ex != null && !trainingHasLoad(ex, [row]);
        });
    Widget tile(String value, String unit, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        decoration: BoxDecoration(
          color: context.pal.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: text(value, size: 34, bold: true),
            ),
            text(unit, size: 12, secondary: true),
            const SizedBox(height: 6),
            text(label, size: 13, secondary: true),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(
              begin: MediaQuery.disableAnimationsOf(context) ? 1 : .7,
              end: 1,
            ),
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
            ),
            curve: Curves.elasticOut,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: SizedBox(
              height: 116,
              child: Center(
                child: AppIcon('check', size: 88, color: context.pal.ok),
              ),
            ),
          ),
        ),
        Center(child: text('练完了', size: 34, bold: true)),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile('${rows.length}', '组', '组数'),
              const SizedBox(width: 8),
              tile(
                allBody
                    ? fmt(bodyReps > 0 ? bodyReps : bodySeconds)
                    : fmt(volume),
                allBody ? (bodyReps > 0 ? '次' : '秒') : 'kg',
                allBody ? '自重' : '训练量',
              ),
              const SizedBox(width: 8),
              tile('${math.max(1, _elapsed.elapsed.inMinutes)}', '分钟', '用时'),
            ],
          ),
        ),
        if (allBody && bodyReps > 0 && bodySeconds > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: text(
              '另有自重 ${fmt(bodySeconds)} 秒',
              size: 13,
              secondary: true,
            ),
          ),
        const SizedBox(height: 20),
        if (_pbLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.pal.fill2,
                borderRadius: BorderRadius.circular(22),
              ),
              child: text('新纪录 · $_pbLabel', size: 13),
            ),
          ),
        if (m.next != null)
          GroupCard(
            children: [
              GroupRow(
                label: '下次',
                value:
                    '${weekday('${m.next!['iso']}')} · ${workoutTitle('${m.next!['workout']['name']}')}',
                chevron: false,
              ),
            ],
          ),
      ],
    );
  }

  Widget exerciseView(
    TodayModel m,
    Map<String, dynamic> e,
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> target,
    double availableHeight,
  ) {
    final p = context.pal;
    final r = _reps ?? trainingReps(e, target, sets),
        w = _weight ?? trainingWeight(e, target, sets);
    final loaded = trainingHasLoad(e, sets);
    final reason = sets.length >= jsNumber(e['target'])
        ? (m.after['${e['id']}']?['reason'])
        : target['reason'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(
            end: _feedbackExpanded
                ? 120
                : (availableHeight * .30).clamp(120, 200).toDouble(),
          ),
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
          ),
          curve: const _TrainingSpring(),
          builder: (_, height, _) => Center(
            child: ExerciseDemo(ex: e, size: height),
          ),
        ),
        button(
          '动作要点 ›',
          () => openGuide(context, '${e['name']}', iso: m.iso),
          secondary: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: text('${e['name']}', size: 34, bold: true),
        ),
        text(
          '目标 ${e['target']} 组 × ${target['reps'] ?? e['min']} ${e['unit'] == 'sec' ? '秒' : '次'}${loaded ? ' · ${fmt(w)} kg' : ' · 自重'}',
          secondary: true,
        ),
        if (jsTruthy(reason)) ...[
          const SizedBox(height: 4),
          text('$reason', size: 13, secondary: true),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (
              var i = 0;
              i < math.max(jsNumber(e['target']).toInt(), sets.length);
              i++
            )
              Semantics(
                button: i < sets.length,
                label: AppMessages.of(context).text(
                  '第 ${i + 1} 组${i < sets.length ? ' 完成${setFeedbackLabel(sets[i]).isNotEmpty ? '，有感受记录' : '，编辑'}' : ''}',
                ),
                child: Pressable(
                  scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
                  onTap: i < sets.length
                      ? () => openEditSet(context, sets[i])
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 220,
                        ),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < sets.length ? p.ok : null,
                          border: Border.all(
                            color: i == sets.length ? p.tint : p.sep,
                            width: 2,
                          ),
                        ),
                        child: i < sets.length
                            ? AppIcon('check', size: 20, color: p.onTint)
                            : LText(
                                '${i + 1}',
                                style: TextStyle(
                                  color: p.secondary,
                                  fontSize: 17,
                                ),
                              ),
                      ),
                      if (i < sets.length &&
                          setFeedbackLabel(sets[i]).isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            key: ValueKey('feedback-dot-${sets[i]['id']}'),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sets[i]['flag'] == 'pain'
                                  ? p.err
                                  : p.tertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: MediaQuery.disableAnimationsOf(context) ? 1 : _pulse.value,
            child: child,
          ),
          child: Padding(
            key: _numbersKeys.putIfAbsent('${e['id']}', () => GlobalKey()),
            // Leave a margin for the thumbnail spring's final subpixel motion.
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                TrainingNumber(
                  key: ValueKey('$_id-${e['name']}-reps'),
                  label: e['unit'] == 'sec' ? '秒' : '次数',
                  value: r,
                  step: e['unit'] == 'sec' ? 5 : 1,
                  minimum: 1,
                  onChanged: (v) => _reps = v,
                ),
                if (loaded) ...[
                  const SizedBox(height: 10),
                  TrainingNumber(
                    key: ValueKey('$_id-${e['name']}-weight'),
                    label: '重量',
                    value: w,
                    step: jsTruthy(e['machine'])
                        ? jsNumber(
                            jsonMap(_app!.progress['steps'])[e['name']] ?? 2.5,
                          )
                        : .5,
                    minimum: 0,
                    onChanged: (v) => _weight = v,
                  ),
                ],
              ],
            ),
          ),
        ),
        TrainingRest(app: _app!),
        button('更多 ›', () => more(e, sets), secondary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _app!,
    builder: (context, _) {
      final m = model;
      final item = m.items.where((i) => i['ex']['id'] == _id).firstOrNull;
      final e = jsonMap(item?['ex']), sets = jsonRows(item?['sets']);
      final target = m.before['${e['id']}'] ?? <String, dynamic>{};
      final index = m.items.indexWhere((i) => i['ex']['id'] == _id);
      return ColoredBox(
        color: context.pal.bg,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    GestureDetector(
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) > 350) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            headerButton(
                              '关闭',
                              'close',
                              () => Navigator.of(context).pop(),
                            ),
                            if (!_summary)
                              Expanded(
                                child: LText(
                                  '${workoutTitle('${m.workout['name'] ?? '训练'}')} · ${_warm
                                      ? '热身'
                                      : _summary
                                      ? '小结'
                                      : '第 ${index + 1}/${m.items.length} 项'}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.pal.secondary,
                                  ),
                                ),
                              ),
                            if (!_summary) headerButton('列表', 'layers', list),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0 &&
                              notification is ScrollEndNotification) {
                            _manualPage = false;
                          }
                          if (notification.depth == 0 &&
                              notification is ScrollStartNotification &&
                              notification.dragDetails != null) {
                            _manualPage = true;
                            _dragOrigin.value = notification.metrics.pixels;
                          }
                          return false;
                        },
                        child: Focus(
                          onFocusChange: (focused) {
                            if (mounted) {
                              setState(() => _inputFocused = focused);
                            }
                          },
                          child: PageView.builder(
                            controller: _pages,
                            pageSnapping: false,
                            physics:
                                _inputFocused ||
                                    MediaQuery.viewInsetsOf(context).bottom > 0
                                ? const NeverScrollableScrollPhysics()
                                : _TrainingPagePhysics(
                                    reduce: MediaQuery.disableAnimationsOf(
                                      context,
                                    ),
                                    origin: _dragOrigin,
                                    parent: const BouncingScrollPhysics(),
                                  ),
                            onPageChanged: pageChanged,
                            itemCount: m.items.length + warmOffset + 1,
                            itemBuilder: (context, page) {
                              if (page != _page) {
                                final itemIndex = page - warmOffset;
                                final ex =
                                    itemIndex >= 0 && itemIndex < m.items.length
                                    ? jsonMap(m.items[itemIndex]['ex'])
                                    : null;
                                return IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 28),
                                        if (ex != null)
                                          ExerciseThumb(ex: ex, size: 160),
                                        const SizedBox(height: 16),
                                        text(
                                          ex == null
                                              ? (page == 0 && hasWarm
                                                    ? '热身'
                                                    : '训练小结')
                                              : '${ex['name']}',
                                          size: 34,
                                          bold: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (_feedbackExpanded &&
                                            !_warm &&
                                            !_summary) {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                final numbers =
                                                    _numbersKeys[_id]
                                                        ?.currentContext;
                                                if (mounted &&
                                                    numbers != null) {
                                                  Scrollable.of(
                                                    numbers,
                                                  ).position.ensureVisible(
                                                    numbers.findRenderObject()!,
                                                    alignment: 1,
                                                    alignmentPolicy:
                                                        ScrollPositionAlignmentPolicy
                                                            .keepVisibleAtEnd,
                                                  );
                                                }
                                              });
                                        }
                                        return SingleChildScrollView(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                            bottom: 12,
                                          ),
                                          child: _warm
                                              ? warmView(m)
                                              : _summary
                                              ? summaryView(m)
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  child: exerciseView(
                                                    m,
                                                    e,
                                                    sets,
                                                    target,
                                                    constraints.maxHeight,
                                                  ),
                                                ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_feedbackId != null &&
                                            !_summary &&
                                            !_warm)
                                          Column(
                                            children: [
                                              Reveal(
                                                visible: _feedbackExpanded,
                                                child: _feedbackExpanded
                                                    ? feedbackView()
                                                    : const SizedBox.shrink(),
                                              ),
                                              if (!_feedbackExpanded)
                                                feedbackBar(),
                                            ],
                                          ),
                                        if (_warm)
                                          button(
                                            '跳过热身',
                                            () => goPage(
                                              warmOffset +
                                                  model.items
                                                      .indexWhere(
                                                        (i) =>
                                                            i['ex']['id'] ==
                                                            _id,
                                                      )
                                                      .clamp(
                                                        0,
                                                        math.max(
                                                          0,
                                                          model.items.length -
                                                              1,
                                                        ),
                                                      ),
                                            ),
                                            secondary: true,
                                          ),
                                        button(
                                          _warm
                                              ? '热身完成'
                                              : _summary
                                              ? '完成'
                                              : '完成第 ${sets.length + 1} 组',
                                          _saving
                                              ? null
                                              : () async {
                                                  if (_warm) {
                                                    await finishWarmup(m);
                                                  } else if (_summary) {
                                                    Navigator.of(context).pop();
                                                  } else {
                                                    await save(e, sets, target);
                                                  }
                                                },
                                          primary: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class TrainingNumber extends StatefulWidget {
  const TrainingNumber({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.minimum,
    required this.onChanged,
  });
  final String label;
  final num value, step, minimum;
  final ValueChanged<num> onChanged;
  @override
  State<TrainingNumber> createState() => _TrainingNumberState();
}

class _TrainingNumberState extends State<TrainingNumber> {
  late final _text = TextEditingController(text: fmt(widget.value));
  final _focus = FocusNode();
  Timer? _repeat;
  @override
  void didUpdateWidget(TrainingNumber old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _text.text = fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void step(num d) {
    final n = math.max(
      widget.minimum,
      ((jsNumber(_text.text) + d) * 10).round() / 10,
    );
    if (n == jsNumber(_text.text)) return;
    HapticScope.of(context)?.tick();
    _text.text = fmt(n);
    widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget bump(bool minus) {
      final d = minus ? -widget.step : widget.step;
      return Listener(
        onPointerUp: (_) {
          _repeat?.cancel();
        },
        onPointerCancel: (_) {
          _repeat?.cancel();
        },
        child: Semantics(
          button: true,
          label: AppMessages.of(context)
              .text('${minus ? '减少' : '增加'}${widget.label}'),
          child: Pressable(
            scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
            onTap: () => step(d),
            onLongPress: () {
              step(d);
              _repeat?.cancel();
              _repeat = Timer.periodic(
                const Duration(milliseconds: 120),
                (_) => step(d),
              );
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: p.fill2, shape: BoxShape.circle),
              child: Center(
                child: LText(
                  minus ? '−' : '+',
                  style: TextStyle(color: p.text, fontSize: 28),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          bump(true),
          Expanded(
            child: Column(
              children: [
                Semantics(
                  label: AppMessages.of(context).text(widget.label),
                  textField: true,
                  child: EditableText(
                    controller: _text,
                    focusNode: _focus,
                    style: DefaultTextStyle.of(context).style.copyWith(
                      color: p.text,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    cursorColor: p.tint,
                    backgroundCursorColor: p.fill,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (s) {
                      final n = num.tryParse(s);
                      if (n != null && n.isFinite) {
                        widget.onChanged(n);
                      } else if (s.isEmpty) {
                        widget.onChanged(0);
                      }
                    },
                  ),
                ),
                LText(
                  widget.label == '重量' ? 'kg' : widget.label,
                  style: TextStyle(color: p.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
          bump(false),
        ],
      ),
    );
  }
}

class TrainingRest extends StatefulWidget {
  const TrainingRest({super.key, required this.app});
  final AppController app;
  @override
  State<TrainingRest> createState() => _TrainingRestState();
}

class _TrainingRestState extends State<TrainingRest> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.app.rest.addListener(changed);

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.app.rest.active) setState(() {});
    });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.app.rest.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rest = widget.app.rest;

    final left = ((rest.untilMs - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 99999);
    Widget action(String label, VoidCallback tap) => Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
        onTap: tap,
        child: SizedBox(
          height: 44,
          width: 76,
          child: Center(
            child: LText(
              label,
              style: TextStyle(color: context.pal.tint, fontSize: 13),
            ),
          ),
        ),
      ),
    );
    return Reveal(
      visible: rest.active,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: LText(
                '休息 ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: context.pal.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            action('+15 秒', () {
              widget.app.haptics.selection();
              rest.add(15);
            }),
            action('跳过', () {
              widget.app.haptics.selection();
              rest.clear();
            }),
          ],
        ),
      ),
    );
  }
}

/// Quarter-page displacement or a deliberate fling; the same spring as entry.
class _TrainingPagePhysics extends ScrollPhysics {
  const _TrainingPagePhysics({
    required this.origin,
    this.reduce = false,
    super.parent,
  });
  final bool reduce;
  final ValueNotifier<double> origin;
  @override
  _TrainingPagePhysics applyTo(ScrollPhysics? ancestor) => _TrainingPagePhysics(
    origin: origin,
    reduce: reduce,
    parent: buildParent(ancestor),
  );
  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 240, damping: 25);
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final width = position.viewportDimension;
    final initial = (origin.value / width).round();
    final delta = position.pixels - origin.value;
    final current = position.pixels / width;
    if ((position.pixels - origin.value).abs() < 1) {
      return null;
    }
    final targetPage = velocity.abs() > 300
        ? (velocity > 0 ? (current + .001).ceil() : (current - .001).floor())
        : initial + (delta.abs() > width / 4 ? (delta > 0 ? 1 : -1) : 0);
    final target = (targetPage * width)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final tolerance = toleranceFor(position);
    if ((position.pixels - target).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (reduce) return _PageSnapSimulation(target);
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _PageSnapSimulation extends Simulation {
  _PageSnapSimulation(this.target);
  final double target;
  @override
  double x(double time) => target;
  @override
  double dx(double time) => 0;
  @override
  bool isDone(double time) => time > 0;
}
