import 'package:flutter/widgets.dart';

import '../kit/transitions.dart';

import '../../domain/body.dart';
import '../../app/routes.dart';
import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/app_icon.dart';
import 'onboarding_widgets.dart';
import 'ruler.dart';

typedef ProfileChange = void Function(String key, Object? value);

class IdentityStep extends StatelessWidget {
  const IdentityStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });
  final Profile profile;
  final ProfileChange onChanged;
  @override
  Widget build(BuildContext context) => OnboardingPage(
    title: '基本信息',
    subtitle: '从你的身体情况开始，找到适合你的节奏。',
    children: [
      Row(
        children: [
          for (final entry in const {'male': '男', 'female': '女'}.entries) ...[
            Expanded(
              child: Semantics(
                button: true,
                selected: profile['sex'] == entry.key,
                label: entry.value,
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
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
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
        child: Column(
          children: [
            for (final field in const [
              ('age', '年龄', '岁', 10.0, 90.0, 1.0),
              ('heightCm', '身高', 'cm', 120.0, 230.0, 1.0),
              ('weightKg', '体重', 'kg', 30.0, 250.0, .1),
            ]) ...[
              ProfileRuler(
                key: ValueKey(field.$1),
                label: field.$2,
                unit: field.$3,
                value: (profile[field.$1] as num).toDouble(),
                min: field.$4,
                max: field.$5,
                step: field.$6,
                onChanged: (v) => onChanged(field.$1, v),
              ),
              if (field.$1 != 'weightKg') const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('继续即表示你了解 ', style: AppText.hint(context.pal)),
          Semantics(
            button: true,
            label: '隐私政策',
            child: Pressable(
              onTap: () => openPrivacy(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                alignment: Alignment.center,
                child: Text('隐私政策 ›', style: AppText.hint(context.pal)),
              ),
            ),
          ),
        ],
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
        Text(title, style: AppText.hint(context.pal)),
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
        Text('你主要在哪练？', style: AppText.hint(p)),
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
                      label: option.$2,
                      excludeSemantics: true,
                      child: Pressable(
                        haptic: widget.profile['venue'] != option.$1,
                        onTap: () => widget.onChanged('venue', option.$1),
                        child: Container(
                          height: 76,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.profile['venue'] == option.$1
                                ? p.tintSoft
                                : p.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.profile['venue'] == option.$1
                                  ? p.tint
                                  : p.sep,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(option.$4, size: 20, color: p.text),
                              const SizedBox(height: 4),
                              Text(
                                option.$3,
                                textAlign: TextAlign.center,
                                style: AppText.hint(p).copyWith(
                                  color: p.text,
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
        Text('无哑铃也能练：徒手、背包、弹力带', style: AppText.hint(p).copyWith(fontSize: 12)),
        Semantics(
          button: true,
          selected: widget.profile['venue'] == 'both',
          label: '两边都会去',
          excludeSemantics: true,
          child: Pressable(
            haptic: widget.profile['venue'] != 'both',
            onTap: () => widget.onChanged('venue', 'both'),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.profile['venue'] == 'both' ? '✓ 两边都会去' : '两边都会去 ›',
                style: AppText.hint(p).copyWith(
                  color: widget.profile['venue'] == 'both'
                      ? p.tint
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
                  Text('不方便的部位', style: AppText.hint(context.pal)),
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
