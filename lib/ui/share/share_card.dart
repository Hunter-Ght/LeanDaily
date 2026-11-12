import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/body_figure.dart';
import '../kit/wordmark.dart';
import 'share_data.dart';

/// 卡片比例。宽度固定 360 逻辑像素，按 3 倍导出：4:5 是 1080×1350，9:16 是 1080×1920。
enum ShareRatio {
  portrait(450, '4:5'),
  story(640, '9:16');

  const ShareRatio(this.height, this.label);
  final double height;
  final String label;
  static const double width = 360;
  static const double exportScale = 3;
  double get aspect => width / height;
}

/// 卡片的外观选项。
class ShareLook {
  const ShareLook({
    required this.dark,
    this.ratio = ShareRatio.portrait,
    this.showWeight = false,
  });
  final bool dark;
  final ShareRatio ratio;

  /// 带重量的新纪录是否写出具体重量。默认关。
  final bool showWeight;

  ShareLook copyWith({bool? dark, ShareRatio? ratio, bool? showWeight}) =>
      ShareLook(
        dark: dark ?? this.dark,
        ratio: ratio ?? this.ratio,
        showWeight: showWeight ?? this.showWeight,
      );
}

/// 一张分享海报。与界面的字号设置、深浅色设置无关：尺寸固定，配色由 [ShareLook.dark] 决定，
/// 所以预览里看到的就是导出的样子。
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.content, required this.look});
  final ShareContent content;
  final ShareLook look;

  @override
  Widget build(BuildContext context) {
    final p = look.dark ? AppPalette.dark : AppPalette.light;
    final tall = look.ratio == ShareRatio.story;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: PaletteScope(
        palette: p,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: p.text, decoration: TextDecoration.none),
          child: SizedBox(
            width: ShareRatio.width,
            height: look.ratio.height,
            child: ColoredBox(
              color: p.bg,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  tall ? 48 : 30,
                  28,
                  tall ? 36 : 24,
                ),
                child: switch (content) {
                  final TrainShare c => _TrainBody(c, look, p, tall),
                  final WeekShare c => _WeekBody(c, look, p, tall),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 日期小字。英文写成 “Fri, Oct 16”，中文写成 “10月16日 周五”。
Widget shareDate(BuildContext context, AppPalette p, String iso) {
  final style = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: p.secondary,
  );
  final d = isoDate(iso);
  if (AppMessages.of(context).code == 'en') {
    return Text(
      '${AppMessages.of(context).text(weekday(iso))}, ${_months[d.month - 1]} ${d.day}',
      style: style,
      maxLines: 1,
    );
  }
  return LText(
    '${d.month}月${d.day}日 ${weekday(iso)}',
    style: style,
    maxLines: 1,
  );
}

/// 一周的日期范围，如 “10月12日 – 10月18日” / “Oct 12 – Oct 18”。
Widget shareRange(
  BuildContext context,
  AppPalette p,
  String start,
  String end,
) {
  final style = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: p.secondary,
  );
  final a = isoDate(start), b = isoDate(end);
  final en = AppMessages.of(context).code == 'en';
  final text = en
      ? '${_months[a.month - 1]} ${a.day} – ${_months[b.month - 1]} ${b.day}'
      : '${a.month}月${a.day}日 – ${b.month}月${b.day}日';
  return Text(text, style: style, maxLines: 1);
}

/// 大标题：先按最大字号排，放不下（超过行数，或者最长的词比版面还宽）就逐级缩小。
class ShareFitTitle extends StatelessWidget {
  const ShareFitTitle(
    this.text, {
    super.key,
    required this.color,
    this.maxLines = 2,
    this.maxSize = 40,
    this.minSize = 22,
  });
  final String text;
  final Color color;
  final int maxLines;
  final double maxSize, minSize;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // 中文的间隔号本身是全角，前后再加空格会散成一排；中文标题去掉空格。
    // 英文里间隔号黏在前一个词后面（不换到行首）。
    final shown = AppMessages.of(context).code == 'en'
        ? AppMessages.of(context).text(text).replaceAll(' · ', '\u00A0· ')
        : AppMessages.of(context).text(text).replaceAll(' · ', '·');
    return LayoutBuilder(
      builder: (context, box) {
        var size = maxSize;
        for (; size > minSize; size -= 2) {
          final painter = TextPainter(
            text: TextSpan(
              text: shown,
              style: AppText.display(p, size: size),
            ),
            textDirection: Directionality.of(context),
            maxLines: maxLines,
          )..layout(maxWidth: box.maxWidth);
          final fits =
              !painter.didExceedMaxLines &&
              painter.minIntrinsicWidth <= box.maxWidth;
          painter.dispose();
          if (fits) break;
        }
        return Text(
          shown,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppText.display(p, size: size, color: color),
        );
      },
    );
  }
}

/// 人体图：正反两面并排，放在剩余空间正中，不比空间高、也不拉得太散。
class _Figure extends StatelessWidget {
  const _Figure({this.tones = const {}, this.heat = const {}});
  final Map<String, MuscleTone> tones;
  final Map<String, double> heat;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight.isFinite ? box.maxHeight : 240.0;
      return Center(
        child: SizedBox(
          width: math.min(box.maxWidth, h * 1.05),
          height: h,
          child: BodyFigure(tones: tones, heat: heat, height: h),
        ),
      );
    },
  );
}

/// 大数字 + 小标签。数字用 Numeral 字体；放不下时整体缩小，不换行。
class _StatText extends StatelessWidget {
  const _StatText(this.value, this.label, this.p, {this.size = 46});
  final String value, label;
  final AppPalette p;
  final double size;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: AppText.num(p, size)),
      ),
      const SizedBox(height: 5),
      LText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: p.secondary,
        ),
      ),
    ],
  );
}

/// 横排的一组数字（9:16 用）。
class _StatRow extends StatelessWidget {
  const _StatRow(this.stats, this.p);
  final List<(String, String)> stats;
  final AppPalette p;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (value, label) in stats)
        Expanded(child: _StatText(value, label, p)),
    ],
  );
}

/// 人体图在左、数字竖排在右（4:5 用）：人体图是主角，吃掉所有剩余的高度。
class _FigureWithStats extends StatelessWidget {
  const _FigureWithStats({
    required this.figure,
    required this.stats,
    required this.p,
  });
  final Widget figure;
  final List<(String, String)> stats;
  final AppPalette p;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: figure),
      const SizedBox(width: 12),
      SizedBox(
        width: 100,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (value, label)) in stats.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _StatText(value, label, p, size: 40),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// 底部：细线 + 字标。字标小而精，只作落款。
class _Footer extends StatelessWidget {
  const _Footer(this.p);
  final AppPalette p;
  @override
  Widget build(BuildContext context) {
    final zh = AppMessages.of(context).code != 'en';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 0.5, color: p.sep),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Wordmark(fontSize: 16),
            if (zh) ...[
              const SizedBox(width: 8),
              Text(
                'LeanDaily',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: p.secondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TrainBody extends StatelessWidget {
  const _TrainBody(this.c, this.look, this.p, this.tall);
  final TrainShare c;
  final ShareLook look;
  final AppPalette p;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final records = c.records.take(2).toList();
    final stats = [
      ('${c.exercises}', '个动作'),
      ('${c.sets}', '组'),
      ('${c.minutes}', '分钟'),
    ];
    final figure = _Figure(tones: c.tones);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shareDate(context, p, c.iso),
        SizedBox(height: tall ? 14 : 8),
        ShareFitTitle(
          c.title,
          color: p.tint,
          maxSize: tall ? 44 : 38,
          maxLines: 2,
        ),
        SizedBox(height: tall ? 16 : 10),
        if (tall) ...[
          Expanded(child: figure),
          const SizedBox(height: 20),
          _StatRow(stats, p),
        ] else
          Expanded(
            child: _FigureWithStats(figure: figure, stats: stats, p: p),
          ),
        if (records.isNotEmpty) ...[
          SizedBox(height: tall ? 22 : 12),
          LText(
            '新纪录',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: p.tint,
            ),
          ),
          const SizedBox(height: 4),
          for (final r in records) _RecordRow(r, look.showWeight, p),
        ],
        SizedBox(height: tall ? 24 : 14),
        _Footer(p),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(this.record, this.showWeight, this.p);
  final ShareRecord record;
  final bool showWeight;
  final AppPalette p;
  @override
  Widget build(BuildContext context) {
    final detail = record.shown(showWeight);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppMessages.of(context).text(record.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: p.text,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 12),
            LText(
              detail,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const _weekdayKeys = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class _WeekBody extends StatelessWidget {
  const _WeekBody(this.c, this.look, this.p, this.tall);
  final WeekShare c;
  final ShareLook look;
  final AppPalette p;
  final bool tall;

  Widget _dots(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.trained[i] ? p.tint : p.fill,
                ),
              ),
              const SizedBox(height: 7),
              LText(
                _weekdayKeys[i],
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: c.trained[i] ? p.text : p.secondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('${c.sets}', '组'),
      if (c.streakWeeks >= 2)
        ('${c.streakWeeks}', '周连续')
      else
        ('${c.exercises}', '个动作'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        shareRange(context, p, c.start, c.end),
        SizedBox(height: tall ? 10 : 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${c.trainDays}',
              style: AppText.num(p, tall ? 80 : 68, color: p.tint),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LText(
                '天训练',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(p, size: 22),
              ),
            ),
          ],
        ),
        SizedBox(height: tall ? 18 : 12),
        _dots(context),
        SizedBox(height: tall ? 14 : 8),
        if (tall) ...[
          Expanded(child: _Figure(heat: c.heat)),
          const SizedBox(height: 20),
          _StatRow(stats, p),
        ] else
          Expanded(
            child: _FigureWithStats(
              figure: _Figure(heat: c.heat),
              stats: stats,
              p: p,
            ),
          ),
        SizedBox(height: tall ? 24 : 14),
        _Footer(p),
      ],
    );
  }
}
