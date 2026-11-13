import 'package:flutter/widgets.dart';

import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';

/// 横条的满刻度（每周组数）。固定不变，改重点时才能看出条的长短变化。
const volumeScale = 16.0;

const _groupNames = {
  'shoulders': '肩',
  'chest': '胸',
  'back': '背',
  'abs': '腹',
  'arms': '手臂',
  'glutes': '臀',
  'quads': '股四头',
  'hamstrings': '腘绳肌',
};

/// 组数的显示：整数不带小数，否则保留一位。
String setsText(num sets) {
  final r = (sets * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.round()}' : r.toStringAsFixed(1);
}

/// 8 个部位每周组数的横条。重点部位用训练橙色并标「多练」，其余用中性色。
class VolumeBars extends StatelessWidget {
  const VolumeBars({super.key, required this.rows});

  /// `weeklyVolume` 的结果。
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        for (final row in rows)
          Builder(
            builder: (context) {
              final focus = row['focus'] == true;
              final sets = (row['sets'] as num).toDouble();
              return Container(
                key: ValueKey('volume-${row['group']}'),
                constraints: const BoxConstraints(minHeight: 34),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: LText(
                        _groupNames['${row['group']}'] ?? '${row['group']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: focus ? FontWeight.w700 : FontWeight.w500,
                          color: p.text,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: (sets / volumeScale).clamp(0.0, 1.0)),
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.fill2,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: t,
                            child: Container(
                              decoration: BoxDecoration(
                                color: focus ? p.tint : p.tertiary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        setsText(sets),
                        textAlign: TextAlign.right,
                        style: AppText.num(
                          p,
                          17,
                          color: focus ? p.tint : p.text,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: focus
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.tintSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: LText(
                                  '多练',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: p.tint,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
