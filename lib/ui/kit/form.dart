import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../motion.dart';
import 'menu.dart';
import 'pressable.dart';
import 'segments.dart';
import 'sheet.dart';
import 'app_icon.dart';

/// Web 的 .lbl / .hint / .row，设置页共用。
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
    child: LText(
      text,
      style: TextStyle(fontSize: 13, color: context.pal.secondary),
    ),
  );
}

class FormHint extends StatelessWidget {
  const FormHint(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
    child: LText(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: error ? context.pal.err : context.pal.secondary,
      ),
    ),
  );
}

class FormRow extends StatelessWidget {
  const FormRow(
    this.label, {
    super.key,
    required this.child,
    this.slim = false,
  });
  final String label;
  final Widget child;
  final bool slim;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: slim ? 6 : 12),
    padding: EdgeInsets.symmetric(
      horizontal: 14,
      vertical: child is FormSwitch && !slim ? 3.5 : 0,
    ),
    constraints: BoxConstraints(minHeight: slim ? 44 : 45),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(
          child: LText(
            label,
            style: TextStyle(
              fontSize: 17,
              height: 1.3,
              color: context.pal.text,
            ),
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    ),
  );
}

/// EditableText 保持焦点、选区和输入草稿；不使用 Material 输入外观。
class FormInput extends StatefulWidget {
  const FormInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.numeric = false,
    this.obscure = false,
    this.enabled = true,
    this.boxed = false,
    this.width,
    this.placeholder,
    this.maxLength,
    this.align = TextAlign.right,
    this.filled = false,
    this.plain = false,
    this.fontSize,
  });
  final String value, label;
  final ValueChanged<String> onChanged;
  final bool numeric, obscure, enabled, boxed, filled, plain;
  final double? fontSize;
  final double? width;
  final String? placeholder;
  final int? maxLength;
  final TextAlign align;
  @override
  State<FormInput> createState() => _FormInputState();
}

class _FormInputState extends State<FormInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();
  @override
  void didUpdateWidget(FormInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _text.text != widget.value) {
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: widget.width,
      child: Semantics(
        label: AppMessages.of(context).text(widget.label),
        textField: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: widget.boxed
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : EdgeInsets.zero,
          decoration: widget.filled
              ? BoxDecoration(
                  color: p.fill,
                  borderRadius: BorderRadius.circular(10),
                )
              : widget.boxed
              ? BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.sep),
                )
              : null,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (_text.text.isEmpty && widget.placeholder != null)
                IgnorePointer(
                  child: LText(
                    widget.placeholder!,
                    style: TextStyle(fontSize: 14, color: p.ph),
                  ),
                ),
              EditableText(
                controller: _text,
                focusNode: _focus,
                readOnly: !widget.enabled,
                obscureText: widget.obscure,
                style: TextStyle(
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  fontSize: widget.fontSize ?? (widget.boxed ? 14 : 17),
                  fontWeight: widget.boxed ? FontWeight.w400 : FontWeight.w600,
                  color: !widget.enabled ? p.secondary : p.text,
                ),
                cursorColor: p.tint,
                backgroundCursorColor: p.fill,
                selectionColor: p.tintSoft,
                textAlign: widget.align,
                keyboardType: widget.numeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                onChanged: (s) {
                  if (widget.maxLength != null &&
                      s.length > widget.maxLength!) {
                    _text.text = s.substring(0, widget.maxLength);
                    s = _text.text;
                  }
                  setState(() {});
                  widget.onChanged(s);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FormSwitch extends StatefulWidget {
  const FormSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.haptic = true,
  });
  final bool haptic;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  @override
  State<FormSwitch> createState() => _FormSwitchState();
}

class _FormSwitchState extends State<FormSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );
  @override
  void didUpdateWidget(FormSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      springTo(_x, widget.value ? 1 : 0, response: .3);
    }
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      label: AppMessages.of(context).text(widget.label),
      toggled: widget.value,
      button: true,
      child: Pressable(
        haptic: widget.haptic,
        onTap: () => widget.onChanged(!widget.value),
        child: SizedBox(
          width: 51,
          height: 44,
          child: Center(
            child: AnimatedBuilder(
              animation: _x,
              builder: (_, _) => Container(
                width: 51,
                height: 31,
                decoration: BoxDecoration(
                  color: Color.lerp(p.fill, p.ok, _x.value.clamp(0, 1)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(2 + 20 * _x.value, 0),
                    child: Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: p.onTint,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: p.shadow,
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FormSegments extends StatelessWidget {
  const FormSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: AppSegments(
      labels: labels,
      selected: selected,
      onChanged: onChanged,
    ),
  );
}

class FormButton extends StatelessWidget {
  const FormButton(
    this.label, {
    super.key,
    required this.onTap,
    this.danger = false,
    this.filled = false,
    this.plain = false,
    this.pill = false,
    this.ink = false,
    this.icon,
    this.semanticLabel,
  });
  final String label;
  final VoidCallback? onTap;
  final bool danger, filled, plain, pill, ink;
  final String? icon, semanticLabel;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(semanticLabel ?? label),
      enabled: onTap != null,
      child: Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: plain
                  ? p.bg.withValues(alpha: 0)
                  : filled
                  ? p.tint
                  : ink || pill
                  ? p.fill
                  : p.tintSoft,
              borderRadius: BorderRadius.circular(pill ? 999 : 10),
            ),
            child: icon != null
                ? AppIcon(icon!, color: danger ? p.err : p.text, size: 18)
                : LText(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: danger
                          ? p.err
                          : filled
                          ? p.onTint
                          : ink || pill
                          ? p.text
                          : p.tint,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class FormChoice extends StatelessWidget {
  const FormChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 150,
    this.filled = false,
    this.arrow = true,
    this.compact = false,
  });
  final String label, value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final double width;
  final bool filled, arrow, compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: () async {
          if (options.length > 8) {
            final picked = await showAppSheet<String>(
              context,
              (c) => AppSheet(
                title: label,
                child: Builder(
                  builder: (body) => Column(
                    children: [
                      for (final e in options.entries)
                        FormButton(
                          e.value,
                          onTap: () => SheetController.of(body).close(e.key),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (picked != null && context.mounted) onChanged(picked);
          } else {
            final picked = await showActionMenu(
              context,
              title: label,
              actions: [
                for (final e in options.entries)
                  MenuAction(id: e.key, label: e.value),
              ],
            );
            if (picked != null && context.mounted) onChanged(picked.id);
          }
        },
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 32 : 44),
          decoration: filled
              ? BoxDecoration(
                  color: context.pal.fill,
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          alignment: filled ? Alignment.center : Alignment.centerRight,
          child: Row(
            mainAxisAlignment: filled
                ? MainAxisAlignment.center
                : MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: LText(
                  options[value] ?? value,
                  maxLines: 2,
                  textAlign: filled ? TextAlign.center : TextAlign.right,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: filled ? context.pal.text : context.pal.secondary,
                  ),
                ),
              ),
              if (arrow)
                RotatedBox(
                  quarterTurns: 1,
                  child: AppIcon(
                    'right',
                    size: 12,
                    color: filled ? context.pal.text : context.pal.tertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Web 原生 checkbox 的紧凑外观；点击热区仍为 44 高。
class FormCheck extends StatelessWidget {
  const FormCheck({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emphasized = false,
  });
  final String label;
  final bool value;
  final bool emphasized;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      checked: value,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: value ? p.tint : p.card,
                  border: Border.all(color: value ? p.tint : p.secondary),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: value
                    ? AppIcon('check', size: 11, color: p.onTint)
                    : null,
              ),
              Flexible(
                child: LText(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: emphasized ? p.text : p.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
