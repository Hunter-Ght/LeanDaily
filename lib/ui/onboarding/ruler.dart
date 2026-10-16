import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// Scrollable ticks repaint independently. Only the local value label listens
/// during dragging; the profile commits at rest, snapped to the nearest tick.
class ProfileRuler extends StatefulWidget {
  const ProfileRuler({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  @override
  State<ProfileRuler> createState() => _ProfileRulerState();
}

class _ProfileRulerState extends State<ProfileRuler> {
  static const spacing = 10.0;
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset:
        (widget.value.clamp(widget.min, widget.max) - widget.min) /
        widget.step *
        spacing,
  );
  late final ValueNotifier<double> _value = ValueNotifier(
    widget.value.clamp(widget.min, widget.max),
  );
  int get count => ((widget.max - widget.min) / widget.step).round();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      _value.value = double.parse(
        (widget.min +
                (_scroll.offset / spacing).round().clamp(0, count) *
                    widget.step)
            .toStringAsFixed(1),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _value.dispose();
    super.dispose();
  }

  void _commit() {
    final tick = ((_value.value - widget.min) / widget.step).round();
    final target = tick * spacing;
    if ((_scroll.offset - target).abs() > .1) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
    widget.onChanged(_value.value);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: AppText.h2(context.pal)),
      ValueListenableBuilder<double>(
        valueListenable: _value,
        builder: (context, value, _) => Semantics(
          label: widget.label,
          value: '$value ${widget.unit}',
          increasedValue:
              '${(value + widget.step).clamp(widget.min, widget.max)}',
          decreasedValue:
              '${(value - widget.step).clamp(widget.min, widget.max)}',
          onIncrease: () => _scroll
              .animateTo(
                math.min(count * spacing, _scroll.offset + spacing),
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              )
              .then((_) => _commit()),
          onDecrease: () => _scroll
              .animateTo(
                math.max(0, _scroll.offset - spacing),
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
              )
              .then((_) => _commit()),
          child: Center(
            child: Text(
              '${value.toStringAsFixed(widget.step < 1 ? 1 : 0)} ${widget.unit}',
              style: AppText.navDay(context.pal).copyWith(fontSize: 28),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _commit();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: CustomPaint(
                    size: Size(count * spacing + constraints.maxWidth, 48),
                    painter: _RulerPainter(
                      start: constraints.maxWidth / 2,
                      count: count,
                      color: context.pal.tertiary,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 2,
                      height: 30,
                      decoration: BoxDecoration(
                        color: context.pal.tint,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.start,
    required this.count,
    required this.color,
  });
  final double start;
  final int count;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final clip = canvas.getLocalClipBounds();
    final first = math.max(0, ((clip.left - start) / 10).floor());
    final last = math.min(count, ((clip.right - start) / 10).ceil());
    for (var i = first; i <= last; i++) {
      final x = start + i * 10;
      canvas.drawLine(
        Offset(x, 0),
        Offset(
          x,
          i % 10 == 0
              ? 26
              : i % 5 == 0
              ? 19
              : 12,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      start != oldDelegate.start ||
      count != oldDelegate.count ||
      color != oldDelegate.color;
}
