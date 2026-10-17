import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../domain/body.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import 'onboarding_widgets.dart';
import 'profile_steps.dart';

class BodyFatStep extends StatelessWidget {
  const BodyFatStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });
  final Profile profile;
  final ProfileChange onChanged;

  @override
  Widget build(BuildContext context) {
    final male = profile['sex'] == 'male';
    final method = profile['bodyFatMethod'];
    final fat = estimateBodyFat(profile);
    final bands = male
        ? [6, 10, 15, 20, 25, 30, 35, 40]
        : [14, 18, 22, 26, 30, 35, 40, 45];
    const descriptions = [
      '线条明显',
      '腹部清晰',
      '轮廓清楚',
      '腰腹柔和',
      '腰围渐宽',
      '腹部饱满',
      '腰腹圆润',
      '轮廓宽厚',
    ];
    final tab = method == 'navy'
        ? 1
        : method == 'picker'
        ? 2
        : method == 'manual'
        ? 0
        : 3;
    return OnboardingPage(
      title: '体脂',
      subtitle: '体脂越准计划越准，之后可以随时改',
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.pal.seg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (i, label) in ['我知道', '量一量', '看图选', '我不知道'].indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: tab == i,
                    label: label,
                    excludeSemantics: true,
                    child: Pressable(
                      haptic: tab != i,
                      onTap: () {
                        if (tab == i) return;
                        onChanged('bodyFatPct', null);
                        onChanged(
                          'bodyFatMethod',
                          ['manual', 'navy', 'picker', 'bmi'][i],
                        );
                      },
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tab == i ? context.pal.segOn : null,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          label,
                          style: AppText.h2(context.pal).copyWith(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PushSwitcher(
          direction: 1,
          child: Column(
            key: ValueKey(tab),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tab == 0)
                OnboardingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('输入你的体脂率', style: AppText.h2(context.pal)),
                      OnboardingNumber(
                        key: const ValueKey('bodyFatPct'),
                        label: '体脂率',
                        value: profile['bodyFatPct'] as num?,
                        suffix: '%',
                        onChanged: (v) {
                          onChanged('bodyFatMethod', 'manual');
                          onChanged(
                            'bodyFatPct',
                            v == null || !v.isFinite
                                ? v
                                : (v * 10).round() / 10,
                          );
                        },
                      ),
                      Text(
                        '填写 3–60%，保留一位小数；也可以先用粗略估算。',
                        style: AppText.hint(context.pal),
                      ),
                    ],
                  ),
                ),
              if (tab == 1)
                OnboardingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (key, label, note) in [
                        ('waistCm', '腰围', '肚脐附近，放松后水平绕一圈'),
                        ('neckCm', '颈围', '喉结下方，皮尺轻贴颈部'),
                        if (!male) ('hipCm', '臀围', '臀部最宽处，水平绕一圈'),
                      ]) ...[
                        Row(
                          children: [
                            CustomPaint(
                              size: const Size(44, 64),
                              painter: BodyOutlinePainter(
                                level: .4,
                                color: context.pal.secondary,
                                accent: context.pal.tint,
                                measurement: key,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  OnboardingNumber(
                                    key: ValueKey(key),
                                    label: label,
                                    value: profile[key] as num?,
                                    onChanged: (v) => onChanged(key, v),
                                  ),
                                  Text(note, style: AppText.hint(context.pal)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        '皮尺轻贴皮肤，不勒紧。缺少有效围度时使用粗略估算。',
                        style: AppText.hint(context.pal),
                      ),
                    ],
                  ),
                ),
              if (tab == 2)
                SizedBox(
                  height: 238,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: bands.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => SizedBox(
                      width: 126,
                      child: Semantics(
                        label: '约 ${bands[i]}%',
                        button: true,
                        selected: profile['bodyFatPct'] == bands[i],
                        excludeSemantics: true,
                        child: _BodyBand(
                          value: bands[i],
                          description: descriptions[i],
                          index: i,
                          selected: profile['bodyFatPct'] == bands[i],
                          tap: () => onChanged('bodyFatPct', bands[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '约 ${fat['value']}%（误差 ±${fat['margin']}%）',
                style: AppText.sect(context.pal),
              ),
              if (fat['method'] == 'bmi') ...[
                const SizedBox(height: 6),
                Text('粗略估算 · BMI 公式', style: AppText.hint(context.pal)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyBand extends StatelessWidget {
  const _BodyBand({
    required this.value,
    required this.description,
    required this.index,
    required this.selected,
    required this.tap,
  });
  final int value;
  final String description;
  final int index;
  final bool selected;
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => Pressable(
    haptic: !selected,
    onTap: tap,
    child: OnboardingCard(
      selected: selected,
      child: Column(
        children: [
          CustomPaint(
            size: const Size(72, 134),
            painter: BodyOutlinePainter(
              level: index / 7,
              color: context.pal.secondary,
              accent: context.pal.tint,
            ),
          ),
          const SizedBox(height: 10),
          Text('约 $value%', style: AppText.h2(context.pal)),
          const SizedBox(height: 4),
          Text(description, style: AppText.hint(context.pal)),
        ],
      ),
    ),
  );
}

/// Simplified torso, intentionally schematic rather than a medical reference.
class BodyOutlinePainter extends CustomPainter {
  const BodyOutlinePainter({
    required this.level,
    required this.color,
    required this.accent,
    this.measurement,
  });
  final double level;
  final Color color;
  final Color accent;
  final String? measurement;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 180);
    final waist = 24 + 24 * level;
    final path = Path()
      ..moveTo(38, 6)
      ..lineTo(38, 20)
      ..lineTo(18, 30)
      ..quadraticBezierTo(12, 58, 50 - waist, 94)
      ..quadraticBezierTo(50 - waist - 5, 122, 22, 150)
      ..lineTo(28, 174)
      ..lineTo(48, 174)
      ..lineTo(50, 144)
      ..lineTo(52, 174)
      ..lineTo(72, 174)
      ..lineTo(78, 150)
      ..quadraticBezierTo(50 + waist + 5, 122, 50 + waist, 94)
      ..quadraticBezierTo(88, 58, 82, 30)
      ..lineTo(62, 20)
      ..lineTo(62, 6);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    if (measurement != null) {
      final y = measurement == 'neckCm'
          ? 16.0
          : measurement == 'hipCm'
          ? 140.0
          : 94.0;
      canvas.drawLine(
        Offset(12, y),
        Offset(88, y),
        Paint()
          ..color = accent
          ..strokeWidth = 4,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodyOutlinePainter oldDelegate) =>
      level != oldDelegate.level ||
      color != oldDelegate.color ||
      accent != oldDelegate.accent ||
      measurement != oldDelegate.measurement;
}
