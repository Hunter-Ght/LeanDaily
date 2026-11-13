import 'package:flutter/widgets.dart';

import '../../domain/movements.dart' show MUSCLE, MUSCLE_PLAIN;
import '../../domain/muscle_brief.dart';
import '../../domain/stats_range.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import 'progress_sections.dart' show rangeEyebrow;
import 'stat_widgets.dart' show shortDate;

/// 点热力人体上的一块肌肉后，在人体图下方原地展开的小结（不是弹层）：
/// 范围内的组数、上次练的日期、最常练的动作，以及打开「怎么练它」的文字链接。
class MuscleBriefPanel extends StatelessWidget {
  const MuscleBriefPanel({
    super.key,
    required this.muscleId,
    required this.brief,
    required this.range,
    required this.onOpen,
  });
  final String muscleId;
  final MuscleBrief brief;
  final StatsRange range;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final name = MUSCLE[muscleId]?['name'] ?? '';
    final plain = MUSCLE_PLAIN[muscleId];
    final stat = AppText.num(p, 28);
    final since = brief.daysSince;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              LText(name, style: AppText.title(p)),
              if (plain != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: LText(
                    plain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.hint(p),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(rangeEyebrow(range), style: AppText.hint(p)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${brief.sets}', style: stat),
                        LText(
                          ' 组',
                          style: TextStyle(fontSize: 14, color: p.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText('上次练', style: AppText.hint(p)),
                    if (since == null)
                      LText(
                        '没练过',
                        style: stat.copyWith(fontSize: 20, height: 1.6),
                      )
                    else
                      LText(
                        sinceText(since),
                        style: stat.copyWith(fontSize: 20, height: 1.6),
                      ),
                    if (since != null && since > 0)
                      Text(shortDate(brief.lastDate), style: AppText.hint(p)),
                  ],
                ),
              ),
            ],
          ),
          if (brief.top.isNotEmpty) ...[
            const SizedBox(height: 10),
            LText('最常练', style: AppText.hint(p)),
            const SizedBox(height: 2),
            for (final ex in brief.top)
              LText(
                ex,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
          ],
          Semantics(
            button: true,
            child: Pressable(
              onTap: onOpen,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LText(
                      '怎么练它',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: p.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppIcon('right', size: 14, color: p.primary),
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
