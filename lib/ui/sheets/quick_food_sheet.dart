import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart' show openMealSheet;
import '../../domain/calendar.dart';
import '../../domain/foods.dart';
import '../../domain/records.dart' as records;
import '../../domain/format.dart' hide shiftDate;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
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

  /// “常见一餐”按哪一餐筛选：空 = 跟随底部选的餐次；也可选“全部”。
  String _mealFilter = '';
  String get _shownMeal => _mealFilter.isEmpty ? _meal : _mealFilter;
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
          final originalName = '${entry['name']}';
          final name = isProteinPowder(originalName) ? '蛋白粉' : originalName;
          counts[name] = (counts[name] ?? 0) + 1;
          entries.putIfAbsent(name, () => entry);
        }
      }
    }
    final catalogue = {
      for (final food in foods.items)
        if (!isProteinPowder(food['name'])) '${food['name']}': food,
      '蛋白粉': _powder,
    };
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
    child: LText(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: context.pal.text,
      ),
    ),
  );
  Map<String, dynamic> get _powder => proteinPowderFood(
    (context.app.plan['protein'] as Map?)?['powder'] as Map?,
  );

  List<Map<String, dynamic>> _search(Foods foods) {
    final messages = AppMessages.of(context);
    return {
      for (final food in [
        ...foods.search(_query).where((f) => !isProteinPowder(f['name'])),
        ...messages.foodSearch([
          _powder,
          ...foods.items.where((f) => !isProteinPowder(f['name'])),
        ], _query),
      ])
        food['name']: food,
    }.values.toList();
  }

  Widget _food(Map<String, dynamic> food) {
    final serving = entryFor(food, units: 1);
    final portion = food['recent'] == true
        ? '1 份（上次份量）'
        : '1 ${food['unit']}（${fmt(food['gramsPerUnit'])} g）';
    return Container(
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
                LText(
                  '${food['name']}',
                  style: TextStyle(fontSize: 16, color: context.pal.text),
                ),
                const SizedBox(height: 4),
                LText(
                  '$portion · ${fmt(serving['kcal'])} 千卡 / 蛋白 ${fmt(serving['protein'])} g',
                  style: TextStyle(fontSize: 12, color: context.pal.secondary),
                ),
              ],
            ),
          ),
          Semantics(
            label: AppMessages.of(context).text('选择 ${food['name']}'),
            button: true,
            child: FoodButton('＋', () => _portion(food)),
          ),
        ],
      ),
    );
  }

  /// 记饮食入口的三个并排大按钮：AI 拍照、搜食物、手动输入。
  Widget _modeTile(
    String icon,
    String label,
    String caption,
    bool selected,
    VoidCallback onTap,
  ) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.tintSoft : p.seg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 22, color: selected ? p.tint : p.text),
              const SizedBox(height: 6),
              LText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? p.tint : p.text,
                ),
              ),
              const SizedBox(height: 2),
              LText(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: p.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasPowder =>
      ((context.app.plan['protein'] as Map?)?['powder'] as Map?) != null;

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
              label: AppMessages.of(context).text(label),
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
                  child: LText(
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
          title: '记饮食',
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
                    LText(
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
              Row(
                children: [
                  Expanded(
                    child: _modeTile(
                      'camera',
                      'AI拍照识别',
                      _configured ? '拍张照自动算' : '未配置，可存照片',
                      false,
                      () {
                        if (!_saving) _openPhoto();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeTile(
                      'search',
                      '搜食物',
                      '常吃、常见一餐',
                      _tab == '搜食物',
                      () {
                        if (!_saving) setState(() => _tab = '搜食物');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeTile(
                      'edit',
                      '手动输入',
                      '自己填营养',
                      _tab == '手动输入',
                      () {
                        if (!_saving) setState(() => _tab = '手动输入');
                      },
                    ),
                  ),
                ],
              ),
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
                        if (_search(foods).isEmpty)
                          LText(
                            '没有找到，试试手动输入',
                            style: TextStyle(color: context.pal.secondary),
                          ),
                        for (final food in _search(foods)) _food(food),
                      ] else ...[
                        _heading('常吃'),
                        if (frequent.isEmpty && !_hasPowder)
                          LText(
                            '最近 14 天还没有记录常吃的食物',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.pal.secondary,
                            ),
                          ),
                        if (_hasPowder) _food(_powder),
                        // 蛋白粉已单独列在最前；常吃只留最常记的 4 项，
                        // 把屏幕留给下面的“常见一餐”。
                        for (final food
                            in frequent
                                .where(
                                  (f) =>
                                      !_hasPowder ||
                                      !isProteinPowder(f['name']),
                                )
                                .take(4))
                          _food(food),
                        _heading('常见一餐'),
                        _segments(
                          const ['早餐', '午餐', '晚餐', '加餐', '全部'],
                          _mealFilter.isEmpty ? _meal : _mealFilter,
                          (v) => setState(() => _mealFilter = v),
                        ),
                        const SizedBox(height: 4),
                        for (final food in foods.typicalMeals(
                          _shownMeal == '全部' ? _meal : _shownMeal,
                          onlyThisMeal: _shownMeal != '全部',
                        ))
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
                      const SizedBox(height: 12),
                      FoodButton(
                        _more ? '收起更多' : '更多',
                        () => setState(() => _more = !_more),
                      ),
                      const SizedBox(height: 8),
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
            ],
          ),
        ),
      );
    },
  );
}
