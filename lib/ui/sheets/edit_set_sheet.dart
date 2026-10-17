import '../../core/haptics.dart';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../data/state_doc.dart' show mark;
import '../../domain/format.dart' show fmt, jsNumber, jsTruthy;
import '../../domain/catalog.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';

class EditSetSheet extends StatefulWidget {
  const EditSetSheet({super.key, required this.set});
  final Map<String, dynamic> set;
  @override
  State<EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<EditSetSheet> {
  late final weight = TextEditingController(text: fmt(widget.set['w'] ?? ''));
  late final reps = TextEditingController(text: fmt(widget.set['reps'] ?? ''));
  final weightFocus = FocusNode(), repsFocus = FocusNode();
  late String type = '${widget.set['type'] ?? '正式'}';
  late int? remaining = widget.set['rpe'] == null
      ? null
      : (10 - jsNumber(widget.set['rpe'])).round().clamp(0, 3);
  late String flag = '${widget.set['flag'] ?? ''}';
  bool feedbackChanged = false;
  String error = '';
  bool saving = false;
  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    weightFocus.dispose();
    repsFocus.dispose();
    super.dispose();
  }

  void bump(bool isWeight, int delta) {
    final controller = isWeight ? weight : reps;
    final value = jsNumber(controller.text);
    final base = value.isFinite ? value : 0;
    final step = isWeight && base >= 20 ? 2.5 : 1;
    final next = math.max(
      isWeight ? 0 : 1,
      ((base + delta * step) * 10).round() / 10,
    );
    if (next == value) return;
    HapticScope.of(context)?.selection();
    controller.text = fmt(next);
  }

  Future<void> save() async {
    if (saving) return;
    final w = jsNumber(weight.text), r = jsNumber(reps.text);
    if (!w.isFinite ||
        !(w >= 0) ||
        !r.isFinite ||
        r != r.roundToDouble() ||
        r < 1) {
      setState(() => error = '重量或次数不对');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final app = context.app;
    try {
      await app.repo.mutate((state) {
        final date = '${widget.set['date'] ?? app.date}';
        final id = '${widget.set['id']}';
        final row = state['sets'][id];
        if (row == null || row['deleted'] == true || row['date'] != date) {
          throw StateError('记录不存在');
        }
        row.addAll(<String, dynamic>{
          'w': w,
          'reps': r,
          'type': type,
          'rpe': feedbackChanged
              ? (remaining == null ? null : 10 - remaining!)
              : widget.set['rpe'],
        });
        if (flag.isEmpty) {
          row.remove('flag');
        } else {
          row['flag'] = flag;
        }
        mark(state, 'sets', id);
        mark(state, 'days', date);
      }, incrementRevision: true);
      app.haptics.saved();
      app.toast.show('已改好');
      if (mounted) SheetController.of(context).close();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppController.message(e);
        });
      }
    }
  }

  Widget step(bool isWeight) {
    final p = context.pal;
    final label = isWeight ? '重量' : '次数';
    final exercise = catalog()['${widget.set['ex']}'];
    final bodyweight =
        exercise != null &&
        !jsTruthy(exercise['machine']) &&
        jsNumber(exercise['weight']) == 0;
    final fieldLabel = isWeight
        ? (bodyweight ? '附加负重 kg（0 = 只用自重）' : '重量 kg（自重动作填 0）')
        : '次数';
    Widget button(int delta) => Semantics(
      button: true,
      excludeSemantics: true,
      label: '${delta < 0 ? '减少' : '增加'}$label',
      child: Pressable(
        onTap: () => bump(isWeight, delta),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
          child: Text(
            delta < 0 ? '−' : '+',
            style: TextStyle(color: p.tint, fontSize: 28),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(fieldLabel, style: TextStyle(fontSize: 13, color: p.secondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              button(-1),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      label: fieldLabel,
                      textField: true,
                      child: EditableText(
                        controller: isWeight ? weight : reps,
                        focusNode: isWeight ? weightFocus : repsFocus,
                        style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.96,
                          color: p.text,
                        ),
                        cursorColor: p.tint,
                        backgroundCursorColor: p.fill,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: isWeight,
                        ),
                      ),
                    ),
                    Text(
                      isWeight ? 'kg' : '次',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              button(1),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AppSheet(
      title: '改这一组',
      onSave: save,
      saveEnabled: !saving,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Reveal(
            visible: error.isNotEmpty,
            child: error.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: p.tintSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: p.err, fontSize: 15),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            '${widget.set['ex']} · 第 ${widget.set['no']} 组',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: p.secondary,
            ),
          ),
          const SizedBox(height: 8),
          step(true),
          const SizedBox(height: 10),
          step(false),
          const SizedBox(height: 14),
          Text('还能做几次', style: TextStyle(fontSize: 13, color: p.secondary)),
          Row(
            children: [
              for (final n in [0, 1, 2, 3]) ...[
                if (n > 0) const SizedBox(width: 6),
                Expanded(
                  child: SetFeedbackChip(
                    label: n == 3 ? '3+' : '$n',
                    selected: remaining == n,
                    onTap: () => setState(() {
                      feedbackChanged = true;
                      remaining = remaining == n ? null : n;
                    }),
                  ),
                ),
              ],
            ],
          ),
          Text('有不舒服吗', style: TextStyle(fontSize: 13, color: p.secondary)),
          Row(
            children: [
              for (final item in [('form', '动作变形'), ('pain', '有点痛')]) ...[
                if (item.$1 == 'pain') const SizedBox(width: 8),
                Expanded(
                  child: SetFeedbackChip(
                    label: item.$2,
                    selected: flag == item.$1,
                    onTap: () =>
                        setState(() => flag = flag == item.$1 ? '' : item.$1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 46,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: p.seg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final name in ['热身', '正式', '递减'])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: type == name,
                      label: name,
                      child: Pressable(
                        onTap: () => setState(() => type = name),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: type == name ? p.segOn : null,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared by the recorder and history editor; visual 36, touch target 44.
class SetFeedbackChip extends StatelessWidget {
  const SetFeedbackChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.selected,
    this.haptic = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool haptic;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    selected: selected,
    child: Pressable(
      scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
      haptic: haptic,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? context.pal.tintSoft : context.pal.fill2,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: selected ? context.pal.tint : context.pal.text,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
