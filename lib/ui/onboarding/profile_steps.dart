import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../app/app_controller.dart';
import '../../domain/body.dart';
import '../../app/routes.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/units_scope.dart';
import '../../domain/units.dart';
import '../kit/app_icon.dart';
import 'onboarding_widgets.dart';
import 'ruler.dart';

typedef ProfileChange = void Function(String key, Object? value);

/// 第 1 步底部「继续即表示你了解 隐私政策」。固定在「继续」按钮上方，小屏也不会被滚走或盖住。
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      LText('继续即表示你了解 ', style: AppText.hint(context.pal)),
      Semantics(
        button: true,
        label: AppMessages.of(context).text('隐私政策'),
        child: Pressable(
          onTap: () => openPrivacy(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            alignment: Alignment.center,
            child: LText('隐私政策 ›', style: AppText.hint(context.pal)),
          ),
        ),
      ),
    ],
  );
}

class IdentityStep extends StatelessWidget {
  const IdentityStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });
  final Profile profile;
  final ProfileChange onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // 矮屏幕（小机型、系统安全区占掉不少高度）：压紧间距和刻度条，
      // 更矮时再收起副标题，保证隐私政策那一行在首屏。
      final compact = box.maxHeight < 600, tiny = box.maxHeight < 520;
      return _page(context, compact: compact, tiny: tiny);
    },
  );

  Widget _page(
    BuildContext context, {
    required bool compact,
    required bool tiny,
  }) => OnboardingPage(
    title: '基本信息',
    subtitle: '从你的身体情况开始，找到适合你的节奏。',
    dense: compact,
    showSubtitle: !tiny,
    titleTrailing: const UnitSwitch(),
    children: [
      Row(
        children: [
          for (final entry in const {'male': '男', 'female': '女'}.entries) ...[
            Expanded(
              child: Semantics(
                button: true,
                selected: profile['sex'] == entry.key,
                label: AppMessages.of(context).text(entry.value),
                excludeSemantics: true,
                child: Pressable(
                  haptic: profile['sex'] != entry.key,
                  onTap: () => onChanged('sex', entry.key),
                  child: AnimatedScale(
                    scale: profile['sex'] == entry.key ? 1 : .97,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: OnboardingCard(
                      selected: profile['sex'] == entry.key,
                      padding: compact ? 8 : 16,
                      child: SizedBox(
                        height: compact ? 36 : 44,
                        child: Center(
                          child: LText(
                            entry.value,
                            style: AppText.sect(context.pal),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (entry.key == 'male') const SizedBox(width: 12),
          ],
        ],
      ),
      OnboardingCard(
        padding: compact ? 12 : 16,
        child: Column(
          children: [
            ProfileRuler(
              key: const ValueKey('age'),
              compact: compact,
              label: '年龄',
              unit: '岁',
              value: (profile['age'] as num).toDouble(),
              min: 10,
              max: 90,
              step: 1,
              onChanged: (v) => onChanged('age', v),
            ),
            SizedBox(height: compact ? 4 : 8),
            if (context.units.isImperial)
              ProfileRuler(
                key: const ValueKey('heightCm-imperial'),
                compact: compact,
                label: '身高',
                unit: 'in',
                value: context.units
                    .heightInches(profile['heightCm'] as num)
                    .clamp(48, 90)
                    .toDouble(),
                min: 48,
                max: 90,
                step: 1,
                majorEvery: 12,
                format: (v) =>
                    context.units.heightText(context.units.heightFromInches(v)),
                onChanged: (v) =>
                    onChanged('heightCm', context.units.heightFromInches(v)),
              )
            else
              ProfileRuler(
                key: const ValueKey('heightCm'),
                compact: compact,
                label: '身高',
                unit: 'cm',
                value: (profile['heightCm'] as num).toDouble(),
                min: 120,
                max: 230,
                step: 1,
                onChanged: (v) => onChanged('heightCm', v),
              ),
            SizedBox(height: compact ? 4 : 8),
            if (context.units.isImperial)
              ProfileRuler(
                key: const ValueKey('weightKg-imperial'),
                compact: compact,
                label: '体重',
                unit: 'lb',
                value: context.units
                    .bodyWeightValue(profile['weightKg'] as num)
                    .clamp(67, 551)
                    .toDouble(),
                min: 67,
                max: 551,
                step: .1,
                onChanged: (v) =>
                    onChanged('weightKg', context.units.bodyWeightToKg(v)),
              )
            else
              ProfileRuler(
                key: const ValueKey('weightKg'),
                compact: compact,
                label: '体重',
                unit: 'kg',
                value: (profile['weightKg'] as num).toDouble(),
                min: 30,
                max: 250,
                step: .1,
                onChanged: (v) => onChanged('weightKg', v),
              ),
          ],
        ),
      ),
    ],
  );
}

class ConditionsStep extends StatefulWidget {
  const ConditionsStep({
    super.key,
    required this.profile,
    required this.onChanged,
    this.embedded = false,
  });
  final bool embedded;
  final Profile profile;
  final ProfileChange onChanged;

  @override
  State<ConditionsStep> createState() => _ConditionsStepState();
}

class _ConditionsStepState extends State<ConditionsStep> {
  bool _more = false;
  Widget _choices(
    BuildContext context,
    String title,
    String field,
    Map<String, String> choices, {
    bool grid = false,
  }) {
    final entries = choices.entries.toList();
    Widget row(List<MapEntry<String, String>> items) => Row(
      children: [
        for (final (i, entry) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: OnboardingButton(
              label: entry.value,
              compact: true,
              selected: '${widget.profile[field]}' == entry.key,
              onTap: () => widget.onChanged(
                field,
                field == 'daysPerWeek' ? int.parse(entry.key) : entry.key,
              ),
            ),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText(title, style: AppText.hint(context.pal)),
        const SizedBox(height: 6),
        if (grid) ...[
          row(entries.take(2).toList()),
          const SizedBox(height: 6),
          row(entries.skip(2).toList()),
        ] else
          row(entries),
      ],
    );
  }

  Widget _venueChoices(BuildContext context) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText('你主要在哪练？', style: AppText.hint(p)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, option) in const [
              ('bodyweight', '在家 · 无哑铃', '在家\n无哑铃', 'full'),
              ('dumbbell', '在家 · 有哑铃', '在家\n有哑铃', 'train'),
              ('gym', '健身房', '健身房', 'train'),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      button: true,
                      selected: widget.profile['venue'] == option.$1,
                      label: AppMessages.of(context).text(option.$2),
                      excludeSemantics: true,
                      child: Pressable(
                        haptic: widget.profile['venue'] != option.$1,
                        onTap: () => widget.onChanged('venue', option.$1),
                        child: Container(
                          height: 76,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.profile['venue'] == option.$1
                                ? p.primary
                                : p.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.profile['venue'] == option.$1
                                  ? p.primary
                                  : p.sep,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(
                                option.$4,
                                size: 20,
                                color: widget.profile['venue'] == option.$1
                                    ? p.onPrimary
                                    : p.text,
                              ),
                              const SizedBox(height: 4),
                              LText(
                                option.$3,
                                textAlign: TextAlign.center,
                                style: AppText.hint(p).copyWith(
                                  color: widget.profile['venue'] == option.$1
                                      ? p.onPrimary
                                      : p.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        LText(
          '无哑铃也能练：徒手、背包、弹力带',
          style: AppText.hint(p).copyWith(fontSize: 12),
        ),
        Semantics(
          button: true,
          selected: widget.profile['venue'] == 'both',
          label: AppMessages.of(context).text('两边都会去'),
          excludeSemantics: true,
          child: Pressable(
            haptic: widget.profile['venue'] != 'both',
            onTap: () => widget.onChanged('venue', 'both'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: LText(
                widget.profile['venue'] == 'both' ? '✓ 两边都会去' : '两边都会去 ›',
                style: AppText.hint(p).copyWith(
                  color: widget.profile['venue'] == 'both'
                      ? p.text
                      : p.secondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingPage(
    embedded: widget.embedded,
    dense: true,
    title: '训练安排',
    subtitle: '能坚持的安排，就是好的开始。',
    children: [
      _venueChoices(context),
      _choices(context, '每周几天', 'daysPerWeek', const {
        '2': '2 天',
        '3': '3 天',
        '4': '4 天',
        '5': '5 天',
        '6': '6 天',
      }),
      _choices(context, '经验', 'experience', const {
        'new': '新手',
        'some': '练过一阵',
        'trained': '规律训练',
      }),
      OnboardingButton(
        label: _more ? '收起更多设置' : '更多设置 ›',
        textOnly: true,
        onTap: () => setState(() => _more = !_more),
      ),
      Reveal(
        visible: _more,
        child: _more
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _choices(context, '活动量', 'activity', const {
                    'sedentary': '久坐',
                    'light': '轻度',
                    'active': '常走动',
                  }),
                  LText('不方便的部位', style: AppText.hint(context.pal)),
                  Row(
                    children: [
                      for (final (i, part) in [
                        '膝',
                        '腰',
                        '肩',
                        '腕',
                        '无',
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: OnboardingButton(
                            label: part,
                            toggleable: part != '无',
                            compact: true,
                            selected: part == '无'
                                ? (widget.profile['limits'] as List).isEmpty
                                : (widget.profile['limits'] as List).contains(
                                    part,
                                  ),
                            onTap: () {
                              final limits = List<String>.from(
                                widget.profile['limits'] as List,
                              );
                              if (part == '无') {
                                limits.clear();
                              } else if (!limits.remove(part)) {
                                limits.add(part);
                              }
                              widget.onChanged('limits', limits);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}

/// 引导第一步里的小分段：公制 / 英制。选择立即生效并存进设置。
/// 放在「年龄」标题行右侧，不单独占行。
class UnitSwitch extends StatelessWidget {
  const UnitSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal, imperial = context.units.isImperial;
    Widget option(String label, bool selected, Units units) => Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        haptic: !selected,
        onTap: selected ? null : () => context.app.setUnits(units),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.primary : p.fill2.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LText(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? p.onPrimary : p.secondary,
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.fill2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option('kg · cm', !imperial, Units.metric),
            option('lb · ft in', imperial, Units.imperial),
          ],
        ),
      ),
    );
  }
}
