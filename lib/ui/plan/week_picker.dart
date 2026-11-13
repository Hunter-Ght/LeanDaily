import 'package:leandaily/l10n/app_messages.dart';

import 'package:flutter/widgets.dart';

import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';

/// 星期的名字，下标 0 是周日（与 plan.schedule 一致）。
const weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/// 一周七个圆点（周一到周日）：亮的是训练日，圆点里是当天训练的一个字。
/// 点圆点开关某一天。
class WeekPicker extends StatelessWidget {
  const WeekPicker({super.key, required this.labels, required this.onToggle});

  /// 训练日（0 是周日）→ 圆点里的字。不在里面的是休息日。
  final Map<int, String> labels;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        for (final day in const [1, 2, 3, 4, 5, 6, 0])
          Expanded(
            child: Semantics(
              button: true,
              selected: labels.containsKey(day),
              label: AppMessages.of(context).text(weekdayNames[day]),
              excludeSemantics: true,
              child: Pressable(
                key: ValueKey('plan-day-$day'),
                haptic: true,
                onTap: () => onToggle(day),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: labels.containsKey(day) ? p.tint : p.fill2,
                      ),
                      child: labels.containsKey(day)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: LText(
                                  labels[day]!,
                                  maxLines: 1,
                                  softWrap: false,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: p.onTint,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    LText(
                      weekdayNames[day],
                      maxLines: 1,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: labels.containsKey(day)
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: labels.containsKey(day) ? p.text : p.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
