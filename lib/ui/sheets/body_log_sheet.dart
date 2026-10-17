import '../../core/haptics.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/calendar.dart' as calendar;
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/number_field.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';

Future<void> openBodyLog(BuildContext context) =>
    showAppSheet<void>(context, (_) => const BodyLogSheet());

class BodyLogSheet extends StatefulWidget {
  const BodyLogSheet({super.key});
  @override
  State<BodyLogSheet> createState() => _BodyLogSheetState();
}

class _BodyLogSheetState extends State<BodyLogSheet> {
  String? _weight;
  String _waist = '';
  bool _waistOpen = false, _update = true, _busy = false;
  int _day = 0;
  String _error = '';
  Timer? _repeat;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weight != null) return;
    final app = context.app;
    final recent = app.bodyEntries.lastOrNull;
    _weight = ((recent?['weightKg'] ?? app.profile?['weightKg'] ?? 70) as num)
        .toStringAsFixed(1);
    final waist =
        app.bodyEntries.reversed
            .where((e) => e['waistCm'] != null)
            .firstOrNull?['waistCm'] ??
        app.profile?['waistCm'];
    _waist = waist == null ? '' : '$waist';
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _step(int direction) {
    final next = ((double.tryParse(_weight!) ?? 70) + direction * .1)
        .clamp(30, 250)
        .toStringAsFixed(1);
    if (next == _weight) return;
    HapticScope.of(context)?.tick();
    setState(() => _weight = next);
  }

  Widget _stepButton(int direction) => Semantics(
    button: true,
    label: direction < 0 ? '减少体重' : '增加体重',
    child: GestureDetector(
      onLongPressStart: (_) {
        _step(direction);
        _repeat = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => _step(direction),
        );
      },
      onLongPressEnd: (_) => _repeat?.cancel(),
      onLongPressCancel: () => _repeat?.cancel(),
      child: Pressable(
        onTap: () => _step(direction),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: Text(
              direction < 0 ? '−' : '+',
              style: TextStyle(fontSize: 30, color: context.pal.tint),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final weight = double.tryParse(_weight!) ?? double.nan;
      final waist = _waistOpen && _waist.isNotEmpty
          ? double.tryParse(_waist) ?? double.nan
          : null;
      final app = context.app;
      await app.recordBody(
        weightKg: weight,
        waistCm: waist,
        date: calendar.shiftDate(app.today, -_day),
        updateProfile: _update,
      );
      if (!mounted) return;
      app.haptics.saved();
      app.toast.show('已记录 ${weight.toStringAsFixed(1)} kg');
      SheetController.of(context).close();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? '请输入 30–250 kg 的体重，腰围为 20–200 cm'
              : AppController.message(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final entries = app.bodyEntries;
    return AppSheet(
      title: '记体重',
      onSave: _save,
      saveEnabled: !_busy,
      padding: EdgeInsets.only(
        top: 16,
        bottom: 28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _stepButton(-1),
                Expanded(
                  child: SheetInput(
                    value: _weight!,
                    onChanged: (v) => _weight = v,
                    label: '体重 kg',
                    numeric: true,
                    size: 44,
                    weight: FontWeight.w700,
                    align: TextAlign.center,
                  ),
                ),
                Text('kg', style: AppText.hint(p)),
                _stepButton(1),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GroupCard(
            children: [
              GroupRow(
                label: '同时记腰围',
                value: _waistOpen ? '收起' : '可选',
                onTap: () => setState(() => _waistOpen = !_waistOpen),
              ),
              Reveal(
                visible: _waistOpen,
                child: _waistOpen
                    ? GroupRow(
                        label: '腰围 cm',
                        trailing: SizedBox(
                          width: 110,
                          child: SheetInput(
                            value: _waist,
                            onChanged: (v) => _waist = v,
                            label: '腰围 cm',
                            numeric: true,
                            align: TextAlign.right,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              GroupRow(
                label: '日期',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, label) in [(0, '今天'), (1, '昨天')])
                      Semantics(
                        button: true,
                        selected: _day == i,
                        label: label,
                        child: Pressable(
                          haptic: _day != i,
                          onTap: () => setState(() => _day = i),
                          child: Container(
                            alignment: Alignment.center,
                            width: 64,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _day == i ? p.tintSoft : p.fill2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                color: _day == i ? p.tint : p.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GroupRow(
                label: '同步到我的资料',
                trailing: FormSwitch(
                  label: '同步到我的资料',
                  value: _update,
                  onChanged: (v) => setState(() => _update = v),
                ),
              ),
            ],
          ),
          Reveal(
            visible: _error.isNotEmpty,
            child: _error.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error,
                      style: TextStyle(fontSize: 13, color: p.err),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const GroupHeader('最近记录'),
          GroupCard(
            children: [
              if (entries.isEmpty) const GroupRow(label: '还没有体重记录'),
              for (final e in entries.reversed.take(7))
                GroupRow(
                  label: '${e['date']}',
                  value: '${(e['weightKg'] as num).toStringAsFixed(1)} kg',
                  sub: _delta(entries, e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _delta(
    List<Map<String, dynamic>> entries,
    Map<String, dynamic> entry,
  ) {
    final index = entries.indexOf(entry);
    if (index == 0) return null;
    final delta =
        (entry['weightKg'] as num) - (entries[index - 1]['weightKg'] as num);
    return delta == 0
        ? '较前一次 持平'
        : '较前一次 ${delta > 0 ? '↑' : '↓'}${delta.abs().toStringAsFixed(1)} kg';
  }
}
