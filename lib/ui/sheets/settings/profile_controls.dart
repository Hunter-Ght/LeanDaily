import 'package:flutter/widgets.dart';

import '../../../domain/body.dart';
import '../../../theme/theme.dart';
import '../../kit/pressable.dart';

class ProfileDiagnosis extends StatelessWidget {
  const ProfileDiagnosis({
    super.key,
    required this.targets,
    required this.kcal,
    required this.protein,
  });
  final Targets targets;
  final num kcal, protein;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget stat(String label, String value, String unit) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: p.secondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
              color: p.text,
            ),
          ),
          Text(unit, style: TextStyle(fontSize: 13, color: p.secondary)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageName(targets['stage'] as String),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            routeText(targets['stage'] as String),
            style: TextStyle(fontSize: 13, height: 1.45, color: p.secondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('目标体脂', numberText(targets['goalBodyFat'] as num), '%'),
              stat('每日热量', numberText(kcal), '千卡'),
              stat('每日蛋白', numberText(protein), '克'),
            ],
          ),
          for (final warning in targets['warnings'] as List)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.fill2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$warning',
                style: TextStyle(fontSize: 13, color: p.secondary),
              ),
            ),
        ],
      ),
    );
  }
}

String numberText(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

/// Only this control rebuilds during dragging; its owner updates the diagnosis
/// through a ValueNotifier instead of rebuilding the sheet on every pointer.
class ProfileGoalSlider extends StatefulWidget {
  const ProfileGoalSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  State<ProfileGoalSlider> createState() => _ProfileGoalSliderState();
}

class _ProfileGoalSliderState extends State<ProfileGoalSlider> {
  late double _value = widget.value;
  @override
  void didUpdateWidget(ProfileGoalSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _value = widget.value;
  }

  void _change(double value) {
    final next = (value.clamp(widget.min, widget.max) * 10).round() / 10;
    setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final fraction = ((_value - widget.min) / (widget.max - widget.min))
          .clamp(0.0, 1.0);
      void locate(double x) =>
          _change(widget.min + (x / box.maxWidth) * (widget.max - widget.min));
      return Semantics(
        label: '目标体脂滑杆',
        value: '${numberText(_value)}%',
        slider: true,
        increasedValue:
            '${numberText((_value + 1).clamp(widget.min, widget.max))}%',
        decreasedValue:
            '${numberText((_value - 1).clamp(widget.min, widget.max))}%',
        onIncrease: () {
          _change(_value + 1);
          widget.onChanged(_value);
        },
        onDecrease: () {
          _change(_value - 1);
          widget.onChanged(_value);
        },
        child: Pressable(
          onTap: () {},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) {
              locate(e.localPosition.dx);
              widget.onChanged(_value);
            },
            onHorizontalDragStart: (e) => locate(e.localPosition.dx),
            onHorizontalDragUpdate: (e) => locate(e.localPosition.dx),
            onHorizontalDragEnd: (_) => widget.onChanged(_value),
            onHorizontalDragCancel: () => widget.onChanged(_value),
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: context.pal.fill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.pal.tint,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(fraction * 2 - 1, 0),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.pal.tint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
