import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';

/// 今日页与预览共用的 Web ExerciseRow。
class TodayExerciseRow extends StatelessWidget {
  const TodayExerciseRow({
    super.key,
    required this.exercise,
    required this.onOpen,
    this.skipped = false,
  });
  final Map<String, dynamic> exercise;
  final VoidCallback onOpen;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Opacity(
      opacity: skipped ? .5 : 1,
      child: Semantics(
        button: true,
        label: AppMessages.of(context).text('${exercise['name']}，看示范'),
        child: Pressable(
          onTap: onOpen,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                ExerciseThumb(ex: exercise),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        '${exercise['name']}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.17,
                          color: p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      LText(
                        '${plan.prescription(exercise)}${jsNumber(exercise['weight']) > 0 ? ' · ${fmt(exercise['weight'])} kg' : ''}',
                        style: TextStyle(fontSize: 14, color: p.secondary),
                      ),
                      if (skipped || jsTruthy(exercise['optional']))
                        LText(
                          skipped ? '精简版不练' : '可选',
                          style: TextStyle(fontSize: 12, color: p.secondary),
                        ),
                    ],
                  ),
                ),
                AppIcon('right', size: 16, color: p.tertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodayButton extends StatelessWidget {
  const TodayButton(
    this.label, {
    super.key,
    required this.onTap,
    this.filled = false,
    this.selected = false,
    this.soft = false,
    this.large = false,
    this.neutral = false,
    this.choice = false,
    this.height,
    this.fontSize,
    this.bold = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool filled, selected, soft, large, neutral, choice, bold;
  final double? height, fontSize;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: height ?? (large ? 52 : 44)),
          padding: EdgeInsets.symmetric(
            horizontal: filled || selected || soft || neutral || choice
                ? 14
                : 0,
          ),
          decoration: BoxDecoration(
            color: filled || selected
                ? p.tint
                : soft
                ? p.tintSoft
                : neutral
                ? p.fill
                : choice
                ? p.fill2
                : null,
            borderRadius: BorderRadius.circular(large ? 16 : 999),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: LText(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:
                    fontSize ??
                    (large
                        ? 18
                        : choice
                        ? 14
                        : 15),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: filled || selected
                    ? p.onTint
                    : neutral || choice
                    ? p.text
                    : p.tintPress,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class TodayBar extends StatelessWidget {
  const TodayBar({super.key, required this.value, this.color, this.height = 8});
  final double value;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: SizedBox(
      height: height,
      child: ColoredBox(
        color: context.pal.fill,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
          ),
          curve: Curves.easeOut,
          builder: (_, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: ColoredBox(
                color: color ?? context.pal.tint,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 数字与器械设置的原生输入，不引入 Material 外观。
class TodayInput extends StatefulWidget {
  const TodayInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.numeric = false,
    this.label = '',
    this.fontSize = 15,
    this.placeholder = '',
  });
  final String value, label, placeholder;
  final ValueChanged<String> onChanged;
  final bool numeric;
  final double fontSize;
  @override
  State<TodayInput> createState() => _TodayInputState();
}

class _TodayInputState extends State<TodayInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();
  @override
  void didUpdateWidget(TodayInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppMessages.of(context).text(widget.label),
    textField: true,
    child: Stack(
      children: [
        if (_text.text.isEmpty && widget.placeholder.isNotEmpty)
          IgnorePointer(
            child: LText(
              widget.placeholder,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: widget.fontSize,
                color: context.pal.ph,
              ),
            ),
          ),
        EditableText(
          controller: _text,
          focusNode: _focus,
          style: DefaultTextStyle.of(context).style.copyWith(
            fontSize: widget.fontSize,
            fontWeight: widget.numeric ? FontWeight.w700 : FontWeight.w400,
            color: context.pal.text,
          ),
          cursorColor: context.pal.tint,
          backgroundCursorColor: context.pal.fill,
          keyboardType: widget.numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textAlign: widget.numeric ? TextAlign.center : TextAlign.start,
          onChanged: (value) {
            setState(() {});
            widget.onChanged(value);
          },
        ),
      ],
    ),
  );
}
