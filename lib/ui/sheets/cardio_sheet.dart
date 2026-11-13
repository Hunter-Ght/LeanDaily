import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../core/haptics.dart';
import '../../domain/cardio.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/grouped.dart';
import '../kit/number_field.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../kit/transitions.dart';
import '../kit/units_scope.dart';
import 'edit_set_sheet.dart' show SetFeedbackChip;
import 'train/controls.dart' show SheetButton;

/// 记一次有氧到 [date]；传 [entry] 就是修改这一条。
Future<void> openCardioSheet(
  BuildContext context, {
  required String date,
  Map<String, dynamic>? entry,
}) => showAppSheet<void>(context, (_) => CardioSheet(date: date, entry: entry));

/// 极简的有氧记录：类型、时长、可选距离、可选吃力程度。不估算热量。
class CardioSheet extends StatefulWidget {
  const CardioSheet({super.key, required this.date, this.entry});
  final String date;
  final Map<String, dynamic>? entry;
  @override
  State<CardioSheet> createState() => _CardioSheetState();
}

class _CardioSheetState extends State<CardioSheet> {
  String? _type;
  late String _minutes;
  String _distance = '';
  String _effort = '';
  bool _busy = false;
  String _error = '';

  bool get _editing => widget.entry != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_type != null) return;
    final app = context.app, units = context.units, e = widget.entry;
    final last = app.lastCardio;
    _type = '${e?['type'] ?? last.type}';
    _minutes = '${e?['minutes'] ?? last.minutes}';
    if (e?['distanceKm'] is num) {
      _distance = units.distance(e!['distanceKm'] as num);
    }
    _effort = '${e?['effort'] ?? ''}';
  }

  /// 5 分钟一档：从 23 加是 25，减是 20。
  void _step(int direction) {
    final now = int.tryParse(_minutes) ?? cardioDefaultMinutes;
    final next = direction > 0
        ? (now ~/ 5 + 1) * 5
        : (now % 5 == 0 ? now - 5 : now ~/ 5 * 5);
    final clamped = next.clamp(1, cardioMaxMinutes);
    if (clamped == now) return;
    HapticScope.of(context)?.selection();
    setState(() => _minutes = '$clamped');
  }

  Future<void> _save() async {
    if (_busy) return;
    final units = context.units, app = context.app;
    final minutes = int.tryParse(_minutes.trim());
    if (minutes == null || minutes < 1 || minutes > cardioMaxMinutes) {
      setState(() => _error = '时长应为 1–600 分钟');
      return;
    }
    num? km;
    if (_distance.trim().isNotEmpty) {
      final value = double.tryParse(_distance.trim());
      if (value == null || !value.isFinite || value <= 0) {
        setState(() => _error = '距离无效');
        return;
      }
      km = units.distanceToKm(value);
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await app.saveCardio(
        date: widget.date,
        type: _type!,
        minutes: minutes,
        distanceKm: km,
        effort: _effort.isEmpty ? null : _effort,
        id: widget.entry?['id'] as String?,
      );
      if (!mounted) return;
      app.haptics.saved();
      app.toast.show(_editing ? '已改好' : '已记录有氧 $minutes 分钟');
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

  Widget _stepButton(int direction) => Semantics(
    button: true,
    excludeSemantics: true,
    label: AppMessages.of(context).text(direction < 0 ? '减少时长' : '增加时长'),
    child: Pressable(
      onTap: () => _step(direction),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.pal.card,
          shape: BoxShape.circle,
        ),
        child: LText(
          direction < 0 ? '−' : '+',
          style: TextStyle(fontSize: 28, height: 1.1, color: context.pal.text),
        ),
      ),
    ),
  );

  /// 类型胶囊：按文字宽度，选中为墨色。
  Widget _typeChip(String id) {
    final p = context.pal, on = _type == id;
    final label = cardioTypeLabels[id]!;
    return Semantics(
      button: true,
      selected: on,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: () => setState(() => _type = id),
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

  @override
  Widget build(BuildContext context) {
    final p = context.pal, units = context.units;
    return AppSheet(
      title: _editing ? '改有氧' : '记有氧',
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [for (final id in cardioTypes) _typeChip(id)],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.fill,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _stepButton(-1),
                Expanded(
                  child: Column(
                    children: [
                      DefaultTextStyle(
                        style: AppText.num(p, 56),
                        child: SheetInput(
                          value: _minutes,
                          onChanged: (v) => _minutes = v,
                          label: '时长 分钟',
                          numeric: true,
                          size: 56,
                          weight: FontWeight.w700,
                          align: TextAlign.center,
                        ),
                      ),
                      LText(
                        '分钟',
                        style: TextStyle(fontSize: 15, color: p.secondary),
                      ),
                    ],
                  ),
                ),
                _stepButton(1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GroupScope(
            child: GroupCard(
              children: [
                GroupRow(
                  label: '距离（可选）',
                  chevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 90,
                        child: SheetInput(
                          value: _distance,
                          onChanged: (v) => _distance = v,
                          label: '距离 ${units.distanceUnit}',
                          placeholder: '0.0',
                          numeric: true,
                          align: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        units.distanceUnit,
                        style: TextStyle(fontSize: 15, color: p.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LText('吃力程度（可选）', style: AppText.hint(p)),
          Row(
            children: [
              for (final (i, id) in cardioEfforts.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SetFeedbackChip(
                    label: cardioEffortLabels[id]!,
                    selected: _effort == id,
                    onTap: () =>
                        setState(() => _effort = _effort == id ? '' : id),
                  ),
                ),
              ],
            ],
          ),
          Reveal(
            visible: _error.isNotEmpty,
            child: _error.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LText(
                      _error,
                      style: TextStyle(fontSize: 13, color: p.err),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          SheetButton(
            _editing ? '保存修改' : '记录',
            _busy ? null : _save,
            primary: true,
          ),
        ],
      ),
    );
  }
}
