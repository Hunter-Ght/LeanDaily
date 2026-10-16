import 'package:flutter/widgets.dart';

import '../../../domain/format.dart';
import '../../../domain/guide.dart';
import '../../../theme/theme.dart';
import '../../kit/form.dart';

/// 单个动作的编辑表单。只改传入的草稿，不触碰已保存计划。
class ExerciseEditor extends StatelessWidget {
  const ExerciseEditor({super.key, required this.exercise, required this.onChanged, required this.onMove, required this.onRemove});
  final Map<String, dynamic> exercise;
  final VoidCallback onChanged, onRemove;
  final ValueChanged<int> onMove;
  void _set(String key, Object? value) { exercise[key] = value; onChanged(); }
  Widget _number(String label, String key, {bool enabled = true}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(label, style: const TextStyle(fontSize: 12)),
    FormInput(label: '$label·${exercise['name']}', value: jsString(exercise[key] ?? 0), numeric: true, filled: true, enabled: enabled, align: TextAlign.center,
      onChanged: (s) { final n = jsNumber(s); if (n.isFinite) _set(key, key == 'rest' ? n.clamp(0, 300) : n); }),
  ]));
  Widget _flag(String label, String key) => FormCheck(label: label, value: key == 'unit' ? exercise[key] == 'sec' : exercise[key] == true, onChanged: (v) => _set(key, key == 'unit' ? (v ? 'sec' : 'reps') : v));
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ladder = jsTruthy(exercise['ladder']);
    final auto = guideFor({'name': exercise['name']});
    return Container(padding: const EdgeInsets.only(top: 10, bottom: 4), decoration: BoxDecoration(border: Border(top: BorderSide(color: p.sep, width: .5))), child: DefaultTextStyle.merge(style: TextStyle(color: p.secondary), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: FormInput(label: '动作名', value: '${exercise['name']}', plain: true, enabled: !ladder, maxLength: 40, align: TextAlign.left, onChanged: (s) => _set('name', s))),
        SizedBox(width: 44, child: FormButton('↑', ink: true, semanticLabel: '上移', onTap: () => onMove(-1))), const SizedBox(width: 2),
        SizedBox(width: 44, child: FormButton('↓', ink: true, semanticLabel: '下移', onTap: () => onMove(1))), const SizedBox(width: 2),
        SizedBox(width: 44, child: FormButton('✕', ink: true, icon: 'close', semanticLabel: '删除', onTap: onRemove, danger: true)),
      ]),
      if (ladder) const FormHint('阶梯动作：名称和次数跟随下面的「进阶阶段」'),
      const SizedBox(height: 8),
      Row(spacing: 6, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [const Text('部位', style: TextStyle(fontSize: 12)), FormChoice(label: '部位', width: 60, filled: true, value: '${exercise['part']}', options: const {'胸': '胸', '背': '背', '腿': '腿', '肩': '肩', '手臂': '手臂', '核心': '核心', '全身': '全身', '有氧': '有氧'}, onChanged: (s) => _set('part', s))])),
        _number('组数', 'sets'), _number('最少', 'min', enabled: !ladder), _number('最多', 'max', enabled: !ladder), _number('kg', 'weight'),
      ]),
      Row(children: [const Expanded(child: Text('示范图', style: TextStyle(fontSize: 14))), FormChoice(label: '示范图', value: '${exercise['img'] ?? ''}', width: 220, options: {'': auto == null ? '无' : '自动：${auto['label']}', for (final o in LIB_OPTIONS) o['key']!: o['label']!}, onChanged: (s) => _set('img', s))]),
      Wrap(spacing: 8, children: [_flag('每侧', 'side'), _flag('按秒', 'unit'), _flag('可选', 'optional'), _flag('精简版必做', 'core'), _flag('器械（要填重量）', 'machine')]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _number('组间休息（秒，0 用默认）', 'rest'), const SizedBox(width: 6),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('没有时可替换成（逗号分隔）', style: TextStyle(fontSize: 12)),
          FormInput(label: '没有时可替换成（逗号分隔）', filled: true, value: ((exercise['alts'] as List?) ?? []).map((a) => (a as Map)['name']).join('，'), align: TextAlign.left, onChanged: (s) {
            final old = {for (final a in (exercise['alts'] as List?) ?? []) (a as Map)['name']: a};
            _set('alts', s.split(RegExp('[,，、/]')).map((n) => n.trim()).where((n) => n.isNotEmpty).map((n) => old[n] ?? {'name': n}).toList());
          }),
        ])),
      ]),
    ])));
  }
}
