import 'package:leandaily/l10n/app_messages.dart';

import '../../../l10n/localized_text.dart';
import '../../../core/haptics.dart';

import 'package:flutter/widgets.dart';

import '../../../theme/theme.dart';
import '../../kit/pressable.dart';
import '../../kit/app_icon.dart';
import '../../kit/segments.dart';

class SheetButton extends StatelessWidget {
  const SheetButton(
    this.label,
    this.onTap, {
    super.key,
    this.icon,
    this.primary = false,
    this.soft = false,
    this.pill = false,
    this.iconOnly = false,
  });
  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final bool primary, soft, pill, iconOnly;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: primary ? 50 : 44,
            minWidth: 44,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primary
                ? p.tint
                : soft
                ? p.fill2
                : pill
                ? p.fill
                : iconOnly
                ? null
                : p.card,
            borderRadius: BorderRadius.circular(primary || pill ? 999 : 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(
                  icon!,
                  size: iconOnly ? 18 : 16,
                  color: primary
                      ? p.onTint
                      : iconOnly
                      ? p.secondary
                      : p.text,
                ),
                if (!iconOnly) const SizedBox(width: 6),
              ],
              if (!iconOnly)
                Flexible(
                  child: LText(
                    label,
                    style: TextStyle(
                      color: primary
                          ? p.onTint
                          : iconOnly
                          ? p.secondary
                          : p.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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

class SheetSegments extends StatelessWidget {
  const SheetSegments({
    super.key,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.height = 40,
    this.iconFor,
  });
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;
  final double height;
  final String Function(String)? iconFor;
  @override
  Widget build(BuildContext context) => AppSegments(
    labels: labels,
    selected: labels.indexOf(value).clamp(0, labels.length - 1),
    onChanged: (i) => onChanged(labels[i]),
    icons: iconFor == null
        ? null
        : [
            for (final label in labels)
              AppIcon(iconFor!(label), size: 16, color: context.pal.text),
          ],
  );
}

class EffortControl extends StatelessWidget {
  const EffortControl({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    void update(double x, double width) {
      var n = ((x / width).clamp(0, 1) * 20).round() / 2;
      if (n > 0 && n < 1) n = 1;
      if (n == value) return;
      if (n.floor() != value.floor()) HapticScope.of(context)?.tick();
      onChanged(n);
    }

    return Semantics(
      label: AppMessages.of(context).text('吃力程度 1–10'),
      value: AppMessages.of(context).text('$value'),
      increasedValue: AppMessages.of(context)
          .text('${(value + 0.5).clamp(1, 10)}'),
      decreasedValue: AppMessages.of(context)
          .text('${value <= 1 ? 0 : value - 0.5}'),
      slider: true,
      onIncrease: () {
        if (value < 10) {
          HapticScope.of(context)?.tick();
          onChanged((value + 0.5).clamp(1, 10));
        }
      },
      onDecrease: () {
        if (value > 0) {
          HapticScope.of(context)?.tick();
          onChanged(value <= 1 ? 0 : value - 0.5);
        }
      },
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx, box.maxWidth),
          onHorizontalDragUpdate: (d) =>
              update(d.localPosition.dx, box.maxWidth),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.fill,
                    border: Border.all(color: p.secondary, width: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value / 10,
                  child: Container(height: 4, color: p.tint),
                ),
                Align(
                  alignment: Alignment(value / 5 - 1, 0),
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: p.tint,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
