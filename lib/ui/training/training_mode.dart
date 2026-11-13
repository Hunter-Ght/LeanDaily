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
import '../../domain/movements.dart' show muscleRoles, musclesOf;
import '../../domain/progress.dart' as progress;
import '../../theme/theme.dart';
import '../../theme/tokens.dart' show AppPalette;
import '../kit/exercise_thumb.dart';
import '../kit/exercise_demo.dart';
import '../sheets/edit_set_sheet.dart' show SetFeedbackChip;
import '../log/set_display.dart';
import '../kit/transitions.dart';
import '../kit/app_icon.dart';
import '../kit/body_figure.dart';
import '../kit/menu.dart';
import '../kit/pressable.dart';
import '../kit/units_scope.dart';
import '../share/share_data.dart';
import '../share/share_sheet.dart';
import '../today/today_model.dart';
import '../today/workout_title.dart';
import 'training_logic.dart';
import 'training_rest.dart';
import 'training_warmup.dart';

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

/// 训练中固定深色，不随系统亮暗切换。
class TrainingMode extends StatelessWidget {
  const TrainingMode({super.key, this.exerciseId});
  final String? exerciseId;
  @override
  Widget build(BuildContext context) => PaletteScope(
    palette: AppPalette.dark,
    child: _TrainingBody(exerciseId: exerciseId),
  );
}

class _TrainingBody extends StatefulWidget {
  const _TrainingBody({required this.exerciseId});
  final String? exerciseId;
  @override
  State<_TrainingBody> createState() => _TrainingModeState();
}

class _TrainingModeState extends State<_TrainingBody>
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
      if (!_warm) stopFollow(rebuild: false);
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

  /// 休息页上方的「新纪录」一行；同一动作一次训练只震一次（[_celebrated]）。
  String? _celebration;
  final _celebrated = <String>{};

  /// 做满计划组数后用户点了「再来一组」的动作：分段条多出一格，仍不改计划组数。
  final _extra = <String>{};

  /// 热身「跟着做」，null 表示在看列表。
  WarmupFollow? _follow;
  void startFollow(TodayModel m) {
    _follow?.dispose();
    final items = (jsonMap(m.workout['warmup'])['items'] as List? ?? []);
    if (items.isEmpty) return;
    setState(() {
      _follow = WarmupFollow(
        count: items.length,
        onStep: () => _app!.haptics.selection(),
        onDone: () {
          stopFollow();
          finishWarmup(model);
        },
      );
    });
  }

  void stopFollow({bool rebuild = true}) {
    final follow = _follow;
    if (follow == null) return;
    _follow = null;
    // 计时器回调里调用也安全：下一帧再释放。
    WidgetsBinding.instance.addPostFrameCallback((_) => follow.dispose());
    if (rebuild && mounted) setState(() {});
  }

  /// 这次练习里破的纪录（同一动作只留最新一条），分享卡上最多列 2 条。
  final _records = <ShareRecord>[];
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
    _follow?.dispose();
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

  /// 「跳过热身」：不记热身完成，直接去当前动作。
  void finishWarmupSkip() => goPage(
    warmOffset +
        model.items
            .indexWhere((i) => i['ex']['id'] == _id)
            .clamp(0, math.max(0, model.items.length - 1)),
  );

  /// 「再来一组」：做满计划组数后还想多做。不写记录，只是结束休息、回到记录状态，
  /// 数字沿用上一组；点「完成第 N 组」才记，计划组数不变。
  void extraSet(Map<String, dynamic> e) {
    _advance?.cancel();
    _app!.haptics.selection();
    _app!.rest.clear();
    setState(() {
      _extra.add('${e['id']}');
      _reps = null;
      _weight = null;
    });
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
        ? _weight ?? trainingWeight(e, target, sets, context.units)
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
        _extra.remove('${e['id']}');
        _celebration = null;
        if (pb) {
          _pbLabel =
              '${e['name']} · ${w > 0 ? '${context.units.loadText(w)} × ' : '自重 '}${fmt(r)} ${e['unit'] == 'sec' ? '秒' : '次'}';
          _celebration = _pbLabel;
          final detail = '${fmt(r)} ${e['unit'] == 'sec' ? '秒' : '次'}';
          _records
            ..removeWhere((x) => x.name == '${e['name']}')
            ..add(
              ShareRecord(
                name: '${e['name']}',
                detail: detail,
                load: w > 0 ? '${context.units.loadText(w)} × ${fmt(r)}' : null,
              ),
            );
        }
      });
      // 同一动作一次训练只震一次；减弱动态效果时不震。
      if (pb &&
          _celebrated.add('${e['name']}') &&
          !MediaQuery.disableAnimationsOf(context)) {
        app.haptics.newRecord();
      }
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
      // 计划内最后一组自动翻到下一个动作；计划外多做的组留在原处，方便继续「再来一组」。
      if (sets.length + 1 == jsNumber(e['target'])) {
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
        constraints: BoxConstraints(minHeight: primary ? 64 : 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary
              ? context.pal.tint
              : selected
              ? context.pal.tintSoft
              : null,
          borderRadius: BorderRadius.circular(primary ? 22 : 18),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: context.pal.tint.withValues(alpha: .32),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: LText(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: primary ? 20 : 14,
            fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
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
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: AppIcon(icon, size: 22, color: context.pal.secondary),
        ),
      ),
    ),
  );

  /// 大读数：Numeral 大数字 + 小号单位 + 标签。
  Widget bigStat(
    String value,
    String unit,
    String label, {
    double size = 56,
    Color? color,
  }) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppText.num(p, size, color: color)),
              const SizedBox(width: 4),
              LText(unit, style: TextStyle(fontSize: 15, color: p.secondary)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // 单位已经说清楚（“4 个动作”）时不再重复一行说明，只留同样的高度让同排对齐。
        if (label.isEmpty)
          const SizedBox(height: 17)
        else
          LText(label, style: TextStyle(fontSize: 13, color: p.secondary)),
      ],
    );
  }

  Widget warmView(TodayModel m) {
    final p = context.pal;
    final warm = jsonMap(m.workout['warmup']);
    final items = warm['items'] as List? ?? [];
    final note = '${warm['note'] ?? ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LText('热身', style: AppText.display(p, size: 34)),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: bigStat(
                  '${warm['minutes'] ?? ''}',
                  '分钟',
                  '用时',
                  size: 64,
                  color: p.tint,
                ),
              ),
              Expanded(child: bigStat('${items.length}', '个动作', '', size: 64)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (items.isNotEmpty)
          WarmupSoftButton(label: '跟着做', onTap: () => startFollow(m)),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          WarmupRow(
            index: i,
            name: '${items[i]}',
            onOpen: () => openGuide(context, '${items[i]}', iso: m.iso),
          ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LText(note, style: AppText.hint(p)),
          ),
      ],
    );
  }

  Widget warmFollowView(TodayModel m) {
    final items = [
      for (final i in jsonMap(m.workout['warmup'])['items'] as List? ?? [])
        '$i',
    ];
    return WarmupFollowView(
      follow: _follow!,
      items: items,
      onOpen: (name) => openGuide(context, name, iso: m.iso),
    );
  }

  /// 小结页的「分享」：把今天的训练做成一张卡片，进预览。
  Future<void> shareSummary(TodayModel m) {
    final names = m.all.map((e) => e['name']).toSet();
    final rows = jsonRows(m.day['sets'])
        .where((s) => names.contains(s['ex']) && s['type'] != '热身')
        .toList();
    return openShareSheet(
      context,
      trainShareFrom(
        iso: m.iso,
        workoutName: '${m.workout['name'] ?? '训练'}',
        rows: rows,
        minutes: _elapsed.elapsed.inMinutes,
        records: _records.length > 2
            ? _records.sublist(_records.length - 2)
            : List.of(_records),
      ),
    );
  }

  Widget summaryView(TodayModel m) {
    final p = context.pal, units = context.units;
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
    // 按动作归组（保持首次出现的顺序），并汇总今天练到的肌肉。
    final byExercise = <String, List<Map<String, dynamic>>>{};
    final tones = <String, MuscleTone>{};
    for (final row in rows) {
      byExercise.putIfAbsent('${row['ex']}', () => []).add(row);
    }
    for (final row in rows) {
      final roles = muscleRoles(row['ex'], '${row['part']}');
      for (final id in roles.main) {
        tones[id] = MuscleTone.effort;
      }
    }
    for (final row in rows) {
      for (final id in muscleRoles(row['ex'], '${row['part']}').assist) {
        tones.putIfAbsent(id, () => MuscleTone.assist);
      }
    }
    Widget chip(String s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.fill2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(s, style: AppText.num(p, 15)),
    );
    String setLabel(Map<String, dynamic> s) {
      final ex = m.all.where((e) => e['name'] == s['ex']).firstOrNull;
      final reps = fmt(jsNumber(s['reps']));
      final w = jsNumber(s['w']);
      final unit = ex != null && ex['unit'] == 'sec' ? 's' : '';
      return ex != null && trainingHasLoad(ex, [s]) && w > 0
          ? '${units.load(w)}×$reps$unit'
          : '$reps$unit';
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: LText('练完了', style: AppText.display(p, size: 34)),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: reduce ? 1 : .6, end: 1),
                duration: Duration(milliseconds: reduce ? 0 : 260),
                curve: Curves.elasticOut,
                builder: (_, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: AppIcon('check', size: 40, color: p.recover),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: bigStat(
                      '${rows.length}',
                      '组',
                      '',
                      size: 60,
                      color: p.tint,
                    ),
                  ),
                  Expanded(
                    child: bigStat(
                      allBody
                          ? fmt(bodyReps > 0 ? bodyReps : bodySeconds)
                          : fmt(units.loadValue(volume)),
                      allBody ? (bodyReps > 0 ? '次' : '秒') : units.weightUnit,
                      allBody ? '自重' : '训练量',
                      size: 60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: bigStat(
                      '${math.max(1, _elapsed.elapsed.inMinutes)}',
                      '分钟',
                      '用时',
                      size: 44,
                    ),
                  ),
                  Expanded(
                    child: bigStat('${byExercise.length}', '个动作', '', size: 44),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (allBody && bodyReps > 0 && bodySeconds > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: LText('另有自重 ${fmt(bodySeconds)} 秒', style: AppText.hint(p)),
          ),
        if (tones.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LText('今天练到', style: AppText.title(p)),
          ),
          const SizedBox(height: 8),
          BodyFigure(tones: tones, height: 220),
        ],
        if (_pbLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: p.tintSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: LText(
                      '新纪录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.tint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LText(
                      _pbLabel!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (byExercise.isNotEmpty) ...[
          const SizedBox(height: 24),
          for (final entry in byExercise.entries)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    entry.key,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final s in entry.value) chip(setLabel(s))],
                  ),
                ],
              ),
            ),
        ],
        if (m.next != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                LText('下次', style: AppText.hint(p)),
                const SizedBox(width: 12),
                Expanded(
                  child: LText(
                    '${weekday('${m.next!['iso']}')} · ${workoutTitle('${m.next!['workout']['name']}')}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 分段组进度条：每段一组，完成的为发力橙；已完成的段可点开编辑。
  Widget segments(Map<String, dynamic> e, List<Map<String, dynamic>> sets) {
    final p = context.pal;
    final count = math.max(
      jsNumber(e['target']).toInt(),
      sets.length + (_extra.contains('${e['id']}') ? 1 : 0),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: i < sets.length,
                label: AppMessages.of(context).text(
                  '第 ${i + 1} 组${i < sets.length ? ' 完成${setFeedbackLabel(sets[i]).isNotEmpty ? '，有感受记录' : '，编辑'}' : ''}',
                ),
                child: Pressable(
                  scale: 1,
                  onTap: i < sets.length
                      ? () => openEditSet(context, sets[i])
                      : null,
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 220,
                          ),
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: i < sets.length
                                ? p.tint
                                : i == sets.length
                                ? p.tintSoft
                                : p.fill2,
                          ),
                        ),
                        if (i < sets.length &&
                            setFeedbackLabel(sets[i]).isNotEmpty)
                          Positioned(
                            right: 2,
                            top: 10,
                            child: Container(
                              key: ValueKey('feedback-dot-${sets[i]['id']}'),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sets[i]['flag'] == 'pain'
                                    ? p.err
                                    : p.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget restView(
    TodayModel m,
    Map<String, dynamic> e,
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> target,
  ) {
    final loaded = trainingHasLoad(e, sets);
    final sec = e['unit'] == 'sec';
    final r = _reps ?? trainingReps(e, target, sets),
        w = _weight ?? trainingWeight(e, target, sets, context.units);
    final total = jsNumber(e['target']).toInt();
    final hasNextSet = sets.length < total;
    final index = m.items.indexWhere((i) => i['ex']['id'] == e['id']);
    final later = m.items
        .where(
          (i) =>
              m.items.indexOf(i) > index &&
              !jsTruthy(i['complete']) &&
              !_skipped.contains('${i['ex']['id']}'),
        )
        .firstOrNull;
    final nextEx = later == null ? null : jsonMap(later['ex']);
    return TrainingRestView(
      app: _app!,
      exercise: e,
      record: _celebration,
      onExtraSet: hasNextSet ? null : () => extraSet(e),
      nextSet: hasNextSet ? sets.length + 1 : null,
      nextSetDetail: TextSpan(
        children: [
          TextSpan(
            text: trainingSetDetail(
              loaded: loaded,
              weight: w,
              reps: r,
              seconds: sec,
              units: context.units,
            ),
          ),
          if (sets.length + 1 == total) ...[
            const TextSpan(text: ' · '),
            const TextSpan(text: '最后一组'),
          ],
        ],
      ),
      nextExercise: nextEx,
      nextExerciseDetail: nextEx == null
          ? const TextSpan()
          : TextSpan(
              children: [
                TextSpan(text: '${nextEx['part'] ?? ''}'),
                const TextSpan(text: ' · '),
                TextSpan(text: '${nextEx['target']} 组'),
              ],
            ),
    );
  }

  Widget exerciseView(
    TodayModel m,
    Map<String, dynamic> e,
    List<Map<String, dynamic>> sets,
    Map<String, dynamic> target,
    double availableHeight,
  ) {
    final p = context.pal, units = context.units;
    final r = _reps ?? trainingReps(e, target, sets),
        w = _weight ?? trainingWeight(e, target, sets, context.units);
    final loaded = trainingHasLoad(e, sets);
    final sec = e['unit'] == 'sec';
    final reason = sets.length >= jsNumber(e['target'])
        ? (m.after['${e['id']}']?['reason'])
        : target['reason'];
    final last = sets.lastOrNull;
    final lastRpe = last?['rpe'];
    final numbers = <Widget>[
      if (loaded)
        Expanded(
          child: TrainingNumber(
            key: ValueKey('$_id-${e['name']}-weight'),
            label: '重量',
            value: units.loadValue(w),
            step: 1,
            stepper: (current, up) => units.stepLoad(
              e,
              current,
              up: up,
              explicitKg: jsonMap(_app!.progress['steps'])[e['name']] as num?,
            ),
            unit: units.weightUnit,
            minimum: 0,
            onChanged: (v) => _weight = units.loadToKg(v),
          ),
        ),
      if (loaded) const SizedBox(width: 12),
      Expanded(
        child: TrainingNumber(
          key: ValueKey('$_id-${e['name']}-reps'),
          label: sec ? '秒' : '次数',
          value: r,
          step: sec ? 5 : 1,
          minimum: 1,
          onChanged: (v) => _reps = v,
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        // 示范图是这一页的主角：占满内容宽度，高度吸收读数卡以外的剩余空间（160–360）。
        TweenAnimationBuilder<double>(
          tween: Tween(
            end: (availableHeight - (jsTruthy(reason) ? 330 : 296))
                .clamp(160, 360)
                .toDouble(),
          ),
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
          ),
          curve: const _TrainingSpring(),
          builder: (_, height, _) => ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: height,
              child: ColoredBox(
                color: p.studio,
                child: LayoutBuilder(
                  builder: (_, box) {
                    // 示范图本身是方形：取宽高较大者铺满，多出的上下部分裁掉。
                    final side = math.max(height, box.maxWidth);
                    return OverflowBox(
                      maxWidth: side,
                      maxHeight: side,
                      child: ExerciseDemo(ex: e, size: side),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            button(
              '动作要点 ›',
              () => openGuide(context, '${e['name']}', iso: m.iso),
              secondary: true,
            ),
            if (jsTruthy(e['side']))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.fill2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: LText(
                    '单边',
                    style: TextStyle(color: p.secondary, fontSize: 12),
                  ),
                ),
              ),
            const Spacer(),
            button('更多 ›', () => more(e, sets), secondary: true),
          ],
        ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: MediaQuery.disableAnimationsOf(context) ? 1 : _pulse.value,
            child: child,
          ),
          child: Padding(
            key: _numbersKeys.putIfAbsent('${e['id']}', () => GlobalKey()),
            // Leave a margin for the thumbnail spring's final subpixel motion.
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: numbers,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: last == null
              ? LText(
                  '目标 ${e['target']} 组 × ${target['reps'] ?? e['min']} ${sec ? '秒' : '次'}${loaded ? ' · ${context.units.loadText(w)}' : ' · 自重'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.secondary, fontSize: 14),
                )
              : LText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '上一组 ${trainingSetDetail(loaded: loaded && jsNumber(last['w']) > 0, weight: jsNumber(last['w']), reps: jsNumber(last['reps']), seconds: sec, units: context.units)}',
                      ),
                      if (lastRpe != null) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(text: '吃力程度 ${fmt(jsNumber(lastRpe))}'),
                      ],
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.secondary, fontSize: 14),
                ),
        ),
        if (jsTruthy(reason)) ...[
          const SizedBox(height: 4),
          LText(
            '$reason',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.tertiary, fontSize: 13, height: 1.3),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_app!, _app!.rest, ?_follow]),
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
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_warm)
                                      LText(
                                        '${e['name'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: context.pal.text,
                                        ),
                                      ),
                                    LText(
                                      '${workoutTitle('${m.workout['name'] ?? '训练'}')} · ${_warm
                                          ? '热身'
                                          : _summary
                                          ? '小结'
                                          : '第 ${index + 1}/${m.items.length} 项'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.pal.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_summary) _ElapsedClock(watch: _elapsed),
                            if (!_summary) headerButton('列表', 'layers', list),
                          ],
                        ),
                      ),
                    ),
                    if (!_warm && !_summary && item != null) segments(e, sets),
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
                                        LText(
                                          ex == null
                                              ? (page == 0 && hasWarm
                                                    ? '热身'
                                                    : '训练小结')
                                              : '${ex['name']}',
                                          style: AppText.display(
                                            context.pal,
                                            size: 30,
                                          ),
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
                                        final resting =
                                            !_warm &&
                                            !_summary &&
                                            _app!.rest.active;
                                        return AnimatedSwitcher(
                                          layoutBuilder: (current, previous) =>
                                              Stack(
                                                alignment: Alignment.topCenter,
                                                children: [
                                                  ...previous,
                                                  ?current,
                                                ],
                                              ),
                                          duration: Duration(
                                            milliseconds:
                                                MediaQuery.disableAnimationsOf(
                                                  context,
                                                )
                                                ? 0
                                                : 220,
                                          ),
                                          child: resting
                                              ? KeyedSubtree(
                                                  key: const ValueKey('rest'),
                                                  child: restView(
                                                    m,
                                                    e,
                                                    sets,
                                                    target,
                                                  ),
                                                )
                                              : SingleChildScrollView(
                                                  key: const ValueKey('work'),
                                                  padding: EdgeInsets.only(
                                                    top: 4,
                                                    // 小结较长，留出底部主按钮的高度，最后一行能完整滚出来。
                                                    bottom: _summary ? 96 : 12,
                                                  ),
                                                  child: _warm
                                                      ? (_follow != null
                                                            ? warmFollowView(m)
                                                            : warmView(m))
                                                      : _summary
                                                      ? summaryView(m)
                                                      : ConstrainedBox(
                                                          constraints: BoxConstraints(
                                                            minHeight: math.max(
                                                              0,
                                                              constraints
                                                                      .maxHeight -
                                                                  16,
                                                            ),
                                                          ),
                                                          child: Align(
                                                            alignment:
                                                                const Alignment(
                                                                  0,
                                                                  -.45,
                                                                ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                  ),
                                                              child: exerciseView(
                                                                m,
                                                                e,
                                                                sets,
                                                                target,
                                                                constraints
                                                                    .maxHeight,
                                                              ),
                                                            ),
                                                          ),
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
                                        if (!_warm &&
                                            !_summary &&
                                            _app!.rest.active)
                                          button(
                                            '更多 ›',
                                            () => more(e, sets),
                                            secondary: true,
                                          ),
                                        if (_warm && _follow != null) ...[
                                          button(
                                            _follow!.isLast ? '热身完成' : '下一项',
                                            _saving ? null : _follow!.next,
                                            primary: true,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: button(
                                                  '退出跟做',
                                                  stopFollow,
                                                  secondary: true,
                                                ),
                                              ),
                                              Expanded(
                                                child: button('跳过热身', () {
                                                  stopFollow();
                                                  finishWarmupSkip();
                                                }, secondary: true),
                                              ),
                                            ],
                                          ),
                                        ] else if (_warm ||
                                            _summary ||
                                            !_app!.rest.active)
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
                                                      Navigator.of(context)
                                                          .pop();
                                                    } else {
                                                      await save(
                                                        e,
                                                        sets,
                                                        target,
                                                      );
                                                    }
                                                  },
                                            primary: true,
                                          ),
                                        if (_summary)
                                          button(
                                            '分享',
                                            () => shareSummary(m),
                                            secondary: true,
                                          ),
                                        if (_warm && _follow == null)
                                          button(
                                            '跳过热身',
                                            finishWarmupSkip,
                                            secondary: true,
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

class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.watch});
  final Stopwatch watch;
  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sec = widget.watch.elapsed.inSeconds;
    final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
    final label = h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
    return ExcludeSemantics(
      child: Text(
        label,
        style: AppText.num(
          context.pal,
          15,
          weight: FontWeight.w600,
          color: context.pal.secondary,
        ),
      ),
    );
  }
}

class TrainingNumber extends StatefulWidget {
  const TrainingNumber({
    super.key,
    required this.label,
    required this.value,
    required this.step,
    required this.minimum,
    required this.onChanged,
    this.stepper,
    this.unit,
  });
  final String label;
  final num value, step, minimum;

  /// 自定义加减结果（当前值、方向 → 新值）；没有时按固定的 [step]。
  final num Function(num current, bool up)? stepper;

  /// 读数下方的单位文字；没有时「重量」写 kg、「次数」写次。
  final String? unit;
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
    final current = jsNumber(_text.text);
    final n = math.max(
      widget.minimum,
      widget.stepper?.call(current, d > 0) ?? ((current + d) * 10).round() / 10,
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
              height: 52,
              constraints: const BoxConstraints(minWidth: 44),
              decoration: BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  minus ? '−' : '+',
                  style: TextStyle(
                    color: p.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final big = box.maxWidth >= 170;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Semantics(
                label: AppMessages.of(context).text(widget.label),
                textField: true,
                child: EditableText(
                  controller: _text,
                  focusNode: _focus,
                  style: AppText.num(p, big ? 60 : 46),
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
              const SizedBox(height: 4),
              LText(
                widget.unit ??
                    (widget.label == '重量'
                        ? 'kg'
                        : widget.label == '次数'
                        ? '次'
                        : widget.label),
                style: TextStyle(color: p.secondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: bump(true)),
                  const SizedBox(width: 8),
                  Expanded(child: bump(false)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 紧凑休息条（训练模式本身已改用 TrainingRestView，此组件保留给弹层等场景和既有测试）。
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
