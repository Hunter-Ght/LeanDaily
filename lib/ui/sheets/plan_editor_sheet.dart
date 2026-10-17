import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/app_icon.dart';
import '../kit/menu.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../today/workout_title.dart';
import 'settings/exercise_editor.dart';
import 'settings/plan_library_section.dart';

class PlanEditorSheet extends StatefulWidget {
  const PlanEditorSheet({super.key});
  @override
  State<PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<PlanEditorSheet> {
  Map<String, dynamic>? _draft;
  late String _original;
  String _open = '', _venue = 'home', _error = '';
  bool _busy = false;
  Map<String, dynamic> get d => _draft!;
  Map get _workouts => d['workouts'] as Map;
  List get _order => d['order'] as List;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;
    _draft = ensurePlanShape(cloneJson(context.app.plan), context.app.today);
    _original = jsonEncode(d);
    _open = _order.isEmpty ? '' : '${_order.first}';
  }

  void _changed() => setState(() {});
  Future<bool> _beforePlanChange() async =>
      !_busy &&
      (jsonEncode(d) == _original ||
          await showConfirm(
            context,
            title: '已填的内容不会保存。',
            confirm: '放弃',
            danger: true,
          ));
  void _reloadPlan() => setState(() {
    _draft = ensurePlanShape(cloneJson(context.app.plan), context.app.today);
    _original = jsonEncode(d);
    _open = _order.isEmpty ? '' : '${_order.first}';
    _venue = 'home';
    _error = '';
  });
  List _list(String id) {
    final w = _workouts[id] as Map;
    return (_venue == 'gym' && w['gym'] is Map
            ? w['gym']['exercises']
            : w['exercises'])
        as List;
  }

  Widget _switch(String label, Map target, String key) => GroupRow(
    label: label,
    trailing: FormSwitch(
      label: label,
      value: target[key] == true,
      onChanged: (v) => setState(() => target[key] = v),
    ),
  );
  Widget _input(
    String label,
    Map target,
    String key, {
    bool numeric = true,
    double width = 94,
  }) => GroupRow(
    label: label,
    trailing: FormInput(
      label: label,
      value: jsString(target[key] ?? ''),
      numeric: numeric,
      width: width,
      maxLength: key == 'name' ? 20 : null,
      onChanged: (s) {
        final n = jsNumber(s);
        if (!numeric || n.isFinite) {
          setState(() => target[key] = numeric ? n : s);
        }
      },
    ),
  );
  Widget _time(String label, Map target, String key) => GroupRow(
    label: label,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FormInput(
          label: label,
          value: '${target[key]}',
          width: 94,
          onChanged: (s) => setState(() => target[key] = s),
        ),
        const SizedBox(width: 8),
        AppIcon('clock', size: 18, color: context.pal.text),
      ],
    ),
  );
  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final app = context.app;
    try {
      final next = normalizePlan(
        cloneJson(d),
        '${d['startDate'] == '' ? app.today : d['startDate']}',
      );
      if ((next['reminder'] as Map)['enabled'] == true) {
        try {
          await app.reminders.enablePlanReminders();
        } on Object catch (e) {
          app.toast.show(
            AppController.message(e),
            duration: const Duration(milliseconds: 3500),
          );
        }
      }
      await app.updatePlan(next);
      app.refreshRemindersNow();
      app.toast.show('计划已保存');
      if (mounted) SheetController.of(context).close();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!await showConfirm(
      context,
      title: '恢复成默认计划？',
      message: '会用最初的 3 天计划覆盖你改过的内容，第 1 周从今天重新开始。训练记录不受影响。',
      confirm: '恢复',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _draft = cloneJson(defaultPlan(context.app.today));
      _open = _order.isEmpty ? '' : '${_order.first}';
    });
  }

  Widget _workout(String id) {
    final w = _workouts[id] as Map;
    final list = _list(id);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      decoration: BoxDecoration(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: AppMessages.of(context).text(workoutTitle('${w['name']}')),
            child: Pressable(
              onTap: () => setState(() => _open = _open == id ? '' : id),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: LText(
                        workoutTitle('${w['name']}'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.pal.text,
                        ),
                      ),
                    ),
                    LText(
                      '${list.length} 个动作${_open == id ? ' ▾' : ' ▸'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.pal.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Reveal(
            visible: _open == id,
            child: _open == id
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          for (final i in [0, 1])
                            FormButton(
                              i == 0
                                  ? '居家版'
                                  : w['gym'] is Map
                                  ? '健身房版'
                                  : '+ 添加健身房版',
                              pill: true,
                              filled: _venue == (i == 0 ? 'home' : 'gym'),
                              onTap: () => setState(() {
                                if (i == 1 && w['gym'] is! Map) {
                                  w['gym'] = {
                                    'tag': '',
                                    'note': '',
                                    'exercises': <dynamic>[],
                                  };
                                }
                                _venue = i == 0 ? 'home' : 'gym';
                              }),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            LText(
                              '名称',
                              style: TextStyle(
                                fontSize: 17,
                                color: context.pal.text,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FormInput(
                                label: '名称',
                                value: '${w['name']}',
                                maxLength: 20,
                                onChanged: (v) => setState(() => w['name'] = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      MotionList(
                        children: [
                          for (final (i, ex) in list.indexed)
                            ExerciseEditor(
                              key: ValueKey('$id-$_venue-${ex['id']}'),
                              exercise: ex as Map<String, dynamic>,
                              onChanged: _changed,
                              onMove: (delta) {
                                final j = i + delta;
                                if (j < 0 || j >= list.length) return;
                                setState(() {
                                  final temp = list[j];
                                  list[j] = list[i];
                                  list[i] = temp;
                                });
                              },
                              onRemove: () async {
                                if (await showConfirm(
                                      context,
                                      title: '删除「${ex['name']}」？',
                                      confirm: '删除',
                                      danger: true,
                                    ) &&
                                    mounted) {
                                  setState(() => list.removeAt(i));
                                }
                              },
                            ),
                        ],
                      ),
                      FormButton(
                        '+ 添加动作',
                        plain: true,
                        onTap: () => setState(
                          () => list.add({
                            'id':
                                'x${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                            'name': '新动作',
                            'part': '胸',
                            'sets': 2,
                            'min': 8,
                            'max': 12,
                            'unit': 'reps',
                            'side': false,
                            'weight': 0,
                            'core': false,
                            'optional': false,
                            'gear': '',
                            'tip': '',
                          }),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = d['reminder'] as Map,
        schedule = d['schedule'] as Map,
        venues = d['venues'] as Map,
        protein = d['protein'] as Map; // ensurePlanShape 已保证这些字段存在
    return ListenableBuilder(
      listenable: context.app,
      builder: (context, _) => AppSheet(
        title:
            '正在编辑：${context.app.plans.where((p) => p['id'] == context.app.activePlanId).firstOrNull?['name'] ?? '当前方案'}',
        onSave: _save,
        saveEnabled: !_busy,
        confirmClose: () async =>
            !_busy &&
            (jsonEncode(d) == _original ||
                await showConfirm(
                  context,
                  title: '已填的内容不会保存。',
                  confirm: '放弃',
                  danger: true,
                )),
        padding: EdgeInsets.fromLTRB(
          0,
          12,
          0,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: _error.isNotEmpty,
              child: _error.isNotEmpty
                  ? FormHint(_error, error: true)
                  : const SizedBox.shrink(),
            ),
            PlanLibrarySection(
              beforeChange: _beforePlanChange,
              onPlanChanged: _reloadPlan,
            ),
            const GroupHeader('每日提醒'),
            GroupCard(
              children: [
                _switch('每天提醒我练什么', r, 'enabled'),
                Reveal(
                  visible: r['enabled'] == true,
                  child: r['enabled'] == true
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _time('提醒时间', r, 'time'),
                            _switch('没练的话 2 小时后再提醒', r, 'nudge'),
                            _switch('休息日也提醒（预告下次）', r, 'restDay'),
                            _switch('蛋白粉提醒', r, 'protein'),
                            Reveal(
                              visible: r['protein'] == true,
                              child: r['protein'] == true
                                  ? _time('蛋白粉时间', r, 'proteinTime')
                                  : const SizedBox.shrink(),
                            ),
                            const GroupFooter(
                              '提醒会按今天的计划写好内容，每次打开 APP 自动排好未来两周。超过两周不打开就不会再提醒。',
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const GroupHeader('每周安排'),
            GroupCard(
              children: [
                for (final day in [1, 2, 3, 4, 5, 6, 0])
                  GroupRow(
                    label: ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][day],
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FormChoice(
                          label:
                              '${['周日', '周一', '周二', '周三', '周四', '周五', '周六'][day]}安排',
                          value: '${schedule['$day'] ?? ''}',
                          options: {
                            '': '休息',
                            for (final id in _order)
                              '$id': workoutTitle('${_workouts[id]['name']}'),
                          },
                          width: 125,
                          onChanged: (v) => setState(() {
                            if (v.isEmpty) {
                              schedule.remove('$day');
                            } else {
                              schedule['$day'] = v;
                            }
                          }),
                        ),
                        if (schedule['$day'] != null &&
                            _workouts[schedule['$day']]?['gym'] is Map)
                          FormChoice(
                            label:
                                '${['周日', '周一', '周二', '周三', '周四', '周五', '周六'][day]}默认场地',
                            value: venues['$day'] == 'gym' ? 'gym' : 'home',
                            width: 102,
                            options: const {'home': '居家', 'gym': '健身房'},
                            onChanged: (v) => setState(() {
                              if (v == 'gym') {
                                venues['$day'] = v;
                              } else {
                                venues.remove('$day');
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const GroupHeader('训练内容'),
            GroupCard(children: [for (final id in _order) _workout('$id')]),
            for (final entry
                in (d['ladders'] is Map ? d['ladders'] as Map : const {})
                    .entries) ...[
              const GroupHeader('进阶阶段（俯卧撑）'),
              GroupCard(
                children: [
                  GroupRow(
                    label: '现在练',
                    trailing: FormChoice(
                      label: '现在练',
                      width: 230,
                      value: '${entry.value['stage']}',
                      options: {
                        for (final (i, step)
                            in (entry.value['steps'] as List).indexed)
                          '$i': '${i + 1}. ${step['name']}',
                      },
                      onChanged: (v) =>
                          setState(() => entry.value['stage'] = int.parse(v)),
                    ),
                  ),
                ],
              ),
              GroupFooter(
                '升级条件：${entry.value['steps'][entry.value['stage']]['hint']}。达到后「今日」页会提示你升级。',
              ),
            ],
            const GroupHeader('蛋白质'),
            GroupCard(
              children: [
                _input('每日目标 g', protein, 'goal'),
                _input('一勺蛋白粉 g', protein['powder'] as Map, 'grams'),
                _input('一勺含蛋白质 g', protein['powder'] as Map, 'protein'),
                _input('一勺热量 kcal', protein['powder'] as Map, 'kcal'),
              ],
            ),
            const GroupHeader('计划起点'),
            GroupCard(
              children: [
                _input('计划开始日', d, 'startDate', numeric: false, width: 150),
              ],
            ),
            const FormHint(
              '每个动作默认从 2 组起步。要不要加到 3 组，由「今日」页根据你的表现、出勤和恢复情况建议，你确认后才会改。',
            ),
            FormButton(
              '从今天重新算第 1 周',
              plain: true,
              onTap: () => setState(() => d['startDate'] = context.app.today),
            ),
            const SizedBox(height: 4),
            FormButton('恢复默认计划', plain: true, onTap: _reset, danger: true),
          ],
        ),
      ),
    );
  }
}

/// 打开编辑前补齐缺失的顶层字段（只补缺的，已有内容原样保留，不会换成默认计划）。
/// 旧版本或手动导入的计划可能缺少 reminder / venues / protein 等字段，强制转换会直接报错。
Map<String, dynamic> ensurePlanShape(Map<String, dynamic> plan, String today) {
  final base = defaultPlan(today);
  Map<String, dynamic> asMap(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  final workouts = plan['workouts'];
  plan['workouts'] = workouts is Map ? workouts : <String, dynamic>{};
  final order = plan['order'];
  final ids = (plan['workouts'] as Map).keys.map((k) => '$k').toSet();
  plan['order'] = [
    for (final id in (order is List ? order : ids.toList()))
      if (ids.contains('$id')) id,
  ];
  if (plan['schedule'] is! Map) plan['schedule'] = <String, dynamic>{};
  if (plan['venues'] is! Map) plan['venues'] = <String, dynamic>{};
  plan['reminder'] = {...asMap(base['reminder']), ...asMap(plan['reminder'])};
  final protein = asMap(plan['protein']);
  protein['goal'] ??= asMap(base['protein'])['goal'];
  protein['powder'] = {
    ...asMap(asMap(base['protein'])['powder']),
    ...asMap(protein['powder']),
  };
  plan['protein'] = protein;
  return plan;
}
