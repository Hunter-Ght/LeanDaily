import 'package:flutter/widgets.dart';

import '../../../domain/foods.dart';
import '../../../domain/format.dart';
import '../../../theme/theme.dart';
import '../../kit/sheet.dart';
import 'food_controls.dart';
import 'nutrition_summary.dart';

class FoodPortionPanel extends StatefulWidget {
  const FoodPortionPanel({super.key, required this.food});
  final Map<String, dynamic> food;
  @override
  State<FoodPortionPanel> createState() => _FoodPortionPanelState();
}

class _FoodPortionPanelState extends State<FoodPortionPanel> {
  late bool _grams = widget.food['unit'] == '100g';
  late String _quantity = _grams ? '100' : '1';
  Map<String, dynamic>? get _entry {
    final n = num.tryParse(_quantity);
    if (n == null || !n.isFinite || n <= 0) return null;
    try {
      final entry = entryFor(
        widget.food,
        grams: _grams ? n : null,
        units: _grams ? null : n,
      );
      if (widget.food['recent'] == true) {
        entry['portion'] = '约${fmt(n)}份（上次份量）';
      }
      return entry;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24 +
            MediaQuery.viewPaddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.food['name']}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: context.pal.text,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FoodButton(
                '－',
                () => setState(
                  () => _quantity = fmt(
                    ((num.tryParse(_quantity) ?? 1) - 1).clamp(1, 9999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FoodField(
                  _grams ? '克数' : '份数',
                  _quantity,
                  (v) => setState(() => _quantity = v),
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              FoodButton(
                '＋',
                () => setState(
                  () => _quantity = fmt((num.tryParse(_quantity) ?? 0) + 1),
                ),
              ),
            ],
          ),
          if (widget.food['recent'] != true)
            FoodButton(
              _grams ? '改用份数（${widget.food['unit']}）' : '改用克数',
              () => setState(() {
                _grams = !_grams;
                _quantity = _grams ? '100' : '1';
              }),
            ),
          const SizedBox(height: 12),
          if (entry == null)
            Text(
              '请输入有效份量',
              style: TextStyle(fontSize: 15, color: context.pal.secondary),
            )
          else
            NutritionSummary(kcal: entry['kcal'], protein: entry['protein']),
          const SizedBox(height: 16),
          FoodButton(
            '加入',
            entry == null
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    SheetController.of(context).close(entry);
                  },
            primary: true,
          ),
          FoodButton('取消', () => SheetController.of(context).close()),
        ],
      ),
    );
  }
}
