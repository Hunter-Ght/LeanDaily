import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../domain/body.dart';
import '../../domain/plan_insight.dart';
import '../../domain/templates.dart';
import '../../theme/theme.dart';
import '../kit/plan_widgets.dart';
import '../kit/sheet.dart';
import 'onboarding_widgets.dart';
import 'profile_steps.dart';

class PlanStep extends StatefulWidget {
  const PlanStep({
    super.key,
    required this.profile,
    required this.upgrade,
    required this.selected,
    required this.onSelected,
    required this.onConfirm,
    this.onProfileChanged,
  });
  final ProfileChange? onProfileChanged;
  final Profile profile;
  final bool upgrade;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final VoidCallback onConfirm;
  @override
  State<PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends State<PlanStep> {
  String? _shown;
  PageController? _compare;
  @override
  void didUpdateWidget(PlanStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ([
      'venue',
      'experience',
      'daysPerWeek',
      'sex',
    ].any((key) => oldWidget.profile[key] != widget.profile[key])) {
      _shown = null;
    }
  }

  @override
  void dispose() {
    _compare?.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _profile => {
    ...widget.profile,
    'venue': widget.profile['venue'] ?? 'bodyweight',
  };
  Map<String, dynamic> _plan(Map<String, dynamic> t) =>
      buildPlan(t['id'] as String, profile: _profile);
  String get _venue => _profile['venue'] == 'gym' ? 'gym' : 'home';
  Future<void> _preview(Map<String, dynamic> t) => showAppSheet<void>(
    context,
    (panel) => AppSheet(
      title: '${t['name']}',
      padding: const EdgeInsets.all(16),
      footer: Padding(
        padding: const EdgeInsets.all(16),
        child: Builder(
          builder: (buttonContext) => OnboardingButton(
            label: '使用这个方案',
            primary: true,
            onTap: () {
              widget.onSelected(t['id'] as String);
              setState(() => _shown = t['id'] as String);
              SheetController.of(buttonContext).close();
            },
          ),
        ),
      ),
      child: PlanPreview(
        plan: _plan(t),
        tagline: t['tagline'] as String,
        venue: _venue,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final ranked = recommend(_profile, buildTargets(widget.profile));
    final options = [
      for (final r in ranked)
        templates.firstWhere((t) => t['id'] == r['templateId']),
    ];
    if (options.isEmpty) return const SizedBox.shrink();
    final main = options.firstWhere(
      (t) => t['id'] == (_shown ?? widget.selected),
      orElse: () => options.first,
    );
    final others = options.where((t) => t != main).toList();
    final limits = (widget.profile['limits'] as List? ?? []).cast<String>();
    return OnboardingPage(
      title: '训练安排',
      dense: true,
      subtitle: widget.upgrade ? '算好目标，保留你熟悉的训练安排。' : '按你的条件推荐，从适合的计划开始。',
      children: [
        if (widget.onProfileChanged != null)
          ConditionsStep(
            profile: widget.profile,
            onChanged: widget.onProfileChanged!,
            embedded: true,
          ),
        if (widget.upgrade)
          OnboardingButton(
            label: '保留我现有的计划',
            selected: widget.selected == null,
            onTap: () => widget.onSelected(null),
          ),
        if (limits.isNotEmpty)
          LText(
            '${limits.join('、')}不方便：模板尚未自动避开，请预览动作后按身体情况调整。',
            style: AppText.hint(context.pal),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: PlanCard(
            key: ValueKey('recommended-${main['id']}'),
            name: main['name'] as String,
            tagline: main['tagline'] as String,
            insight: planInsight(_plan(main), venue: _venue),
            size: PlanCardSize.large,
            selected: true,
            level: templateLevel(main),
            feature: main['feature'] as String?,
            reasons: matchReasons(_profile, main),
            footer: Row(
              children: [
                Expanded(
                  child: OnboardingButton(
                    label: '选这个方案',
                    selected: widget.selected == main['id'],
                    onTap: () => widget.onSelected(main['id'] as String),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OnboardingButton(
                    label: '预览每天练什么',
                    onTap: () => _preview(main),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (others.isNotEmpty) ...[
          LText('也适合你 · 左右滑动比较', style: AppText.hint(context.pal)),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: MediaQuery.textScalerOf(context).scale(220) + 65,
              child: PageView.builder(
                key: ValueKey(main['id']),
                controller: _compare ??= PageController(
                  viewportFraction: 312 / c.maxWidth,
                ),
                padEnds: false,
                itemCount: others.length,
                itemBuilder: (context, i) {
                  final t = others[i];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 8),
                      child: SizedBox(
                        width: 300,
                        child: PlanCard(
                          name: t['name'] as String,
                          tagline: t['tagline'] as String,
                          insight: planInsight(_plan(t), venue: _venue),
                          size: PlanCardSize.small,
                          feature: t['feature'] as String?,
                          level: templateLevel(t),
                          onTap: () {
                            widget.onSelected(t['id'] as String);
                            setState(() => _shown = t['id'] as String);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        SizedBox(height: 138 + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}
