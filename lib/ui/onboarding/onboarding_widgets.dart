import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../kit/pressable.dart';

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.child, this.selected = false});
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: selected ? context.pal.tint : context.pal.card,
        width: 2,
      ),
    ),
    child: child,
  );
}

class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.selected = false,
    this.toggleable = false,
    this.circular = false,
    this.secondary = false,
    this.textOnly = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool selected;
  final bool circular;
  final bool toggleable;
  final bool secondary, textOnly, compact;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        haptic:
            toggleable || (!selected && !primary && !secondary && !textOnly),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: primary ? 56 : 44,
            minWidth: 44,
          ),
          width: primary || secondary ? double.infinity : null,
          height: compact || secondary ? 44 : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 14,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: primary
                ? (onTap == null ? p.fill : p.tint)
                : textOnly
                ? p.bg.withValues(alpha: 0)
                : selected
                ? p.tintSoft
                : secondary
                ? p.fill2
                : p.card,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular
                ? null
                : BorderRadius.circular(primary ? 22 : 14),
            border: selected ? Border.all(color: p.tint) : null,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: LText(
              label,
              textAlign: TextAlign.center,
              style: (textOnly || compact ? AppText.body(p) : AppText.h2(p))
                  .copyWith(
                    color: primary && onTap != null
                        ? p.onTint
                        : selected
                        ? p.tint
                        : p.text,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.embedded = false,
    this.dense = false,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool embedded;
  final bool dense;

  @override
  Widget build(BuildContext context) => embedded
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              child,
              if (i < children.length - 1) SizedBox(height: dense ? 10 : 12),
            ],
          ],
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            LText(title, style: AppText.navDay(context.pal)),
            const SizedBox(height: 12),
            LText(subtitle, style: AppText.navWeek(context.pal)),
            SizedBox(height: dense ? 16 : 24),
            for (final child in children) ...[
              child,
              SizedBox(height: dense ? 12 : 16),
            ],
          ],
        );
}

/// EditableText keeps platform keyboard/selection behavior without Material styling.
class OnboardingNumber extends StatefulWidget {
  const OnboardingNumber({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix = 'cm',
  });
  final String label;
  final num? value;
  final String suffix;
  final ValueChanged<num?> onChanged;

  @override
  State<OnboardingNumber> createState() => _OnboardingNumberState();
}

class _OnboardingNumberState extends State<OnboardingNumber> {
  late final _text = TextEditingController(
    text: widget.value?.toString() ?? '',
  );
  final _focus = FocusNode();
  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: LText(widget.label, style: AppText.body(context.pal))),
        SizedBox(
          width: 90,
          child: Semantics(
            label: AppMessages.of(context).text(widget.label),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.pal.fill2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: EditableText(
                  controller: _text,
                  focusNode: _focus,
                  style: AppText.h2(context.pal),
                  cursorColor: context.pal.tint,
                  backgroundCursorColor: context.pal.fill,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  onChanged: (text) => widget.onChanged(
                    text.trim().isEmpty
                        ? null
                        : num.tryParse(text) ?? double.nan,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        LText(widget.suffix, style: AppText.hint(context.pal)),
      ],
    ),
  );
}
