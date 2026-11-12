import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';
import '../../../core/haptics.dart';

import 'package:flutter/widgets.dart';

import '../../../theme/theme.dart';
import '../../kit/number_field.dart' show SheetInput;
import '../../kit/pressable.dart';

/// 记组用的加减读数：大数字（Numeral 字体）居中，两侧是清晰的圆形加减按钮。
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.unit,
    required this.step,
    this.focusNode,
    this.stepper,
  });
  final String value, label, unit;
  final double step;

  /// 自定义加减结果（当前值、方向 → 新值）。英制重量的步长随数值变化，用它覆盖 [step]。
  final num Function(num current, bool up)? stepper;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;

  void _bump(BuildContext context, double delta) {
    if (value.trim().isEmpty) {
      if (delta > 0) {
        HapticScope.of(context)?.selection();
        onChanged(
          '${stepper?.call(0, true) ?? step}'.replaceFirst(RegExp(r'\.0$'), ''),
        );
      }
      return;
    }
    final n = double.tryParse(value);
    if (n == null || !n.isFinite) return;
    final next = stepper != null
        ? stepper!(n, delta > 0).toDouble()
        : ((n + delta) * 1000).round() / 1000;
    if ((next < 0 ? 0 : next) == n) return;
    HapticScope.of(context)?.selection();
    onChanged(
      (next < 0 ? 0 : next).toString().replaceFirst(RegExp(r'\.0$'), ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget button(String text, String semantics, double delta) => Semantics(
      button: true,
      label: AppMessages.of(context).text(semantics),
      child: Pressable(
        onTap: () => _bump(context, delta),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
          child: ExcludeSemantics(
            child: LText(
              text,
              style: TextStyle(
                color: p.text,
                fontSize: 26,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          button('−', '减少$label', -step),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'Numeral'),
                  child: SheetInput(
                    value: value,
                    onChanged: onChanged,
                    label: label,
                    placeholder: '0',
                    numeric: true,
                    align: TextAlign.center,
                    size: 36,
                    letterSpacing: -0.36,
                    focusNode: focusNode,
                    weight: FontWeight.w700,
                  ),
                ),
                LText(
                  unit,
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          button('+', '增加$label', step),
        ],
      ),
    );
  }
}
