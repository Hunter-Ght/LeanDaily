import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../domain/format.dart' show effortWord;
import '../../../theme/theme.dart';
import 'controls.dart';

/// RPE dragging rebuilds only this small control, never the sheet or its rows.
class EffortEditor extends StatefulWidget {
  const EffortEditor({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<EffortEditor> createState() => _EffortEditorState();
}

class _EffortEditorState extends State<EffortEditor> {
  late String _value = widget.value;
  @override
  void didUpdateWidget(EffortEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(
      children: [
        Row(
          children: [
            LText('吃力程度 1–10', style: AppText.hint(p)),
            const SizedBox(width: 8),
            LText(
              _value.isEmpty ? '关' : _value,
              style: TextStyle(
                color: p.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            LText(
              effortWord(_value),
              style: TextStyle(
                color: p.secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        EffortControl(
          value: double.tryParse(_value) ?? 0,
          onChanged: (n) {
            final value = n == 0 ? '' : '$n'.replaceFirst(RegExp(r'\.0$'), '');
            setState(() => _value = value);
            widget.onChanged(value);
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['不记', '轻松', '适中', '吃力', '力竭'])
              LText(
                label,
                style: TextStyle(
                  color:
                      (_value.isEmpty && label == '不记') ||
                          effortWord(_value) == label
                      ? p.tint
                      : p.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
