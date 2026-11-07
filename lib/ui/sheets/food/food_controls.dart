import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../theme/theme.dart';
import '../../kit/app_icon.dart';
import '../../kit/pressable.dart';
import '../../today/today_widgets.dart';

class FoodField extends StatelessWidget {
  const FoodField(
    this.label,
    this.value,
    this.onChanged, {
    super.key,
    this.numeric = false,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool numeric;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: context.pal.fill2,
      borderRadius: BorderRadius.circular(14),
    ),
    child: TodayInput(
      value: value,
      onChanged: onChanged,
      numeric: numeric,
      label: label,
      placeholder: label,
    ),
  );
}

/// 饮食弹层的按钮：主（墨色，[primary]）/ 次（fill2）/ 文字链接（[link]）。
/// 标签为「＋」「－」时画成圆形加减号。
class FoodButton extends StatelessWidget {
  const FoodButton(
    this.label,
    this.onTap, {
    super.key,
    this.primary = false,
    this.link = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary, link;

  bool get _round => label == '＋' || label == '－';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = primary ? p.onPrimary : p.text;
    final Widget content;
    if (_round) {
      content = label == '＋'
          ? AppIcon('plus', size: 20, color: fg)
          : Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(1),
              ),
            );
    } else {
      content = LText(
        label,
        style: TextStyle(
          fontSize: primary ? 16 : 15,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      );
    }
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: Container(
            constraints: BoxConstraints(
              minHeight: _round ? 44 : (primary ? 50 : 44),
              minWidth: 44,
            ),
            padding: _round
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: _round
                ? BoxDecoration(color: p.fill2, shape: BoxShape.circle)
                : BoxDecoration(
                    color: link
                        ? null
                        : primary
                        ? p.primary
                        : p.fill2,
                    borderRadius: BorderRadius.circular(primary ? 999 : 14),
                  ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// 小胶囊：已选食物（点一下移除）、份数快捷项。选中为墨色底，未选 fill2。
class FoodChip extends StatelessWidget {
  const FoodChip(
    this.label,
    this.onTap, {
    super.key,
    this.selected = false,
    this.removable = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool selected, removable;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = selected ? p.onPrimary : p.text;
    return Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: EdgeInsets.only(left: 12, right: removable ? 10 : 12),
            decoration: BoxDecoration(
              color: selected ? p.primary : p.fill2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LText(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (removable) ...[
                    const SizedBox(width: 6),
                    AppIcon('close', size: 14, color: p.secondary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
