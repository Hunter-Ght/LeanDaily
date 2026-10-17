import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../theme/theme.dart';
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
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: context.pal.fill2,
      borderRadius: BorderRadius.circular(12),
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

class FoodButton extends StatelessWidget {
  const FoodButton(this.label, this.onTap, {super.key, this.primary = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppMessages.of(context).text(label),
    child: Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: primary ? context.pal.tint : context.pal.fill2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: LText(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: primary ? context.pal.onTint : context.pal.text,
            ),
          ),
        ),
      ),
    ),
  );
}
