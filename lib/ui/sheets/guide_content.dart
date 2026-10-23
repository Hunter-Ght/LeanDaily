import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/guide.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/guide_demo.dart';
import '../kit/app_icon.dart';
import '../today/today_widgets.dart';

/// 弹层内的示范排版；播放与交互保持共享版本的行为。
class SheetGuideBody extends StatefulWidget {
  const SheetGuideBody({super.key, required this.exercise, required this.iso});
  final Map<String, dynamic> exercise;
  final String iso;
  @override
  State<SheetGuideBody> createState() => _SheetGuideBodyState();
}

class _SheetGuideBodyState extends State<SheetGuideBody> {
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
  void didUpdateWidget(SheetGuideBody old) {
    super.didUpdateWidget(old);
    if (old.exercise['name'] != widget.exercise['name']) _frame = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = widget.exercise;
    final g = guideFor(e);
    final altName = e['alt'] ?? (jsonRows(e['alts']).firstOrNull?['name']);
    final alt = !jsTruthy(e['swapped']) && altName != null
        ? guideFor({'name': altName})
        : null;
    final last = plan.lastSession(
      context.app.repo.allDays(),
      '${e['name']}',
      widget.iso,
    );
    Widget line(
      String text, {
      double size = 14,
      bool bold = false,
      bool secondary = true,
      double top = 6,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 0),
      child: LText(
        text,
        style: TextStyle(
          fontSize: size,
          height: 1.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: secondary ? p.secondary : p.text,
        ),
      ),
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: LText(
        text,
        style: TextStyle(
          fontSize: 17,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
      ),
    );
    List<Widget> bullets(Object? rows, bool ordered) => [
      for (final (i, t) in ((rows as List?) ?? []).indexed)
        Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            4,
            i == (rows as List).length - 1 ? 0 : 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: LText(
                  ordered ? '${i + 1}.' : '•',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: p.secondary,
                  ),
                ),
              ),
              Expanded(
                child: LText(
                  '$t',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: p.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (g != null)
          Semantics(
            button: true,
            label: AppMessages.of(context).text(_paused ? '继续播放示范' : '暂停示范'),
            child: Pressable(
              onTap: () => setState(() => _paused = !_paused),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: GuideDemo(guide: g, frame: _frame, paused: _paused),
              ),
            ),
          ),
        if (g?['demoNote'] != null) line(g!['demoNote'] as String, top: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
          child: LText(
            '${e['name']}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
        ),
        line(
          '${e['target'] != null ? '今天 ${plan.prescription(e)}' : '${e['sets']} 组 × ${e['min']}～${e['max']}'}${jsNumber(e['weight']) > 0 ? ' · ${fmt(e['weight'])} kg' : ''}',
          size: 14,
          top: 6,
        ),
        if (last != null)
          line(
            '上次 ${('${last['date']}').substring(5).replaceAll('-', '/')}：${jsonRows(last['sets']).map((s) => jsNumber(s['w']) > 0 ? '${fmt(s['w'])}×${s['reps']}' : '${s['reps']}').join(' / ')}',
          ),
        if (jsTruthy(e['gear']))
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(
              children: [
                AppIcon('weight', size: 16, color: p.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: LText(
                    '${e['gear']}',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: p.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (g != null) ...[
          heading('怎么做'),
          ...bullets(g['steps'], true),
          heading('常见错误'),
          ...bullets(g['mistakes'], false),
        ] else
          line('这个动作还没有示范图和要点，可以在「训练计划与提醒」里给它选一张示范图。'),
        if (jsTruthy(e['tip'])) ...[heading('本计划的提醒'), line('${e['tip']}')],
        if (alt != null) ...[
          heading('也可以换成：${alt['label']}'),
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
          ...bullets(alt['steps'], true),
        ],
        const SizedBox(height: 20),
        TodayButton(
          '搜示范视频',
          soft: true,
          large: true,
          height: 48,
          fontSize: 16,
          onTap: () =>
              context.app.native.openUrl(videoSearchUrl('${e['name']}')),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: LText(
            '示范图来自开源动作库 free-exercise-db（Unlicense）',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.tertiary),
          ),
        ),
      ],
    );
  }
}
