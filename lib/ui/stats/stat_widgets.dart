import '../../l10n/localized_text.dart';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../domain/format.dart';

class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText(title, style: AppText.h2(context.pal)),
        ...children,
      ],
    ),
  );
}

class GoalRings extends CustomPainter {
  GoalRings(this.values, this.goals, this.palette);
  final List<num> values, goals;
  final AppPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72);
    final colors = [palette.tint, palette.dotMeal, palette.kcal];
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromCircle(
        center: const Offset(36, 36),
        radius: 30 - i * 8,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(
        const Offset(36, 36),
        30 - i * 8,
        paint..color = palette.fill,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * (values[i] / math.max(1, goals[i])).clamp(.08, 1),
        false,
        paint..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(GoalRings old) => true;
}

class WeekBars extends CustomPainter {
  WeekBars(this.days, this.field, this.color, this.palette, this.labelStyle);
  final List<Map<String, dynamic>> days;
  final String field;
  final Color color;
  final AppPalette palette;
  final TextStyle labelStyle;
  @override
  void paint(Canvas canvas, Size size) {
    final max = days.fold<num>(1, (n, d) => math.max(n, d[field] as num));
    final step = (size.width + 8) / 7;
    for (var i = 0; i < days.length; i++) {
      final h = math.max(4.0, (days[i][field] as num) / max * 64);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * step, 64 - h, math.min(22, step - 8), h),
          const Radius.circular(7),
        ),
        Paint()..color = color,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${days[i]['label']}',
          style: labelStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.secondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(i * step + (math.min(22, step - 8) - text.width) / 2, 70),
      );
    }
  }

  @override
  bool shouldRepaint(WeekBars old) => true;
}

class EstimateChart extends CustomPainter {
  EstimateChart(this.dots, this.color);
  final List<Map<String, dynamic>> dots;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // Preserve the SVG viewBox's aspect ratio and centered letterboxing.
    final scale = math.min(size.width / 320, size.height / 140);
    canvas.translate(
      (size.width - 320 * scale) / 2,
      (size.height - 140 * scale) / 2,
    );
    canvas.scale(scale);
    final path = Path();
    for (var i = 0; i < dots.length; i++) {
      final x = (dots[i]['x'] as num).toDouble(),
          y = (dots[i]['y'] as num).toDouble();
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    for (final d in dots) {
      canvas.drawCircle(
        Offset((d['x'] as num).toDouble(), (d['y'] as num).toDouble()),
        3.5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(EstimateChart old) =>
      old.dots != dots || old.color != color;
}

String shortDate(Object? iso) {
  final parts = '$iso'.split('-');
  return '${fmt(num.parse(parts[1]))}/${fmt(num.parse(parts[2]))}';
}
