import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../domain/body.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import 'onboarding_widgets.dart';

class DiagnosisStep extends StatefulWidget {
  const DiagnosisStep({
    super.key,
    required this.profile,
    required this.onGoalChanged,
  });
  final Profile profile;
  final ValueChanged<double> onGoalChanged;
  @override
  State<DiagnosisStep> createState() => _DiagnosisStepState();
}

class _DiagnosisStepState extends State<DiagnosisStep> {
  bool _adjusting = false;
  @override
  Widget build(BuildContext context) {
    final targets = buildTargets(widget.profile);
    final p = context.pal;
    final male = widget.profile['sex'] == 'male';
    final fat = targets['bodyFat'] as Map;
    final weeks = targets['weeksRange'] as List?;
    return OnboardingPage(
      title: '你的路线',
      subtitle: '先看清起点，再一步步接近目标。',
      children: [
        OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyFatScale(
                current: fat['value'] as num,
                goal: targets['goalBodyFat'] as num,
                male: male,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TargetNumber(
                    value: '${targets['kcal']}',
                    label: '每日热量',
                    unit: '千卡',
                  ),
                  _TargetNumber(
                    value: '${targets['proteinG']}',
                    label: '每日蛋白',
                    unit: '克',
                  ),
                  _TargetNumber(
                    value: weeks == null ? '—' : '${weeks[0]}–${weeks[1]}',
                    label: '预计周期',
                    unit: '周',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                stageName(targets['stage'] as String),
                style: AppText.sect(p),
              ),
              const SizedBox(height: 6),
              Text(
                routeText(targets['stage'] as String),
                style: AppText.body(p),
              ),
            ],
          ),
        ),
        Text(
          fat['margin'] == 0
              ? '体脂 ${_percent(fat['value'] as num)}%（手动输入）'
              : '体脂约 ${_percent(fat['value'] as num)}%，估算误差 ±${fat['margin']}%。',
          style: AppText.hint(p),
        ),
        OnboardingButton(
          label: _adjusting ? '收起目标体脂' : '调整目标体脂',
          secondary: true,
          onTap: () => setState(() => _adjusting = !_adjusting),
        ),
        Reveal(
          visible: _adjusting,
          child: _adjusting
              ? OnboardingCard(
                  child: Column(
                    children: [
                      GoalBodyFatSlider(
                        key: ValueKey(
                          '${widget.profile['sex']}-${targets['goalBodyFat']}',
                        ),
                        value: (targets['goalBodyFat'] as num).toDouble(),
                        min: male ? 8 : 16,
                        max: male ? 25 : 35,
                        onChanged: widget.onGoalChanged,
                      ),
                      Text(
                        '目标体脂安全下限：${male ? 8 : 16}%',
                        style: AppText.hint(p),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        for (final warning in targets['warnings'] as List)
          if (!(warning as String).startsWith('体脂为估算值'))
            Text(warning, style: AppText.hint(p)),
        Text(
          '估算仅供参考，不是医疗建议',
          key: const ValueKey('diagnosis-disclaimer'),
          textAlign: TextAlign.center,
          style: AppText.hint(p),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TargetNumber extends StatelessWidget {
  const _TargetNumber({
    required this.value,
    required this.label,
    required this.unit,
  });
  final String value, label, unit;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppText.navDay(context.pal).copyWith(fontSize: 28),
          ),
        ),
        Text('$label · $unit', style: AppText.hint(context.pal)),
      ],
    ),
  );
}

class BodyFatScale extends StatelessWidget {
  const BodyFatScale({
    super.key,
    required this.current,
    required this.goal,
    required this.male,
  });
  final num current, goal;
  final bool male;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final band = male ? thinBodyFatMale : thinBodyFatFemale;
    return Semantics(
      label: '体脂刻度，薄肌区间 ${band.$1}–${band.$2}%，你现在 $current%，目标 $goal%',
      excludeSemantics: true,
      child: SizedBox(
        height: 148,
        child: LayoutBuilder(
          builder: (context, box) {
            // Inset the rail so even clamped endpoint markers remain fully visible.
            final width = box.maxWidth - 22;
            double x(num value) => 11 + (value.clamp(5, 40) - 5) / 35 * width;
            final nowX = x(current);
            final goalX = x(goal);
            Widget label(
              String text,
              double center,
              double top,
              double w, {
              bool bubble = false,
            }) => Positioned(
              left: (center - w / 2).clamp(0, box.maxWidth - w),
              top: top,
              width: w,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: bubble ? 5 : 0),
                decoration: bubble
                    ? BoxDecoration(
                        color: p.fill2,
                        borderRadius: BorderRadius.circular(9),
                      )
                    : null,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppText.hint(p).copyWith(
                    fontSize: bubble ? 13 : 12,
                    color: bubble ? p.text : p.secondary,
                  ),
                ),
              ),
            );
            return Stack(
              children: [
                label('你现在 ${_percent(current)}%', nowX, 0, 112, bubble: true),
                label('薄肌区间', (x(band.$1) + x(band.$2)) / 2, 35, 76),
                Positioned(
                  key: const ValueKey('body-fat-rail'),
                  left: 11,
                  right: 11,
                  top: 63,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.fill2,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
                Positioned(
                  left: x(band.$1),
                  width: x(band.$2) - x(band.$1),
                  top: 63,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.ok.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
                Positioned(
                  left: nowX < goalX ? nowX : goalX,
                  width: (nowX - goalX).abs(),
                  top: 67,
                  height: 6,
                  child: ColoredBox(color: p.tint.withValues(alpha: .30)),
                ),
                Positioned(
                  key: const ValueKey('body-fat-goal-marker'),
                  left: goalX - 11,
                  top: 59,
                  width: 22,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.card,
                      border: Border.all(color: p.tint, width: 3),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('body-fat-current-marker'),
                  left: nowX - 11,
                  top: 59,
                  width: 22,
                  height: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.text,
                      border: Border.all(color: p.onTint, width: 3),
                    ),
                  ),
                ),
                label('${band.$1.toInt()}', x(band.$1), 85, 22),
                label('${band.$2.toInt()}', x(band.$2), 85, 22),
                label('目标 ${_percent(goal)}%', goalX, 107, 98),
                label('5%', 11, 130, 24),
                label('40%', box.maxWidth - 15, 130, 30),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _percent(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// The thumb and label update locally while dragging; targets recompute on release.
class GoalBodyFatSlider extends StatefulWidget {
  const GoalBodyFatSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  @override
  State<GoalBodyFatSlider> createState() => _GoalBodyFatSliderState();
}

class _GoalBodyFatSliderState extends State<GoalBodyFatSlider> {
  late final _value = ValueNotifier(widget.value.clamp(widget.min, widget.max));
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _set(double x, double width) => _value.value =
      ((widget.min + (x / width).clamp(0, 1) * (widget.max - widget.min)) * 10)
          .round() /
      10;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: _value,
    builder: (context, value, _) => Semantics(
      label: '目标体脂',
      button: true,
      slider: true,
      value: '$value%',
      increasedValue: '${(value + .1).clamp(widget.min, widget.max)}%',
      decreasedValue: '${(value - .1).clamp(widget.min, widget.max)}%',
      onIncrease: () =>
          widget.onChanged((value + .1).clamp(widget.min, widget.max)),
      onDecrease: () =>
          widget.onChanged((value - .1).clamp(widget.min, widget.max)),
      child: Pressable(
        onTap: () {},
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('$value%', style: AppText.sect(context.pal)),
            SizedBox(
              height: 48,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) =>
                      _set(d.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragUpdate: (d) =>
                      _set(d.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragEnd: (_) => widget.onChanged(_value.value),
                  onHorizontalDragCancel: () => widget.onChanged(_value.value),
                  onTapUp: (d) {
                    _set(d.localPosition.dx, constraints.maxWidth);
                    widget.onChanged(_value.value);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.pal.fill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor:
                              (value - widget.min) / (widget.max - widget.min),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.pal.tint,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(
                          (value - widget.min) / (widget.max - widget.min) * 2 -
                              1,
                          0,
                        ),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: context.pal.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.pal.tint,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.pal.shadow,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.min.toInt()}%',
                  style: AppText.hint(context.pal),
                ),
                Text(
                  '${widget.max.toInt()}%',
                  style: AppText.hint(context.pal),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
