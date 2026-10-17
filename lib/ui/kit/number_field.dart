import '../../core/haptics.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';
import 'pressable.dart';

/// Unstyled editable input, with the Web placeholder and numeric typography.
class SheetInput extends StatefulWidget {
  const SheetInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.placeholder = '',
    this.numeric = false,
    this.align = TextAlign.start,
    this.size = 17,
    this.lines = 1,
    this.weight = FontWeight.w400,
    this.onSubmitted,
    this.focusNode,
    this.color,
    this.letterSpacing = 0,
  });
  final String value, label, placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool numeric;
  final TextAlign align;
  final double size;
  final int lines;
  final FontWeight weight;
  final Color? color;
  final double letterSpacing;
  @override
  State<SheetInput> createState() => _SheetInputState();
}

class _SheetInputState extends State<SheetInput> {
  late final _text = TextEditingController(text: widget.value);
  late final _focus = widget.focusNode ?? FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_select);
  }

  void _select() {
    if (_focus.hasFocus && widget.numeric) {
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    }
  }

  @override
  void didUpdateWidget(SheetInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.value) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.removeListener(_select);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = DefaultTextStyle.of(context).style.copyWith(
      color: widget.color ?? p.text,
      fontSize: widget.size,
      fontWeight: widget.weight,
      letterSpacing: widget.letterSpacing,
      fontFeatures: widget.numeric
          ? const [FontFeature.tabularFigures()]
          : null,
    );
    return Semantics(
      label: widget.label,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (widget.value.isEmpty)
            IgnorePointer(
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  widget.placeholder,
                  textAlign: widget.align,
                  style: style.copyWith(color: p.ph),
                ),
              ),
            ),
          EditableText(
            controller: _text,
            focusNode: _focus,
            style: style,
            cursorColor: p.tint,
            backgroundCursorColor: p.fill,
            selectionColor: p.tintSoft,
            textAlign: widget.align,
            keyboardType: widget.numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            maxLines: widget.lines,
            minLines: widget.lines,
            textInputAction: widget.lines > 1
                ? TextInputAction.newline
                : TextInputAction.done,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTapOutside: (_) => _focus.unfocus(),
          ),
        ],
      ),
    );
  }
}

/// The +/- weight/repetition stepper from .step in app.css.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.unit,
    required this.step,
    this.focusNode,
  });
  final String value, label, unit;
  final double step;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  void bump(BuildContext context, double delta) {
    if (value.trim().isEmpty) {
      if (delta > 0) {
        HapticScope.of(context)?.selection();
        onChanged('$step'.replaceFirst(RegExp(r'\.0$'), ''));
      }
      return;
    }
    final n = double.tryParse(value);
    if (n == null || !n.isFinite) return;
    final next = ((n + delta) * 1000).round() / 1000;
    if ((next < 0 ? 0 : next) == n) return;
    HapticScope.of(context)?.selection();
    onChanged(
      (next < 0 ? 0 : next).toString().replaceFirst(RegExp(r'\.0$'), ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget button(String text, String semantics, double delta) => Semantics(
      button: true,
      label: semantics,
      child: Pressable(
        onTap: () => bump(context, delta),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
          child: ExcludeSemantics(
            child: Text(text, style: TextStyle(color: p.tint, fontSize: 28)),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 76),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          button('−', '减少$label', -step),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                SheetInput(
                  value: value,
                  onChanged: onChanged,
                  label: label,
                  numeric: true,
                  align: TextAlign.center,
                  size: 32,
                  letterSpacing: -0.96,
                  focusNode: focusNode,
                  weight: FontWeight.w700,
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          button('+', '增加$label', step),
        ],
      ),
    );
  }
}
