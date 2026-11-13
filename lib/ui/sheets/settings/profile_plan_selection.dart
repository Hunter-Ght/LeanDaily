import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../app/app_controller.dart';
import '../../../domain/plan_recipe.dart';
import '../../../theme/theme.dart';
import '../../kit/form.dart';
import '../../onboarding/plan_step.dart';
import '../../plan/recipe_draft.dart';

/// Reuses onboarding's plan step with existing-plan protection. The assessment
/// is already saved, so a generated plan is only added to the library.
class ProfilePlanSelection extends StatefulWidget {
  const ProfilePlanSelection({super.key});
  @override
  State<ProfilePlanSelection> createState() => _ProfilePlanSelectionState();
}

class _ProfilePlanSelectionState extends State<ProfilePlanSelection> {
  final _draft = RecipeDraft();
  bool _keep = true;
  bool _busy = false;
  String _error = '';
  Future<void> _confirm() async {
    if (_busy) return;
    final app = context.app;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (!_keep) await app.addRecipePlan(_recipe, activate: false);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> get _base {
    final profile = context.app.profile!;
    return defaultRecipe(profile, context.app.targets ?? const {});
  }

  Map<String, dynamic> get _recipe => _draft.resolve(_base);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: ColoredBox(
      color: context.pal.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  FormButton(
                    '返回',
                    plain: true,
                    onTap: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: LText(
                      '选择计划',
                      textAlign: TextAlign.center,
                      style: AppText.h2(context.pal),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            if (_error.isNotEmpty) FormHint(_error, error: true),
            Expanded(
              child: AbsorbPointer(
                absorbing: _busy,
                child: PlanStep(
                  upgrade: true,
                  recipe: _recipe,
                  onRecipeChanged: (next) =>
                      setState(() => _draft.update(_base, next)),
                  keepExisting: _keep,
                  onKeepChanged: (v) => setState(() => _keep = v),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FormButton(
                  _busy
                      ? '正在保存…'
                      : _keep
                      ? '保留我现有的计划'
                      : '另外添加这个计划',
                  filled: true,
                  onTap: _busy ? null : _confirm,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
