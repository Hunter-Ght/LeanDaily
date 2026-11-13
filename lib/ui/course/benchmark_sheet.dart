import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/benchmarks.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/grouped.dart';
import '../kit/number_field.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../kit/transitions.dart';
import '../kit/units_scope.dart';
import 'benchmark_rows.dart';

/// 做一次小测试：三项都可以留空跳过，数字只记「类型 + 数字」。
Future<void> openBenchmarkSheet(BuildContext context) =>
    showAppSheet<void>(context, (_) => const BenchmarkSheet());

class BenchmarkSheet extends StatefulWidget {
  const BenchmarkSheet({super.key});
  @override
  State<BenchmarkSheet> createState() => _BenchmarkSheetState();
}

class _BenchmarkSheetState extends State<BenchmarkSheet> {
  bool _ready = false;
  String _pushup = '', _plank = '', _pull = '';
  bool _knee = false;
  String _pullType = 'row';
  bool _busy = false;
  String _error = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final app = context.app, units = context.units;
    // 居家默认反向划船，健身房默认引体向上。
    _pullType = app.profile?['venue'] == 'gym' ? 'pullup' : 'row';
    // 今天已经测过：带出来修改（同一天只保存一次）。
    final today = app.benchmarkEntries
        .where((e) => e['date'] == app.today)
        .firstOrNull;
    if (today == null) return;
    final push = today['pushup'], plank = today['plank'], pull = today['pull'];
    if (push is Map) {
      _pushup = benchNumber(units, 'pushup', Map<String, dynamic>.from(push));
      _knee = push['knee'] == true;
    }
    if (plank is Map) {
      _plank = benchNumber(units, 'plank', Map<String, dynamic>.from(plank));
    }
    if (pull is Map) {
      _pullType = '${pull['type']}';
      _pull = benchNumber(units, 'pull', Map<String, dynamic>.from(pull));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final app = context.app, units = context.units;
    String? text(String v) => v.trim().isEmpty ? null : v.trim();
    final pull = text(_pull);
    Object? pullValue = pull;
    if (pull != null && _pullType == 'assisted') {
      final v = double.tryParse(pull);
      if (v == null || !v.isFinite) {
        setState(() => _error = '测试数字无效');
        return;
      }
      pullValue = units.loadToKg(v);
    }
    if (text(_pushup) == null && text(_plank) == null && pull == null) {
      setState(() => _error = '至少填一项，或直接关掉');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await app.saveBenchmark(
        date: app.today,
        pushup: text(_pushup),
        pushupKnee: _knee,
        plank: text(_plank),
        pullType: pull == null ? null : _pullType,
        pull: pullValue,
      );
      if (!mounted) return;
      app.haptics.saved();
      app.toast.show('已保存小测试');
      SheetController.of(context).close();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = AppController.message(e);
        });
      }
    }
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: on,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? p.primary : p.fill2,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                widthFactor: 1,
                child: LText(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: on ? p.onPrimary : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(String value, ValueChanged<String> onChanged, String label) =>
      SizedBox(
        width: 90,
        child: SheetInput(
          value: value,
          onChanged: onChanged,
          label: label,
          placeholder: '–',
          numeric: true,
          align: TextAlign.right,
          size: 20,
          weight: FontWeight.w600,
        ),
      );

  Widget _unit(String unit) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: LText(
      unit,
      style: TextStyle(fontSize: 15, color: context.pal.secondary),
    ),
  );

  /// 上一次的数字，写在行的下方；没测过返回 null。
  String? _last(String item) {
    final units = context.units;
    final rows = benchmarkRows(context.app.benchmarkEntries);
    final row = rows.where((r) => r['item'] == item).firstOrNull;
    if (row == null) return null;
    final side = Map<String, dynamic>.from(
      (row['latest'] ?? row['first']) as Map,
    );
    final n = benchNumber(units, item, side), u = benchUnit(units, item, side);
    return '上次 $n $u';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, units = context.units;
    return AppSheet(
      title: '小测试',
      onSave: _busy ? null : _save,
      padding: EdgeInsets.only(
        top: 4,
        bottom: 28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LText(
              '做不了或不想测的项目直接留空，数字只用来和以前的自己比。',
              style: AppText.hint(p),
            ),
          ),
          const GroupHeader('俯卧撑'),
          GroupCard(
            children: [
              GroupRow(
                label: '最多连续做几个',
                sub: _last('pushup'),
                chevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(_pushup, (v) => _pushup = v, '俯卧撑'),
                    _unit('次'),
                  ],
                ),
              ),
              GroupRow(
                label: '做法',
                sub: '做不了标准的，选跪姿',
                chevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chip('标准', !_knee, () => setState(() => _knee = false)),
                    const SizedBox(width: 8),
                    _chip('跪姿', _knee, () => setState(() => _knee = true)),
                  ],
                ),
              ),
            ],
          ),
          const GroupHeader('平板支撑'),
          GroupCard(
            children: [
              GroupRow(
                label: '最久能撑多少秒',
                sub: _last('plank'),
                chevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(_plank, (v) => _plank = v, '平板支撑'),
                    _unit('秒'),
                  ],
                ),
              ),
            ],
          ),
          const GroupHeader('拉的动作'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final t in benchmarkPullTypes)
                  _chip(
                    benchmarkPullLabels[t]!,
                    _pullType == t,
                    () => setState(() => _pullType = t),
                  ),
              ],
            ),
          ),
          GroupCard(
            children: [
              GroupRow(
                label: _pullType == 'assisted' ? '配重' : '最多做几次',
                sub: _last('pull'),
                chevron: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(_pull, (v) => _pull = v, '拉的动作'),
                    _unit(_pullType == 'assisted' ? units.weightUnit : '次'),
                  ],
                ),
              ),
            ],
          ),
          Reveal(
            visible: _error.isNotEmpty,
            child: _error.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: LText(
                      _error,
                      style: TextStyle(fontSize: 13, color: p.err),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
