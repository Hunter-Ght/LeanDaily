import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../domain/format.dart';
import '../../../theme/theme.dart';

/// Nutrition uses quiet text values; only the small markers carry meaning.
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({
    super.key,
    required this.kcal,
    required this.protein,
  });
  final Object? kcal, protein;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget item(String text, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        LText(
          text,
          style: TextStyle(
            fontSize: 14,
            color: p.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        item('${fmt(kcal)} 千卡', p.kcal),
        item('蛋白 ${fmt(protein)} g', p.protein),
      ],
    );
  }
}
