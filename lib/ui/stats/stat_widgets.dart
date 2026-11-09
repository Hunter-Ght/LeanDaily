import '../../l10n/localized_text.dart';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../domain/format.dart';

/// 进度页的区块：区块标题（AppText.title）+ 内容。默认不套卡片，靠留白分组；
/// [card] 为 true 时才套卡片（需要和周围内容分开的少数场合）。
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.card = false,
  });
  final String title;
  final List<Widget> children;

  /// 标题右侧的小字（如时间范围）。
  final Widget? trailing;
  final bool card;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: card
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 4),
      decoration: card
          ? BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(22),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: LText(title, style: AppText.title(p))),
              ?trailing,
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

class EstimateChart extends CustomPainter {
  EstimateChart(this.dots, this.color, {this.viewHeight = 140});
  final List<Map<String, dynamic>> dots;
  final Color color;

  /// 坐标系高度（宽固定 320）；数值全相同、只画一条平线时用矮一点的。
  final double viewHeight;
  @override
  void paint(Canvas canvas, Size size) {
    // Preserve the SVG viewBox's aspect ratio and centered letterboxing.
    final scale = math.min(size.width / 320, size.height / viewHeight);
    canvas.translate(
      (size.width - 320 * scale) / 2,
      (size.height - viewHeight * scale) / 2,
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
      old.dots != dots || old.color != color || old.viewHeight != viewHeight;
}

String shortDate(Object? iso) {
  final parts = '$iso'.split('-');
  return '${fmt(num.parse(parts[1]))}/${fmt(num.parse(parts[2]))}';
}
