import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../domain/format.dart';
import '../../../theme/theme.dart';

/// 热量与蛋白的汇总：大号数字做主角，单位小号；小圆点只做点缀。
class NutritionSummary extends StatelessWidget {
  const NutritionSummary({
    super.key,
    required this.kcal,
    required this.protein,
    this.size = 26,
  });
  final Object? kcal, protein;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget item(Object? value, String unit, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fmt(value), style: AppText.num(p, size)),
            const SizedBox(width: 3),
            LText(unit, style: TextStyle(fontSize: 13, color: p.secondary)),
          ],
        ),
      ],
    );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [item(kcal, '千卡', p.kcal), item(protein, 'g 蛋白', p.protein)],
    );
  }
}
