import 'package:flutter/widgets.dart';

import '../../domain/body.dart';
import '../kit/transitions.dart';
import '../plan/your_plan.dart';
import 'onboarding_widgets.dart';
import 'profile_steps.dart';

/// 引导最后一步：回答场地、经验、不方便的部位，下面是按回答生成的「你的方案」，
/// 可以直接在上面调整。升级的老用户默认保留现有的计划，也可以另外生成一份新的。
///
/// 配方和是否保留现有计划都由外层持有（见 `RecipeDraft`）。
class PlanStep extends StatelessWidget {
  const PlanStep({
    super.key,
    required this.upgrade,
    required this.recipe,
    required this.onRecipeChanged,
    this.profile,
    this.onProfileChanged,
    this.keepExisting = false,
    this.onKeepChanged,
  });
  final bool upgrade;

  /// 有 [profile] 和 [onProfileChanged] 时，顶部显示场地、经验、不方便部位的问题。
  final Profile? profile;
  final ProfileChange? onProfileChanged;
  final Map<String, dynamic> recipe;
  final ValueChanged<Map<String, dynamic>> onRecipeChanged;

  /// 升级时：true 保留现有的计划，不生成新方案。
  final bool keepExisting;
  final ValueChanged<bool>? onKeepChanged;

  @override
  Widget build(BuildContext context) {
    final showPlan = !upgrade || !keepExisting;
    return OnboardingPage(
      title: '训练安排',
      dense: true,
      subtitle: upgrade ? '算好目标，保留你熟悉的训练安排。' : '回答几个问题，生成适合你的方案。',
      children: [
        if (profile != null && onProfileChanged != null)
          ConditionsStep(
            profile: profile!,
            onChanged: onProfileChanged!,
            embedded: true,
          ),
        if (upgrade && onKeepChanged != null) ...[
          const SizedBox(height: 4),
          OnboardingButton(
            label: '保留我现有的计划',
            selected: keepExisting,
            onTap: () => onKeepChanged!(true),
          ),
          OnboardingButton(
            label: '按现在的情况生成新方案',
            selected: !keepExisting,
            onTap: () => onKeepChanged!(false),
          ),
        ],
        Reveal(
          visible: showPlan,
          child: showPlan
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: YourPlan(recipe: recipe, onChanged: onRecipeChanged),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
