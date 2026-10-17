import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart' show openMealSheet;
import '../../domain/calendar.dart';
import '../../domain/foods.dart';
import '../../domain/records.dart' as records;
import '../../domain/format.dart' hide shiftDate;
import '../../theme/theme.dart';
import '../kit/menu.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'food/food_controls.dart';
import 'food/portion_panel.dart';
import 'food/nutrition_summary.dart';

/// Direct entry point for consumers that do not depend on the shared router.
Future<void> openQuickFood(
  BuildContext context, {
  String? date,
  String? meal,
}) =>
    showAppSheet<void>(context, (_) => QuickFoodSheet(date: date, meal: meal));

class QuickFoodSheet extends StatefulWidget {
  const QuickFoodSheet({super.key, this.date, this.meal});
  final String? date, meal;
  @override
  State<QuickFoodSheet> createState() => _QuickFoodSheetState();
}

class _QuickFoodSheetState extends State<QuickFoodSheet> {
  final _items = <Map<String, dynamic>>[];
  String _tab = '搜食物', _query = '', _meal = '', _time = '';
  String _name = '', _kcal = '', _protein = '', _carbs = '', _fat = '';
  bool _more = false,
      _configured = false,
      _saving = false,
      _initialized = false;
  late String _date;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _date = widget.date ?? context.app.date;
    _meal = widget.meal ?? '';
    _load();
  }

  Future<void> _load() async {
    final app = context.app;
    try {
      final clock = await app.native.clock('${app.settings.value['tz']}');
      final secret = await app.native.secretsGet();
      if (!mounted) return;
      final parts = clock.now.split(':');
      final minutes =
          (int.tryParse(parts.first) ?? 0) * 60 +
          (int.tryParse(parts.last) ?? 0);
      setState(() {
        _time = clock.now;
        if (_meal.isEmpty) {
          _meal = minutes < 630
              ? '早餐'
              : minutes < 870
              ? '午餐'
              : minutes >= 1020 && minutes < 1260
              ? '晚餐'
              : '加餐';
        }
        _configured =
            secret.modelKey.trim().isNotEmpty &&
            '${app.settings.value['model'] ?? ''}'.trim().isNotEmpty &&
            '${app.settings.value['baseUrl'] ?? ''}'.trim().isNotEmpty;
      });
    } on Object catch (e) {
      if (mounted) app.toast.show(AppController.message(e));
    }
  }

  num total(String key) => jsNumber(records.sumItems(_items)[key]);
  String get _summary =>
      '${fmt(total('kcal'))} 千卡 / 蛋白 ${fmt(total('protein'))} g';

  Future<void> _save() async {
    if (_saving || _items.isEmpty || _meal.isEmpty) return;
    final app = context.app, ctl = SheetController.of(context);
    final summary = _summary, meal = _meal;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await app.repo.saveMeal(
        date: _date,
        meal: _meal,
        time: _time,
        source: '手动填写',
        items: _items.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      app.haptics.saved();
      app.toast.show('已记入 $meal：$summary');
      if (mounted) ctl.close();
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _portion(Map<String, dynamic> food) async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final entry = await showSheetPanel<Map<String, dynamic>>(
      context,
      (_) => FoodPortionPanel(food: food),
    );
    if (mounted && entry != null && !_saving) _add(entry);
  }

  void _add(Map<String, dynamic> entry) {
    if (_items.length >= 40) {
      context.app.toast.show('最多 40 项食物');
      return;
    }
    setState(() => _items.add(records.cleanItems([entry]).single));
    context.app.haptics.selection();
  }

  void _openPhoto() {
    if (_saving) return;
    context.app.setDate(_date);
    openMealSheet(context, preset: {'meal': _meal, 'time': _time});
  }

  void _manual() {
    if (_saving) return;
    if (_items.length >= 40) {
      context.app.toast.show('最多 40 项食物');
      return;
    }
    final values = [_kcal, _protein, _carbs, _fat];
    final nums = values
        .map((s) => s.trim().isEmpty ? 0 : num.tryParse(s))
        .toList();
    if (_name.trim().isEmpty ||
        _name.trim().length > 60 ||
        _kcal.trim().isEmpty ||
        _protein.trim().isEmpty ||
        nums.any((n) => n == null || !n.isFinite || n < 0 || n >= 100000)) {
      context.app.toast.show('请填写名称、热量和蛋白，数值应为非负数');
      return;
    }
    _add({
      'name': _name.trim(),
      'portion': '1 份',
      for (final (i, k) in ['kcal', 'protein', 'carbs', 'fat'].indexed)
        k: nums[i],
    });
    setState(() {
      _name = _kcal = _protein = _carbs = _fat = '';
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  List<Map<String, dynamic>> _frequent(Foods foods) {
    final counts = <String, int>{};
    final entries = <String, Map<String, dynamic>>{};
    final app = context.app;
    for (var i = 0; i < 14; i++) {
      for (final meal in jsonRows(
        app.repo.meals(shiftDate(_date, -i))['meals'],
      )) {
        for (final entry in jsonRows(meal['items'])) {
          final name = '${entry['name']}';
          counts[name] = (counts[name] ?? 0) + 1;
          entries.putIfAbsent(name, () => entry);
        }
      }
    }
    final catalogue = {for (final food in foods.items) '${food['name']}': food};
    final ranked = <Map<String, dynamic>>[
      for (final e in entries.entries)
        catalogue[e.key] ??
            {
              'name': e.key, 'unit': '份', 'gramsPerUnit': 100,
              // Unknown weights cannot truthfully be shown per 100 g. Reuse one
              // previously recorded portion, keeping its nutrition unchanged.
              'recent': true,
              for (final k in ['kcal', 'protein', 'carbs', 'fat'])
                '${k}100': jsNumber(e.value[k]),
            },
    ];
    ranked.sort((a, b) => counts[b['name']]!.compareTo(counts[a['name']]!));
    return ranked.take(12).toList();
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: context.pal.text,
      ),
    ),
  );
  Widget _food(Map<String, dynamic> food) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.pal.sep, width: .5)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${food['name']}',
                style: TextStyle(fontSize: 16, color: context.pal.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${food['recent'] == true ? '每份' : '每 100g'} 约 ${fmt(food['kcal100'])} 千卡 / 蛋白 ${fmt(food['protein100'])} g',
                style: TextStyle(fontSize: 12, color: context.pal.secondary),
              ),
            ],
          ),
        ),
        Semantics(
          label: '选择 ${food['name']}',
          button: true,
          child: FoodButton('＋', () => _portion(food)),
        ),
      ],
    ),
  );

  Widget _segments(
    List<String> labels,
    String value,
    ValueChanged<String> change,
  ) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: context.pal.seg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              selected: label == value,
              child: Pressable(
                onTap: () => change(label),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: label == value ? context.pal.segOn : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.pal.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.app,
    builder: (context, _) {
      final foods = context.app.foods;
      final frequent = foods == null
          ? <Map<String, dynamic>>[]
          : _frequent(foods);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AppSheet(
          title: '快速记饮食',
          padding: const EdgeInsets.all(16),
          confirmClose: () async =>
              !_saving &&
              (_items.isEmpty ||
                  await showConfirm(
                    context,
                    title: '放弃这次填写？',
                    message: '已选食物还没有记录。',
                    confirm: '放弃',
                  )),
          footer: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: context.pal.card,
              border: Border(
                top: BorderSide(color: context.pal.sep, width: .5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '已选 ${_items.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.pal.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NutritionSummary(
                        kcal: total('kcal'),
                        protein: total('protein'),
                      ),
                    ),
                  ],
                ),
                Reveal(
                  visible: _items.isNotEmpty,
                  child: SizedBox(
                    height: 54,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: MotionList(
                        axis: Axis.horizontal,
                        children: [
                          for (final item in _items)
                            Padding(
                              key: ObjectKey(item),
                              padding: const EdgeInsets.only(right: 8),
                              child: FoodButton(
                                '${item['name']} × ${item['portion']}  ×',
                                _saving
                                    ? null
                                    : () => setState(() => _items.remove(item)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _segments(['早餐', '午餐', '晚餐', '加餐'], _meal, (v) {
                  if (!_saving) setState(() => _meal = v);
                }),
                const SizedBox(height: 10),
                FoodButton(
                  _saving ? '记录中…' : '记录',
                  !_saving && _items.isNotEmpty && _meal.isNotEmpty
                      ? _save
                      : null,
                  primary: true,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _segments(['搜食物', '手动输入', if (_configured) '拍照'], _tab, (v) {
                if (_saving) return;
                if (v == '拍照') {
                  _openPhoto();
                } else {
                  setState(() => _tab = v);
                }
              }),
              const SizedBox(height: 16),
              PushSwitcher(
                child: Column(
                  key: ValueKey('$_tab:${foods == null}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_tab == '搜食物') ...[
                      FoodField(
                        '搜索食物',
                        _query,
                        (v) => setState(() => _query = v),
                      ),
                      if (foods == null)
                        _heading('食物库加载中…')
                      else if (_query.trim().isNotEmpty) ...[
                        _heading('搜索结果'),
                        if (foods.search(_query).isEmpty)
                          Text(
                            '没有找到，试试手动输入',
                            style: TextStyle(color: context.pal.secondary),
                          ),
                        for (final food in foods.search(_query)) _food(food),
                      ] else ...[
                        _heading('常吃'),
                        if (frequent.isEmpty)
                          Text(
                            '最近 14 天还没有记录常吃的食物',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.pal.secondary,
                            ),
                          ),
                        for (final food in frequent) _food(food),
                        _heading('高蛋白推荐'),
                        for (final food in foods.proteinRanking().take(12))
                          _food(food),
                      ],
                    ] else if (_tab == '手动输入') ...[
                      FoodField('名称', _name, (v) => setState(() => _name = v)),
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
                      FoodButton(
                        _more ? '收起更多' : '更多',
                        () => setState(() => _more = !_more),
                      ),
                      Reveal(
                        visible: _more,
                        child: _more
                            ? Row(
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
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 10),
                      FoodButton('加入', _manual),
                    ],
                  ],
                ),
              ),
              if (!_configured)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '在 我的 → 高级 里配置大模型后可用',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.pal.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
