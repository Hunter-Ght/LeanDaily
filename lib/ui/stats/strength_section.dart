import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:leandaily/l10n/app_messages.dart';

import '../../domain/format.dart';
import '../../domain/stats.dart' show chartPoints;
import '../../domain/stats_range.dart';
import '../../domain/strength_rows.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/form.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'progress_sections.dart' show rangeEyebrow;
import 'stat_widgets.dart';

/// 力量：每个动作一行（名称 + 最佳成绩 + 较范围起点的变化），点一行原地展开曲线。
class StrengthSection extends StatefulWidget {
  const StrengthSection({
    super.key,
    required this.exercises,
    required this.bests,
    required this.today,
    this.range = StatsRange.weeks4,
  });
  final List<Map<String, dynamic>> exercises, bests;
  final String today;
  final StatsRange range;

  /// 默认显示的动作数，其余点「查看全部」。
  static const preview = 4;

  @override
  State<StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends State<StrengthSection> {
  String? open;
  bool all = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rows = strengthRows(
      exercises: widget.exercises,
      bests: widget.bests,
      today: widget.today,
      range: widget.range,
    );
    return StatBlock(
      title: '力量',
      trailing: LText(rangeEyebrow(widget.range), style: AppText.hint(p)),
      children: [
        const SizedBox(height: 6),
        for (final (i, r) in rows.indexed)
          Reveal(
            visible: all || i < StrengthSection.preview,
            child: _StrengthRowView(
              row: r,
              range: widget.range,
              first: i == 0,
              open: open == r.name,
              onTap: () =>
                  setState(() => open = open == r.name ? null : r.name),
            ),
          ),
        if (rows.length > StrengthSection.preview)
          FormButton(
            all ? '收起' : '查看全部',
            plain: true,
            onTap: () => setState(() => all = !all),
          ),
      ],
    );
  }
}

class _StrengthRowView extends StatelessWidget {
  const _StrengthRowView({
    required this.row,
    required this.range,
    required this.first,
    required this.open,
    required this.onTap,
  });
  final StrengthRow row;
  final StatsRange range;
  final bool first, open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.sep, width: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: AppMessages.of(context).text(row.name),
            child: Pressable(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LText(
                            row.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _caption(p),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _best(p),
                    const SizedBox(width: 6),
                    Transform.rotate(
                      angle: open ? -math.pi / 2 : math.pi / 2,
                      child: AppIcon('right', size: 14, color: p.tertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Reveal(
            visible: open,
            child: open ? _Curve(row: row) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 最佳成绩：大数字 + 小号单位。
  Widget _best(AppPalette p) {
    final unit = TextStyle(fontSize: 13, color: p.secondary);
    final b = row.best;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: row.bodyweight
          ? [
              LText('自重 × ', style: unit),
              Text(fmt(b['heavyReps']), style: AppText.num(p, 26)),
              LText(' 次', style: unit),
            ]
          : [
              Text(fmt(b['heavy']), style: AppText.num(p, 26)),
              LText(' kg', style: unit),
              Text(' × ', style: unit),
              Text(fmt(b['heavyReps']), style: AppText.num(p, 26)),
            ],
    );
  }

  /// 与范围起点相比的变化：进步用发力橙，其余用次要色。
  Widget _caption(AppPalette p) {
    final secondary = TextStyle(fontSize: 13, height: 1.3, color: p.secondary);
    final base = row.base == StrengthBase.firstRecord
        ? '第一次记录'
        : switch (range) {
            StatsRange.weeks4 => '4 周前',
            StatsRange.weeks12 => '12 周前',
            StatsRange.all => '第一次记录',
          };
    final v = fmt(row.delta);
    final text = switch (row.change) {
      StrengthChange.first => '首次记录',
      StrengthChange.idle => switch (range) {
        StatsRange.weeks12 => '近 12 周没练过',
        _ => '近 4 周没练过',
      },
      StrengthChange.flat => '和$base持平',
      StrengthChange.up =>
        row.bodyweight ? '↑ 比 $base +$v 次' : '↑ 估算极限比 $base +$v kg',
      StrengthChange.down =>
        row.bodyweight ? '比 $base −$v 次' : '估算极限比 $base −$v kg',
    };
    return LText(
      text,
      style: row.change == StrengthChange.up
          ? secondary.copyWith(color: p.tint, fontWeight: FontWeight.w600)
          : secondary,
    );
  }
}

/// 展开后的曲线：只有 1 个数据点时不画空坐标，改成一句提示。
class _Curve extends StatelessWidget {
  const _Curve({required this.row});
  final StrengthRow row;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final points = row.points;
    final body = row.bodyweight;
    final last = points.last;
    final chart = chartPoints(
      body
          ? [
              for (final e in points) {...e, 'e1': e['reps']},
            ]
          : points,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(body ? '次数' : '估算极限', style: AppText.hint(p)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                body ? fmt(last['reps']) : fmt(last['e1']),
                style: AppText.num(p, 36),
              ),
              LText(
                body ? ' 次' : ' kg',
                style: TextStyle(fontSize: 15, color: p.secondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LText(
            body
                ? '最近一次 · ${shortDate(last['iso'])} · 自重 × ${fmt(last['reps'])} 次'
                : '最近一次估算极限 · ${shortDate(last['iso'])} · ${fmt(last['weight'])}×${fmt(last['reps'])}',
            style: AppText.hint(p),
          ),
          const SizedBox(height: 10),
          if (points.length < 2)
            LText('再练几次就能看到曲线', style: AppText.body(p).copyWith(fontSize: 15))
          else ...[
            Semantics(
              label: AppMessages.of(context)
                  .text('${row.name} 的${body ? '次数' : '估算极限'}'),
              image: true,
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: CustomPaint(
                  painter: EstimateChart(jsonRows(chart['dots']), p.tint),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final e in [
                  jsonRows(chart['list']).first,
                  jsonRows(chart['list']).last,
                ])
                  LText(shortDate(e['iso']), style: AppText.hint(p)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
