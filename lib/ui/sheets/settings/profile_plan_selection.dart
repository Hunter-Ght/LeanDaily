import '../../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../../app/app_controller.dart';
import '../../../theme/theme.dart';
import '../../kit/form.dart';
import '../../onboarding/plan_step.dart';

/// Reuses onboarding's plan list with existing-plan protection. The assessment
/// is already saved, so choosing a template only adds it to the library.
class ProfilePlanSelection extends StatefulWidget {
  const ProfilePlanSelection({super.key});
  @override
  State<ProfilePlanSelection> createState() => _ProfilePlanSelectionState();
}

class _ProfilePlanSelectionState extends State<ProfilePlanSelection> {
  String? _selected;
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
      if (_selected != null) {
        await app.addTemplatePlan(_selected!, activate: false);
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  profile: context.app.profile!,
                  upgrade: true,
                  selected: _selected,
                  onSelected: (id) => setState(() => _selected = id),
                  onConfirm: _confirm,
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
                      : _selected == null
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
