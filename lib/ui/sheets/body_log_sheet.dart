import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';
import '../../core/haptics.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/calendar.dart' as calendar;
import '../../domain/units.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/number_field.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../kit/units_scope.dart';

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
    final app = context.app, units = context.units;
    final recent = app.bodyEntries.lastOrNull;
    _weight = units.bodyWeight(
      (recent?['weightKg'] ?? app.profile?['weightKg'] ?? 70) as num,
      fixed: true,
    );
    final waist =
        app.bodyEntries.reversed
            .where((e) => e['waistCm'] != null)
            .firstOrNull?['waistCm'] ??
        app.profile?['waistCm'];
    _waist = waist == null
        ? ''
        : units.isImperial
        ? units.length(waist as num)
        : '$waist';
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _step(int direction) {
    final units = context.units;
    final next =
        ((double.tryParse(_weight!) ?? units.bodyWeightValue(70)) +
                direction * .1)
            .clamp(units.isImperial ? 67 : 30, units.isImperial ? 551 : 250)
            .toStringAsFixed(1);
    if (next == _weight) return;
    HapticScope.of(context)?.tick();
    setState(() => _weight = next);
  }

  Widget _stepButton(int direction) => Semantics(
    button: true,
    label: AppMessages.of(context).text(direction < 0 ? '减少体重' : '增加体重'),
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
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.pal.fill2,
            shape: BoxShape.circle,
          ),
          child: LText(
            direction < 0 ? '−' : '+',
            style: TextStyle(
              fontSize: 28,
              height: 1.1,
              color: context.pal.text,
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
      final units = context.units;
      final weight = double.tryParse(_weight!) ?? double.nan;
      final waist = _waistOpen && _waist.isNotEmpty
          ? double.tryParse(_waist) ?? double.nan
          : null;
      // 先在这里核对输入：只有体重/腰围真的超出范围，才显示范围提示。
      final waistCm = waist == null ? null : units.lengthToCm(waist);
      if (!weight.isFinite ||
          !units.bodyWeightInRange(weight) ||
          (waistCm != null &&
              (!waistCm.isFinite || waistCm < 20 || waistCm > 200))) {
        throw FormatException(
          units.isImperial
              ? '请输入 ${units.bodyWeightRangeText} 的体重，腰围为 ${units.lengthRangeText}'
              : '请输入 30–250 kg 的体重，腰围为 20–200 cm',
        );
      }
      final app = context.app;
      await app.recordBody(
        weightKg: units.bodyWeightToKg(weight),
        waistCm: waistCm,
        date: calendar.shiftDate(app.today, -_day),
        updateProfile: _update,
      );
      if (!mounted) return;
      app.haptics.saved();
      app.toast.show('已记录 ${weight.toStringAsFixed(1)} ${units.weightUnit}');
      SheetController.of(context).close();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : AppController.message(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal, units = context.units;
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: DefaultTextStyle(
                            style: AppText.num(p, 60),
                            child: SheetInput(
                              value: _weight!,
                              onChanged: (v) => _weight = v,
                              label: '体重 ${units.weightUnit}',
                              numeric: true,
                              size: 60,
                              weight: FontWeight.w700,
                              align: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      LText(
                        units.weightUnit,
                        style: TextStyle(fontSize: 17, color: p.secondary),
                      ),
                    ],
                  ),
                ),
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
                        label: '腰围 ${units.lengthUnit}',
                        trailing: SizedBox(
                          width: 110,
                          child: SheetInput(
                            value: _waist,
                            onChanged: (v) => _waist = v,
                            label: '腰围 ${units.lengthUnit}',
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
                        label: AppMessages.of(context).text(label),
                        child: Pressable(
                          haptic: _day != i,
                          onTap: () => setState(() => _day = i),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(
                              minWidth: 64,
                              minHeight: 44,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _day == i ? p.primary : p.fill2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: LText(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _day == i ? p.onPrimary : p.text,
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
                    child: LText(
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
                  chevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        units.bodyWeight(e['weightKg'] as num, fixed: true),
                        style: AppText.num(p, 22),
                      ),
                      Text(
                        ' ${units.weightUnit}',
                        style: TextStyle(fontSize: 13, color: p.secondary),
                      ),
                    ],
                  ),
                  sub: _delta(units, entries, e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _delta(
    Units units,
    List<Map<String, dynamic>> entries,
    Map<String, dynamic> entry,
  ) {
    final index = entries.indexOf(entry);
    if (index == 0) return null;
    final delta =
        (entry['weightKg'] as num) - (entries[index - 1]['weightKg'] as num);
    return delta == 0
        ? '较前一次 持平'
        : '较前一次 ${delta > 0 ? '↑' : '↓'}${units.bodyWeightDelta(delta, fixed: true)} ${units.weightUnit}';
  }
}
