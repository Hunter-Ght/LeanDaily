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
import '../kit/segments.dart';
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
  bool _more = false, _saving = false, _initialized = false;
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
    openMealSheet(
      context,
      preset: {'date': _date, 'meal': _meal, 'time': _time},
    );
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

  Widget _heading(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 6),
    child: Row(
      children: [
        Expanded(child: LText(text, style: AppText.title(context.pal))),
        ?trailing,
      ],
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
    final p = context.pal;
    final serving = entryFor(food, units: 1);
    final portion = food['recent'] == true
        ? '1 份（上次份量）'
        : '1 ${food['unit']}（${fmt(food['gramsPerUnit'])} g）';
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sep, width: .5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  '${food['name']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 4),
                LText(
                  portion,
                  style: TextStyle(fontSize: 13, color: p.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(fmt(serving['kcal']), style: AppText.num(p, 18)),
                  const SizedBox(width: 3),
                  LText(
                    '千卡',
                    style: TextStyle(fontSize: 12, color: p.secondary),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: p.protein,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(fmt(serving['protein']), style: AppText.num(p, 15)),
                  const SizedBox(width: 2),
                  LText(
                    'g',
                    style: TextStyle(fontSize: 12, color: p.secondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 10),
          Semantics(
            label: AppMessages.of(context).text('选择 ${food['name']}'),
            button: true,
            child: FoodButton('＋', () => _portion(food)),
          ),
        ],
      ),
    );
  }

  /// 记饮食入口的三个并排按钮：AI 拍照、搜食物、手动输入。选中为墨色底。
  Widget _modeTile(
    String icon,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final p = context.pal;
    final fg = selected ? p.onPrimary : p.text;
    return Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? p.primary : p.fill2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 22, color: fg),
              const SizedBox(height: 8),
              LText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasPowder =>
      ((context.app.plan['protein'] as Map?)?['powder'] as Map?) != null;

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
                Reveal(
                  visible: _items.isNotEmpty,
                  child: SizedBox(
                    height: 60,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: MotionList(
                        axis: Axis.horizontal,
                        children: [
                          for (final item in _items)
                            Padding(
                              key: ObjectKey(item),
                              padding: const EdgeInsets.only(right: 8),
                              child: FoodChip(
                                '${item['name']} × ${item['portion']}',
                                _saving
                                    ? null
                                    : () => setState(() => _items.remove(item)),
                                removable: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LText(
                            '已选 ${_items.length}',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.pal.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          NutritionSummary(
                            kcal: total('kcal'),
                            protein: total('protein'),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 116,
                      child: FoodButton(
                        _saving ? '记录中…' : '记录',
                        !_saving && _items.isNotEmpty && _meal.isNotEmpty
                            ? _save
                            : null,
                        primary: true,
                      ),
                    ),
                  ],
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
                    child: _modeTile('camera', 'AI拍照识别', false, () {
                      if (!_saving) _openPhoto();
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeTile('search', '搜食物', _tab == '搜食物', () {
                      if (!_saving) setState(() => _tab = '搜食物');
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _modeTile('edit', '手动输入', _tab == '手动输入', () {
                      if (!_saving) setState(() => _tab = '手动输入');
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppSegments(
                labels: const ['早餐', '午餐', '晚餐', '加餐'],
                selected: const ['早餐', '午餐', '晚餐', '加餐'].indexOf(_meal),
                onChanged: (i) {
                  if (_saving) return;
                  setState(() {
                    _meal = const ['早餐', '午餐', '晚餐', '加餐'][i];
                    _mealFilter = '';
                  });
                },
              ),
              const SizedBox(height: 8),
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
                        _heading(
                          '常见一餐',
                          trailing: FoodChip(
                            '全部',
                            () => setState(
                              () =>
                                  _mealFilter = _mealFilter == '全部' ? '' : '全部',
                            ),
                            selected: _mealFilter == '全部',
                          ),
                        ),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FoodButton(
                          _more ? '收起更多' : '更多',
                          () => setState(() => _more = !_more),
                          link: true,
                        ),
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
