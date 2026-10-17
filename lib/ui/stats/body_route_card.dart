import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/body_trend.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../me/profile_card.dart';
import 'stat_widgets.dart';

class BodyRouteCard extends StatelessWidget {
  const BodyRouteCard({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    // 起点用评估时记下的体重/体脂，不随“同步体重”变化。
    final base = app.baseline;
    final profile = app.profile == null || base == null
        ? app.profile
        : {...app.profile!, 'weightKg': base['weightKg']};
    final targets = app.targets == null || base == null
        ? app.targets
        : {
            ...app.targets!,
            'bodyFat': {
              ...app.targets!['bodyFat'] as Map,
              'value': base['bodyFatPct'],
            },
          };
    final trend = bodyTrend(app.bodyEntries, profile, targets, app.today);
    final mean = trend['latestMean'] as double?;
    final change = trend['weekChange'] as double?;
    final stage = app.targets?['stage'];
    final series = (trend['series'] as List).cast<Map<String, dynamic>>();
    final estimate = trend['estimatedBodyFat'] as double?;
    return StatBlock(
      title: routeName(stage),
      children: [
        const SizedBox(height: 10),
        if (mean == null) ...[
          LText(
            '记录体重，看见趋势',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 14),
          FormButton('记体重', filled: true, onTap: () => openBodyLog(context)),
        ] else ...[
          LText(
            '${mean.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
          LText(
            change == null
                ? (trend['count'] == 1 ? '再记几天就能看到趋势' : '7 日平均体重 · 继续记录，看见本周变化')
                : '本周 ${change == 0 ? '持平' : '${change > 0 ? '↑' : '↓'}${change.abs().toStringAsFixed(1)} 公斤'} · 7 日平均',
            style: AppText.hint(p),
          ),
          if (series.length > 1 && (trend['count'] as int) > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: CustomPaint(
                painter: BodyTrendLine(series, p.tint, p.fill),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LText(
                  _shortDate(series.first['date'] as String),
                  style: AppText.hint(p),
                ),
                LText(
                  _shortDate(series.last['date'] as String),
                  style: AppText.hint(p),
                ),
              ],
            ),
          ],
          if (trend['progress'] != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LText(
                  '起点 ${(targets!['bodyFat']['value'] as num).toStringAsFixed(1)}%',
                  style: AppText.hint(p),
                ),
                LText(
                  '估算 ${estimate!.toStringAsFixed(1)}%',
                  style: AppText.hint(p),
                ),
                LText(
                  '目标 ${app.targets!['goalBodyFat']}%',
                  style: AppText.hint(p),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: p.fill)),
                    FractionallySizedBox(
                      widthFactor: trend['progress'] as double,
                      heightFactor: 1,
                      child: ColoredBox(color: p.tint),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            LText('体脂根据体重变化估算，仅供参考。', style: AppText.hint(p)),
          ],
          if (stage == 'bulk' || stage == 'youth') ...[
            const SizedBox(height: 12),
            LText(
              stage == 'youth'
                  ? '成长期 · 吃够睡够，保持训练习惯'
                  : '每周增重参考 0.2–0.4 kg${change == null
                        ? ''
                        : trend['gainInRange'] == true
                        ? ' · 本周在参考区间内'
                        : ' · 持续记录，观察变化'}',
              style: AppText.hint(p),
            ),
          ],
        ],
      ],
    );
  }
}

class BodyTrendLine extends CustomPainter {
  BodyTrendLine(this.series, this.color, this.fill);
  final List<Map<String, dynamic>> series;
  final Color color, fill;
  @override
  void paint(Canvas canvas, Size size) {
    final weights = series
        .map((e) => (e['weightKg'] as num).toDouble())
        .toList();
    final min = weights.reduce((a, b) => a < b ? a : b),
        max = weights.reduce((a, b) => a > b ? a : b);
    final span = (max - min).clamp(.5, double.infinity);
    canvas.drawLine(
      Offset(0, size.height - 5),
      Offset(size.width, size.height - 5),
      Paint()
        ..color = fill
        ..strokeWidth = 1,
    );
    final start = DateTime.parse(series.first['date'] as String),
        end = DateTime.parse(series.last['date'] as String);
    final days = end.difference(start).inDays.clamp(1, 10000);
    final path = Path();
    for (var i = 0; i < weights.length; i++) {
      final x =
          4 +
          DateTime.parse(series[i]['date'] as String).difference(start).inDays /
              days *
              (size.width - 8);
      final y =
          size.height - 10 - (weights[i] - min) / span * (size.height - 20);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      // 点多时只画线；点少（刚开始记录）才画圆点，避免折线变成一串珠子。
      if (weights.length <= 14) {
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(BodyTrendLine oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.color != color ||
      oldDelegate.fill != fill;
}

String _shortDate(String iso) =>
    '${int.parse(iso.substring(5, 7))}月${int.parse(iso.substring(8, 10))}日';
