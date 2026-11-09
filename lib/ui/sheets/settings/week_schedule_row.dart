import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../theme/theme.dart';
import '../../kit/app_icon.dart';
import '../../kit/menu.dart';
import '../../kit/pressable.dart';

const weekdayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/// 「每周安排」的一行：星期（固定宽度）+ 部位小胶囊 + 右侧场地与箭头。
/// 训练日名称（如「背 · 腿 · 手臂」）拆成一个个小胶囊，宽度不够时在行内收窄、省略，不会折成两行；
/// 休息日显示中性的「休息」。点整行换这一天练什么，点场地换默认场地。
class WeekScheduleRow extends StatelessWidget {
  const WeekScheduleRow({
    super.key,
    required this.day,
    required this.workout,
    required this.workoutOptions,
    required this.onWorkout,
    this.venue,
    this.onVenue,
  });

  /// 0 = 周日 … 6 = 周六。
  final int day;

  /// 当天安排的训练日 id；空串 = 休息。
  final String workout;

  /// id → 显示名，含 '' → 「休息」。
  final Map<String, String> workoutOptions;
  final ValueChanged<String> onWorkout;

  /// 为 null 表示这个训练日没有健身房版，不显示场地。
  final String? venue;
  final ValueChanged<String>? onVenue;

  /// 「背 · 腿 · 手臂」「胸 + 肩」拆成部位；没有分隔符就是一个整体。
  static List<String> parts(String title) => [
    for (final s in title.split(RegExp(r'\s*[·+]\s*')))
      if (s.trim().isNotEmpty) s.trim(),
  ];

  Future<void> _pickWorkout(BuildContext context) async {
    final label = '${weekdayNames[day]}安排';
    final picked = await showActionMenu(
      context,
      title: label,
      actions: [
        for (final e in workoutOptions.entries)
          MenuAction(id: e.key, label: e.value, selected: e.key == workout),
      ],
    );
    if (picked != null && context.mounted) onWorkout(picked.id);
  }

  Future<void> _pickVenue(BuildContext context) async {
    final label = '${weekdayNames[day]}默认场地';
    final picked = await showActionMenu(
      context,
      title: label,
      actions: [
        MenuAction(id: 'home', label: '居家', selected: venue == 'home'),
        MenuAction(id: 'gym', label: '健身房', selected: venue == 'gym'),
      ],
    );
    if (picked != null && context.mounted) onVenue?.call(picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rest = workout.isEmpty;
    final title = workoutOptions[workout] ?? workout;
    final dayName = weekdayNames[day];
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('$dayName安排'),
      value: AppMessages.of(context).text(title),
      excludeSemantics: true,
      child: Pressable(
        scale: 0.99,
        onTap: () => _pickWorkout(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: LText(
                  dayName,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ),
              Expanded(
                child: rest
                    ? LText(
                        '休息',
                        maxLines: 1,
                        style: TextStyle(fontSize: 16, color: p.secondary),
                      )
                    : Row(
                        children: [
                          for (final (i, part) in parts(
                            AppMessages.of(context).text(title),
                          ).indexed) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Flexible(child: _PartPill(part)),
                          ],
                        ],
                      ),
              ),
              if (!rest && venue != null && onVenue != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  key: ValueKey('schedule-venue-$day'),
                  button: true,
                  label: AppMessages.of(context).text('$dayName默认场地'),
                  value: AppMessages.of(context)
                      .text(venue == 'gym' ? '健身房' : '居家'),
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: () => _pickVenue(context),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: p.fill2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: LText(
                        venue == 'gym' ? '健身房' : '居家',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AppIcon('right', size: 14, color: p.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartPill extends StatelessWidget {
  const _PartPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.tintSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      // widthFactor: 1 让胶囊贴着文字宽度，不撑满 Flexible 给的空间。
      child: Center(
        widthFactor: 1,
        child: LText(
          text,
          localize: false,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: p.tint,
          ),
        ),
      ),
    );
  }
}
