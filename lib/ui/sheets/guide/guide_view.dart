import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../../app/app_controller.dart';
import '../../../domain/equipment.dart' show partOfExercise;
import '../../../domain/format.dart';
import '../../../domain/guide.dart';
import '../../../domain/movements.dart' show musclesOf;
import '../../../domain/plan.dart' as plan;
import '../../../l10n/localized_text.dart';
import '../../../theme/theme.dart';
import '../../../theme/tokens.dart' show AppPalette;
import '../../kit/app_icon.dart';
import '../../kit/guide_demo.dart';
import '../../kit/pressable.dart';
import '../../kit/transitions.dart';
import '../train/exercise_info.dart';
import '../train/muscle_focus.dart';
import '../../kit/units_scope.dart';

/// 动作要点的全部内容：示范、动作名与处方、练哪里、怎么做、常见错误、搜视频。
/// 手机弹层（SheetGuideBody）与宽屏常驻栏（GuideBody）共用，版式一致。
class GuideView extends StatelessWidget {
  const GuideView({super.key, required this.exercise, required this.iso});
  final Map<String, dynamic> exercise;
  final String iso;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = exercise, app = context.app;
    final name = '${e['name']}';
    final g = guideFor(e);
    final altName = e['alt'] ?? (jsonRows(e['alts']).firstOrNull?['name']);
    final alt = !jsTruthy(e['swapped']) && altName != null
        ? guideFor({'name': altName})
        : null;
    final last = plan.lastSession(app.repo.allDays(), name, iso);
    final part = '${e['part'] ?? partOfExercise(name)}';
    final info = exerciseInfo(
      AppMessages.of(context),
      recoveryStatus(app),
      name,
      part,
    );
    final mv = musclesOf(name, part);
    final showMuscles = mv != null && mv['matched'] != 'part';
    // 不在计划里的动作（器械库、换一个、从肌肉找动作）没有组数，不显示处方。
    final hasRx = e['target'] != null || e['sets'] != null;
    final weight = jsNumber(e['weight']);
    final steps = (g?['steps'] as List?) ?? const [];
    final mistakes = (g?['mistakes'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (g != null) GuideDemoPlayer(guide: g, name: name),
        if (g?['demoNote'] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: LText(g!['demoNote'] as String, style: AppText.hint(p)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: LText(name, style: AppText.display(p, size: 28)),
        ),
        if (hasRx || info.ready != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasRx) _Prescription(exercise: e),
                if (hasRx && weight > 0)
                  _Stat(
                    value: context.units.suggested(weight),
                    unit: Text(context.units.weightUnit),
                  ),
                if (info.ready != null) RecoveryTag(info, large: true),
              ],
            ),
          ),
        if (last != null) _LastSets(last: last),
        if (jsTruthy(e['gear']))
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Row(
              children: [
                AppIcon('weight', size: 16, color: p.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: LText(
                    '${e['gear']}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: p.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (showMuscles) ...[
          _label(p, '练哪里'),
          MuscleFocusCard(name: name, part: part),
        ],
        if (g != null) ...[
          _label(p, '怎么做'),
          _Steps(steps),
          if (mistakes.isNotEmpty) ...[_label(p, '常见错误'), _Mistakes(mistakes)],
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
            child: LText(
              '这个动作还没有示范图和要点，可以在「训练计划与提醒」里给它选一张示范图。',
              style: TextStyle(fontSize: 16, height: 1.5, color: p.text),
            ),
          ),
        if (jsTruthy(e['tip'])) ...[
          _label(p, '本计划的提醒'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: LText(
              '${e['tip']}',
              style: TextStyle(fontSize: 16, height: 1.5, color: p.text),
            ),
          ),
        ],
        if (alt != null) ...[
          _label(p, '也可以换成：${alt['label']}'),
          Row(
            children: [
              for (final frame in alt['frames'] as List)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        '$frame',
                        frameBuilder: revealImageFrame,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Steps(alt['steps'] as List? ?? const []),
        ],
        const SizedBox(height: 20),
        _VideoLink(name: name),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: LText(
            '3D 模型 Quaternius（CC0），照片 free-exercise-db（Unlicense）',
            style: TextStyle(fontSize: 13, height: 1.4, color: p.tertiary),
          ),
        ),
      ],
    );
  }

  static Widget _label(AppPalette p, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
    child: LText(text, style: AppText.title(p)),
  );
}

/// 示范播放：点一下暂停 / 继续。计时器只重建示范本身，不牵连下面的内容。
class GuideDemoPlayer extends StatefulWidget {
  const GuideDemoPlayer({super.key, required this.guide, required this.name});
  final Map<String, dynamic> guide;
  final String name;
  @override
  State<GuideDemoPlayer> createState() => _GuideDemoPlayerState();
}

class _GuideDemoPlayerState extends State<GuideDemoPlayer> {
  Timer? _timer;
  int _frame = 0;
  bool _paused = false;
  bool _visible = true;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted && _visible && !_paused) setState(() => _frame = 1 - _frame);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(GuideDemoPlayer old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _frame = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppMessages.of(context).text(_paused ? '继续播放示范' : '暂停示范'),
    child: Pressable(
      onTap: () => setState(() => _paused = !_paused),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GuideDemo(guide: widget.guide, frame: _frame, paused: _paused),
      ),
    ),
  );
}

/// 一个大数字加小号单位。
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit});
  final String value;
  final Widget unit;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppText.num(p, 26)),
        const SizedBox(width: 3),
        DefaultTextStyle(
          style: TextStyle(fontSize: 14, color: p.secondary),
          child: unit,
        ),
      ],
    );
  }
}

/// 「3 组 × 8–12 次」：数字大、单位小。
class _Prescription extends StatelessWidget {
  const _Prescription({required this.exercise});
  final Map<String, dynamic> exercise;
  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = exercise;
    final sets = jsString(e['target'] ?? e['sets']);
    final lo = jsString(e['min']), hi = jsString(e['max']);
    final range = lo == hi ? lo : '$lo–$hi';
    final unit = e['unit'] == 'sec'
        ? '秒'
        : jsTruthy(e['side'])
        ? '次/侧'
        : '次';
    final small = TextStyle(fontSize: 14, color: p.secondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(sets, style: AppText.num(p, 26)),
        const SizedBox(width: 3),
        LText('组', style: small),
        const SizedBox(width: 8),
        Text('×', style: small),
        const SizedBox(width: 8),
        Text(range, style: AppText.num(p, 26)),
        const SizedBox(width: 3),
        LText(unit, style: small),
      ],
    );
  }
}

/// 「上次 10/15」+ 每组一个小片，和记录页时间线的组片同款。
class _LastSets extends StatelessWidget {
  const _LastSets({required this.last});
  final Map<String, dynamic> last;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final date = '${last['date']}'.substring(5).replaceAll('-', '/');
    final style = AppText.num(p, 15);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: LText('上次 $date', style: AppText.hint(p)),
          ),
          for (final s in jsonRows(last['sets']))
            Container(
              constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  jsNumber(s['w']) > 0
                      ? '${context.units.load(jsNumber(s['w']))}×${s['reps']}'
                      : '${s['reps']}',
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 编号步骤：序号是 Numeral 大数字，正文 16 号正文色。
class _Steps extends StatelessWidget {
  const _Steps(this.rows);
  final List rows;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in rows.indexed)
          Padding(
            padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 14, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${i + 1}',
                      style: AppText.num(p, 20, color: p.secondary),
                    ),
                  ),
                ),
                Expanded(
                  child: LText(
                    '$t',
                    style: TextStyle(fontSize: 16, height: 1.5, color: p.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 常见错误：每条前一个小叉（警示红），正文仍是正文色。
class _Mistakes extends StatelessWidget {
  const _Mistakes(this.rows);
  final List rows;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in rows.indexed)
          Padding(
            padding: EdgeInsets.fromLTRB(4, i == 0 ? 0 : 14, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppIcon('close', size: 15, color: p.err),
                    ),
                  ),
                ),
                Expanded(
                  child: LText(
                    '$t',
                    style: TextStyle(fontSize: 16, height: 1.5, color: p.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 「搜示范视频」文字链接：正文色加粗 + 外链小图标。
class _VideoLink extends StatelessWidget {
  const _VideoLink({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: AppMessages.of(context).text('搜示范视频'),
        excludeSemantics: true,
        child: Pressable(
          onTap: () => context.app.native.openUrl(videoSearchUrl(name)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: LText(
                    '搜示范视频',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AppIcon('external', size: 16, color: p.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
