import 'package:flutter/widgets.dart';

import '../../../app/app_controller.dart';
import '../../../domain/format.dart';
import '../../../l10n/localized_text.dart';
import '../../../theme/theme.dart';
import '../../kit/menu.dart';
import '../../kit/sheet.dart';
import 'food_controls.dart';

/// 编辑「我的食物」里的一条：单个食物改名称和营养，常吃整餐只改名称。
/// 底部可以删除。保存和删除都在面板里做完，关闭时返回 true。
class MyFoodPanel extends StatefulWidget {
  const MyFoodPanel({super.key, required this.entry});
  final Map<String, dynamic> entry;
  @override
  State<MyFoodPanel> createState() => _MyFoodPanelState();
}

class _MyFoodPanelState extends State<MyFoodPanel> {
  late String _name = '${widget.entry['name']}';
  late String _kcal = fmt(widget.entry['kcal']);
  late String _protein = fmt(widget.entry['protein']);
  late String _carbs = fmt(widget.entry['carbs']);
  late String _fat = fmt(widget.entry['fat']);
  bool _busy = false;
  bool get _isMeal => widget.entry['items'] is List;

  num? _num(String s) => s.trim().isEmpty ? 0 : num.tryParse(s);

  Future<void> _save() async {
    if (_busy) return;
    final app = context.app, ctl = SheetController.of(context);
    final nums = [_kcal, _protein, _carbs, _fat].map(_num).toList();
    final name = _name.trim();
    if (name.isEmpty ||
        name.length > 60 ||
        (!_isMeal &&
            (_kcal.trim().isEmpty ||
                nums.any(
                  (n) => n == null || !n.isFinite || n < 0 || n >= 100000,
                )))) {
      app.toast.show('请填写名称、热量和蛋白，数值应为非负数');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      if (_isMeal) {
        await app.renameMyMeal('${widget.entry['id']}', name);
      } else {
        await app.saveMyFood(
          id: '${widget.entry['id']}',
          name: name,
          kcal: nums[0]!,
          protein: nums[1]!,
          carbs: nums[2]!,
          fat: nums[3]!,
        );
      }
      ctl.close(true);
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final app = context.app, ctl = SheetController.of(context);
    if (!await showConfirm(
      context,
      title: _isMeal ? '删除这个常吃整餐？' : '删除这个食物？',
      message: '已经记下的饮食不受影响。',
      confirm: '删除',
      danger: true,
    )) {
      return;
    }
    try {
      await app.deleteMyFood('${widget.entry['id']}');
      ctl.close(true);
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
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
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText(_isMeal ? '编辑常吃整餐' : '编辑我的食物', style: AppText.title(p)),
          const SizedBox(height: 16),
          FoodField('名称', _name, (v) => setState(() => _name = v)),
          if (!_isMeal) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FoodField(
                    '热量（千卡）',
                    _kcal,
                    (v) => setState(() => _kcal = v),
                    numeric: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FoodField(
                    '蛋白（g）',
                    _protein,
                    (v) => setState(() => _protein = v),
                    numeric: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FoodField(
                    '碳水（g）',
                    _carbs,
                    (v) => setState(() => _carbs = v),
                    numeric: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FoodField(
                    '脂肪（g）',
                    _fat,
                    (v) => setState(() => _fat = v),
                    numeric: true,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FoodButton('保存', _busy ? null : _save, primary: true),
          const SizedBox(height: 4),
          FoodButton('删除', _busy ? null : _delete, link: true),
        ],
      ),
    );
  }
}
