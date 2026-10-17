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
  // 默认按一个人通常吃的一份（一碗、一个、一杯）算，不先摆出 100 克。
  late bool _grams = widget.food['unit'] == '100g';
  late String _quantity = _grams ? '100' : '1';
  num get _perUnit => widget.food['gramsPerUnit'] as num;
  bool get _recent => widget.food['recent'] == true;

  /// 克数模式一次加减 10 g，份数模式一次加减半份。
  num get _step => _grams ? 10 : .5;
  num get _min => _grams ? 10 : .5;

  void _nudge(num delta) => setState(
    () => _quantity = fmt(
      ((num.tryParse(_quantity) ?? 0) + delta).clamp(_min, 9999),
    ),
  );

  void _switchMode() {
    final n = num.tryParse(_quantity);
    setState(() {
      if (_grams) {
        _grams = false;
        _quantity = fmt(n == null || n <= 0 ? 1 : _round2(n / _perUnit));
      } else {
        _grams = true;
        _quantity = fmt(n == null || n <= 0 ? _perUnit : _round2(n * _perUnit));
      }
    });
  }

  static num _round2(num n) => (n * 100).round() / 100;

  Map<String, dynamic>? get _entry {
    final n = num.tryParse(_quantity);
    if (n == null || !n.isFinite || n <= 0) return null;
    try {
      final entry = entryFor(
        widget.food,
        grams: _grams ? n : null,
        units: _grams ? null : n,
      );
      if (_recent) {
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
              FoodButton('－', () => _nudge(-_step)),
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
              FoodButton('＋', () => _nudge(_step)),
            ],
          ),
          if (!_recent) ...[
            const SizedBox(height: 8),
            Text(
              _hint(),
              style: TextStyle(fontSize: 13, color: context.pal.secondary),
            ),
            if (!_grams) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, q) in const [.5, 1, 1.5, 2].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: FoodButton(
                        '${fmt(q)}${widget.food['unit']}',
                        () => setState(() => _quantity = fmt(q)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            FoodButton(
              _grams ? '改用份数（${widget.food['unit']}）' : '改用克数',
              _switchMode,
            ),
          ],
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

  /// 份数模式提示一份有多重；克数模式提示大约相当于几份。
  String _hint() {
    final unit = '${widget.food['unit']}';
    if (_grams) {
      final n = num.tryParse(_quantity);
      if (n == null || n <= 0 || unit == '100g') return '';
      return '约 ${fmt(_round2(n / _perUnit))} $unit';
    }
    final n = num.tryParse(_quantity);
    final total = n == null || n <= 0
        ? ''
        : '，共约 ${fmt(_round2(n * _perUnit))} g';
    return '1 $unit ≈ ${fmt(_perUnit)} g$total';
  }
}
