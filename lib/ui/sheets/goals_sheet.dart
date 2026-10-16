import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import 'profile_sheet.dart';
import '../../domain/format.dart';
import '../../domain/goals.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/menu.dart';
import '../kit/sheet.dart';

class GoalsSheet extends StatefulWidget {
  const GoalsSheet({super.key});
  @override
  State<GoalsSheet> createState() => _GoalsSheetState();
}

class _GoalsSheetState extends State<GoalsSheet> {
  Map<String, String>? _values;
  late Map<String, String> _original;
  late bool _rest, _rest0;
  late int _sec, _sec0;
  bool _busy = false;
  String _error = '';
  bool get _dirty =>
      _values!.keys.any(
        (k) => jsNumber(_values![k]) != jsNumber(_original[k]),
      ) ||
      _rest != _rest0 ||
      _sec != _sec0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_values != null) return;
    final app = context.app;
    _values = {for (final e in app.goals.entries) e.key: '${e.value}'};
    _values!['weekDays'] =
        '${weekTargetFromHistory(app.goals['weekDays'] ?? 0, ((app.plan['schedule'] as Map?) ?? const {}).length, null)}';
    _original = Map.of(_values!);
    _rest = _rest0 = app.restEnabled;
    _sec = _sec0 = app.restSeconds;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final app = context.app;
      final next = <String, dynamic>{};
      for (final e in _values!.entries) {
        final n = jsNumber(e.value), min = e.key == 'kcal' ? 200 : 1;
        next[e.key] = n.isFinite ? (n + .5).floor().clamp(min, 1 << 30) : min;
      }
      if (app.profile != null) next['kcal'] = app.kcalGoal;
      await app.saveGoals(next);
      await app.saveRestPrefs({'enabled': _rest, 'sec': _sec});
      if (!_rest) app.rest.clear();
      if (mounted) SheetController.of(context).close();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheet(
    title: '设置',
    onSave: _save,
    saveEnabled: !_busy,
    confirmClose: () async =>
        !_busy &&
        (!_dirty ||
            await showConfirm(
              context,
              title: '已填的内容不会保存。',
              confirm: '放弃',
              danger: true,
            )),
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
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
        const GroupHeader('组间计时'),
        GroupCard(
          children: [
            GroupRow(
              label: '保存一组后倒计时',
              trailing: FormSwitch(
                label: '保存一组后倒计时',
                value: _rest,
                onChanged: (v) => setState(() => _rest = v),
              ),
            ),
            Reveal(
              visible: _rest,
              child: _rest
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: FormSegments(
                        labels: const ['90 秒', '2 分钟'],
                        selected: _sec == 90 ? 0 : 1,
                        onChanged: (i) =>
                            setState(() => _sec = i == 0 ? 90 : 120),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const GroupHeader('每天的目标'),
        GroupCard(
          children: [
            for (final e in const {
              'sets': '每天正式组',
              'meals': '每天几餐',
              'kcal': '每天千卡',
              'weekDays': '每周训练天数',
            }.entries)
              if (e.key == 'kcal' && context.app.profile != null)
                GroupRow(
                  label: '每天千卡',
                  value: '${context.app.kcalGoal}',
                  semanticLabel: '我的资料与目标',
                  onTap: () async {
                    await showAppSheet<void>(
                      context,
                      (_) => const ProfileSheet(),
                    );
                    if (mounted) setState(() {});
                  },
                )
              else
                GroupRow(
                  label: e.value,
                  trailing: FormInput(
                    label: e.value,
                    value: _values![e.key]!,
                    width: 94,
                    numeric: true,
                    onChanged: (v) => setState(() => _values![e.key] = v),
                  ),
                ),
          ],
        ),
        GroupFooter(
          '进度按这些目标计算。',
        ),
      ],
    ),
  );
}
