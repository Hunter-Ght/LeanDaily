import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../kit/transitions.dart';

import '../../kit/pressable.dart';
import '../../kit/segments.dart';
import '../../../core/haptics.dart';
import '../../kit/app_icon.dart';
import '../../../domain/movements.dart';
import '../../../domain/muscles.dart';
import '../../../theme/theme.dart';
import '../../../theme/tokens.dart';
import 'body_map.dart';

enum MuscleMode { fatigue, volume, detrain }

const _targets = {
  'chest': 8,
  'back': 8,
  'shoulders': 6,
  'arms': 6,
  'abs': 6,
  'quads': 8,
  'hamstrings': 6,
  'glutes': 6,
  'calves': 4,
};
const _labels = ['恢复状态', '训练量', '久未练'];
const _notes = [
  '颜色越深，肌肉还没缓过来；已恢复的显示为灰色。',
  '近 7 天各肌肉的有效组数，颜色越深越接近每周所需的量。',
  '颜色越深，离上次训练越久；很久没练或没练过的最深。',
];
String _fmt(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();
String _daysText(num d) =>
    d < 0.75 ? '不到 1 天' : '约 ${_fmt((d * 2).round() / 2)} 天';
String _sinceText(num? n) {
  if (n == null) return '没练过';
  if (n <= 0) return '今天';
  if (n < 14) return '$n 天前';
  if (n < 70) return '${(n / 7).round()} 周前';
  return '${(n / 30).round()} 个月前';
}

class MuscleCard extends StatefulWidget {
  const MuscleCard({
    super.key,
    required this.days,
    required this.nowMs,
    required this.bodyPaths,
    this.onOpen,
    this.initialMode = MuscleMode.fatigue,
  });
  final Map<String, Map<String, dynamic>> days;
  final Map<String, dynamic> bodyPaths;
  final int nowMs;
  final ValueChanged<String>? onOpen;
  final MuscleMode initialMode;
  @override
  State<MuscleCard> createState() => _MuscleCardState();
}

class _MuscleCardState extends State<MuscleCard> {
  late MuscleMode mode;
  String picked = '';
  bool _showAll = false, _showDetail = false;
  late Map<String, dynamic> status;
  late BodyGeometry geometry;
  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 资料里改了性别，人体图跟着换；解析结果有缓存。
    geometry = BodyGeometry(widget.bodyPaths, female: BodySexScope.of(context));
  }

  void _load() {
    status = muscleStatus(widget.days, widget.nowMs);
  }

  @override
  void didUpdateWidget(MuscleCard old) {
    super.didUpdateWidget(old);
    if (old.bodyPaths != widget.bodyPaths) {
      geometry = BodyGeometry(
        widget.bodyPaths,
        female: BodySexScope.of(context),
      );
    }
    if (old.days != widget.days ||
        old.nowMs != widget.nowMs ||
        old.bodyPaths != widget.bodyPaths) {
      _load();
    }
  }

  double level(Map<String, dynamic> m) {
    if (mode == MuscleMode.fatigue) return (m['heat'] as num).toDouble();
    if (mode == MuscleMode.volume) {
      return ((m['sets7'] as num) / (_targets[m['group']] ?? 6)).clamp(0, 1);
    }
    return m['last'] == null && status['setCount'] == 0
        ? 0
        : detrainLevel(m['daysSince'] as num?);
  }

  String value(Map<String, dynamic> m) {
    if (mode == MuscleMode.fatigue) {
      return m['recovered'] as bool
          ? '已恢复'
          : '${_daysText(m['daysLeft'] as num)}恢复';
    }
    if (mode == MuscleMode.volume) {
      return (m['sets7'] as num) < 0.05
          ? '近 7 天未练到'
          : '${_fmt(((m['sets7'] as num) * 10).round() / 10)} 组';
    }
    return _sinceText(m['daysSince'] as num?);
  }

  String detail(Map<String, dynamic> m) {
    if (mode == MuscleMode.fatigue) {
      final from = m['from'] as List<Map<String, dynamic>>;
      if (from.isEmpty) return m['recovered'] as bool ? '最近没有练到这里。' : '';
      final src = from
          .take(3)
          .map((f) => '${f['ex']} ${f['sets']} 组')
          .join('、');
      return '${m['recovered'] as bool ? '已基本恢复' : '还要${_daysText(m['daysLeft'] as num)}才恢复'}。最近的负荷主要来自：$src。';
    }
    if (mode == MuscleMode.volume) {
      return '近 7 天 ${_fmt(((m['sets7'] as num) * 10).round() / 10)} 组，近 30 天 ${_fmt(((m['sets30'] as num) * 10).round() / 10)} 组；每周参考量约 ${_targets[m['group']] ?? 6} 组（${GROUP[m['group']]!['name']}）。';
    }
    return m['last'] != null
        ? '最近一次练到是 ${m['last']}，${_sinceText(m['daysSince'] as num?)}。'
        : '还没有练到过这块肌肉。';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final hue = switch (mode) {
      MuscleMode.fatigue => p.tint,
      MuscleMode.volume => p.volume,
      MuscleMode.detrain => p.detrain,
    };
    final muscles = status['byMuscle'] as Map<String, Map<String, dynamic>>;
    final rows = muscles.values.toList();
    num sortValue(Map<String, dynamic> m) => switch (mode) {
      MuscleMode.fatigue => m['fatigue'] as num,
      MuscleMode.volume => m['sets7'] as num,
      MuscleMode.detrain => m['daysSince'] as num? ?? 1000000,
    };
    // Explicit tie-break preserves the web's stable sort/catalog order.
    final order = muscles.keys.toList();
    rows.sort((a, b) {
      final result = sortValue(b).compareTo(sortValue(a));
      return result != 0
          ? result
          : order
                .indexOf(a['id'] as String)
                .compareTo(order.indexOf(b['id'] as String));
    });
    final current = muscles[picked] ?? rows.first;
    final visible = rows;
    final selected = current['id'] as String;
    final colors = {
      for (final m in rows)
        m['id'] as String: _mixedFill(p.fill, hue, level(m)),
    };
    final levels = {for (final m in rows) m['id'] as String: level(m)};
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(Metrics.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Metrics.pagePad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText('肌肉状态', style: AppText.h2(p)),
            const SizedBox(height: 12.0),
            _segments(p),
            const SizedBox(height: 12.0),
            TweenAnimationBuilder<_Frame>(
              tween: _FrameTween(end: _Frame(colors, levels)),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              builder: (context, frame, _) {
                final figures = Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final back in [false, true]) ...[
                          if (back) const SizedBox(width: 6.0),
                          Expanded(
                            child: Column(
                              children: [
                                BodyMap(
                                  key: ValueKey(
                                    back ? 'body-back' : 'body-front',
                                  ),
                                  geometry: geometry,
                                  back: back,
                                  colors: frame.colors,
                                  palette: p,
                                  selected: selected,
                                  onSelect: (id) {
                                    if (id != picked) {
                                      HapticScope.of(context)?.selection();
                                    }
                                    setState(() => picked = id);
                                  },
                                ),
                                const SizedBox(height: 2),
                                LText(
                                  back ? '背面' : '正面',
                                  style: AppText.calLabel(p)
                                      .copyWith(letterSpacing: 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        children: [
                          LText(
                            switch (mode) {
                              MuscleMode.fatigue => '已恢复',
                              MuscleMode.volume => '偏少',
                              MuscleMode.detrain => '刚练过',
                            },
                            style: AppText.calLabel(p)
                                .copyWith(letterSpacing: 0),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Container(
                              height: 6.0,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3.0),
                                gradient: LinearGradient(colors: [p.fill, hue]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          LText(
                            switch (mode) {
                              MuscleMode.fatigue => '很累',
                              MuscleMode.volume => '够量',
                              MuscleMode.detrain => '很久没练',
                            },
                            style: AppText.calLabel(p)
                                .copyWith(letterSpacing: 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: LText(
                            current['name'] as String,
                            style: AppText.sect(p),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        LText(
                          value(current),
                          style: AppText.navWeek(p)
                              .copyWith(color: hue, letterSpacing: 0),
                        ),
                      ],
                    ),
                    if (detail(current).isNotEmpty) ...[
                      const SizedBox(height: 4.0),
                      LText(
                        detail(current),
                        maxLines: _showDetail ? null : 2,
                        overflow: _showDetail ? null : TextOverflow.ellipsis,
                        style: AppText.hint(p),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _openButton(selected, '看怎么练、加入计划', p),
                    const SizedBox(height: 8),
                    for (var i = 0; i < visible.length; i++)
                      Reveal(
                        visible: _showAll || i < Metrics.musclePreviewCount,
                        child: Column(
                          children: [
                            if (i > 0) Container(height: 0.5, color: p.sep),
                            Row(
                              children: [
                                Expanded(
                                  child: _row(
                                    visible[i],
                                    selected,
                                    p,
                                    hue,
                                    frame.levels[visible[i]['id']]!,
                                  ),
                                ),
                                if (_needs(visible[i])) ...[
                                  const SizedBox(width: 6),
                                  _openButton(
                                    visible[i]['id'] as String,
                                    '练它',
                                    p,
                                    hue: hue,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    Pressable(
                      onTap: () => setState(() => _showAll = !_showAll),
                      child: SizedBox(
                        height: Metrics.touchTarget,
                        child: Center(
                          child: LText(
                            _showAll ? '收起列表' : '查看全部 ${rows.length} 块肌肉',
                            style: AppText.hint(p).copyWith(color: p.tint),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        MediaQuery.sizeOf(context).width >=
                            Metrics.twoBreakpoint &&
                        MediaQuery.sizeOf(context).height >=
                            Metrics.minTallForWide;
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 340.0, child: figures),
                              const SizedBox(width: 24.0),
                              Expanded(child: info),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              figures,
                              const SizedBox(height: 14.0),
                              info,
                            ],
                          );
                  },
                );
              },
            ),
            const SizedBox(height: 12.0),
            LText(_notes[mode.index], style: AppText.hint(p)),
            Pressable(
              onTap: () => setState(() => _showDetail = !_showDetail),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: LText(
                  _showDetail ? '收起说明' : '估算依据',
                  style: AppText.hint(p).copyWith(color: p.tint),
                ),
              ),
            ),
            Reveal(
              visible: _showDetail,
              child: _showDetail
                  ? LText(
                      '${status['setCount'] == 0 ? '记过正式组之后，这里就会亮起来。' : ''}根据你记的组数、次数和余力估算，仅供参考，恢复快慢因人而异。',
                      style: AppText.hint(p),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  bool _needs(Map<String, dynamic> m) {
    if (status['setCount'] == 0 && mode != MuscleMode.detrain) return false;
    if (mode == MuscleMode.detrain) {
      return m['daysSince'] == null || (m['daysSince'] as num) >= 14;
    }
    return mode == MuscleMode.volume &&
        (m['sets7'] as num) < (_targets[m['group']] ?? 6) * .5;
  }

  Widget _openButton(String id, String label, AppPalette p, {Color? hue}) =>
      Semantics(
        button: true,
        label: AppMessages.of(context)
            .text(label == '练它' ? '练${MUSCLE[id]!['name']}的动作' : label),
        child: Pressable(
          onTap: () => widget.onOpen?.call(id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Container(
                constraints: BoxConstraints(minHeight: label == '练它' ? 30 : 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: p.tintSoft,
                  borderRadius: BorderRadius.circular(label == '练它' ? 99 : 14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: LText(
                        label,
                        style: TextStyle(
                          fontSize: label == '练它' ? 13 : 16,
                          fontWeight: FontWeight.w600,
                          color: hue ?? p.tint,
                        ),
                      ),
                    ),
                    if (label != '练它') ...[
                      const SizedBox(width: 4),
                      AppIcon('right', size: 16, color: p.tint),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _segments(AppPalette p) => AppSegments(
    labels: _labels,
    selected: mode.index,
    itemKeys: [for (final m in MuscleMode.values) ValueKey('mode-${m.name}')],
    onChanged: (i) => setState(() {
      mode = MuscleMode.values[i];
      _showDetail = false;
    }),
  );
  Widget _row(
    Map<String, dynamic> m,
    String selected,
    AppPalette p,
    Color hue,
    double lv,
  ) {
    final nameStyle = AppText.navWeek(p)
        .copyWith(color: p.text, letterSpacing: 0);
    final valueStyle = AppText.weekGoal(p);
    final pct = (lv * 100.0).round() / 100.0;
    final fraction = lv > 0 ? pct.clamp(4.0 / 100.0, 1.0) : 0.0;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(m['name'] as String),
      selected: m['id'] == selected,
      child: Pressable(
        key: ValueKey('muscle-row-${m['id']}'),

        onTap: () {
          if (picked != m['id']) HapticScope.of(context)?.selection();
          setState(() => picked = m['id'] as String);
        },
        child: Container(
          height: 44.0,
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            color: m['id'] == selected ? p.fill2 : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              SizedBox(
                width: nameStyle.fontSize! * 5.5,
                child: LText(m['name'] as String, style: nameStyle),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: mode == MuscleMode.detrain
                    ? LText(
                        m['daysSince'] == null ? '' : '距上次',
                        textAlign: TextAlign.right,
                        style: AppText.hint(p),
                      )
                    : Container(
                        height: 6.0,
                        decoration: BoxDecoration(
                          color: p.fill,
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: fraction,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: hue,
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10.0),
              SizedBox(
                width: valueStyle.fontSize! * 6.4,
                child: LText(
                  value(m),
                  style: valueStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Frame {
  const _Frame(this.colors, this.levels);
  final Map<String, Color> colors;
  final Map<String, double> levels;

  @override
  bool operator ==(Object other) =>
      other is _Frame &&
      mapEquals(colors, other.colors) &&
      mapEquals(levels, other.levels);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      colors.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      levels.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

class _FrameTween extends Tween<_Frame> {
  _FrameTween({required _Frame end}) : super(begin: end, end: end);
  @override
  _Frame lerp(double t) => _Frame(
    {
      for (final id in end!.colors.keys)
        id: Color.lerp(begin!.colors[id], end!.colors[id], t)!,
    },
    {
      for (final id in end!.levels.keys)
        id: begin!.levels[id]! + (end!.levels[id]! - begin!.levels[id]!) * t,
    },
  );
}

// CSS color-mix(in srgb) interpolates premultiplied alpha.
Color _mixedFill(Color fill, Color hue, double level) {
  final alpha = fill.a * (1 - level) + hue.a * level;
  return Color.lerp(
    fill.withValues(alpha: 1),
    hue.withValues(alpha: 1),
    alpha == 0 ? 0 : hue.a * level / alpha,
  )!.withValues(alpha: alpha);
}
