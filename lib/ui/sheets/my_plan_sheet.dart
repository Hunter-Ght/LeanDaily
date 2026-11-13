import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/plan_recipe.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/plan_widgets.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import '../kit/transitions.dart';
import '../plan/your_plan.dart';
import 'train/controls.dart';

/// 「我的方案」：当前方案是按配方生成的，就直接在上面调整；是老方案（模板、自建），
/// 先看概要，可以按现在的情况重新生成一份。切换、改名、复制、删除、从模板添加、
/// 编辑动作都留在「方案库」里。
class MyPlanSheet extends StatefulWidget {
  const MyPlanSheet({super.key});
  @override
  State<MyPlanSheet> createState() => _MyPlanSheetState();
}

class _MyPlanSheetState extends State<MyPlanSheet> {
  /// 用户改过的配方；null 表示还没改，显示当前方案自己的配方。
  Map<String, dynamic>? _draft;

  /// 老方案：已经点了「按我的情况重新生成」。
  bool _regenerate = false;
  bool _busy = false;

  Map<String, dynamic> _fresh(AppController app) =>
      defaultRecipe(app.profile ?? const {}, app.targets ?? const {});

  Future<void> _save(AppController app, bool hasRecipe) async {
    final recipe = _draft;
    if (_busy || recipe == null) return;
    setState(() => _busy = true);
    try {
      if (hasRecipe) {
        await app.applyRecipe(recipe);
        app.toast.show('方案已更新');
      } else {
        await app.addRecipePlan(recipe);
        app.toast.show('已添加并使用');
      }
      if (mounted) SheetController.of(context).close();
    } on Object catch (e) {
      app.toast.show(AppController.message(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLibrary() async {
    await openPlanEditor(context);
    // 在方案库里可能换了方案，这里的草稿不再对得上。
    if (mounted) {
      setState(() {
        _draft = null;
        _regenerate = false;
      });
    }
  }

  Widget _library(AppPalette p) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      children: [
        Container(height: .5, color: p.sep),
        Semantics(
          button: true,
          label: AppMessages.of(context).text('方案库'),
          excludeSemantics: true,
          child: Pressable(
            key: const ValueKey('my-plan-library'),
            onTap: _openLibrary,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: LText(
                      '方案库',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ),
                  AppIcon('right', size: 16, color: p.tertiary),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _footer(
    AppPalette p,
    String button,
    String note,
    bool visible,
    VoidCallback onTap,
  ) => Reveal(
    visible: visible,
    child: visible
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SheetButton(button, _busy ? null : onTap, ink: true),
                ),
                const SizedBox(height: 8),
                LText(
                  note,
                  textAlign: TextAlign.center,
                  style: AppText.hint(p),
                ),
              ],
            ),
          )
        : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.app,
    builder: (context, _) {
      final app = context.app, p = context.pal;
      final active = app.activeRecipe;
      final hasRecipe = active != null;
      final shown = _draft ?? active ?? _fresh(app);
      final dirty =
          _draft != null &&
          (!hasRecipe ||
              jsonEncode(normalizeRecipe(_draft!)) != jsonEncode(active));
      final showPlan = hasRecipe || _regenerate;
      final activeItem = app.plans
          .where((e) => e['id'] == app.activePlanId)
          .firstOrNull;
      final name = '${activeItem?['name'] ?? app.plan['name'] ?? '我的方案'}';
      return AppSheet(
        title: '我的方案',
        cancelLabel: '关闭',
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        footer: hasRecipe
            ? _footer(
                p,
                '更新方案',
                '训练记录不受影响，今天之后按新方案安排。',
                dirty,
                () => _save(app, true),
              )
            : _footer(
                p,
                '使用这个方案',
                '原来的方案会留在方案库里，随时可以换回去。',
                _regenerate,
                () => _save(app, false),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSwitcher(
              child: showPlan
                  ? YourPlan(
                      key: const ValueKey('my-plan-edit'),
                      recipe: shown,
                      onChanged: (next) => setState(() => _draft = next),
                    )
                  : Column(
                      key: const ValueKey('my-plan-legacy'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LText(name, style: AppText.display(p, size: 28)),
                        const SizedBox(height: 14),
                        SheetButton(
                          '按我的情况重新生成',
                          () => setState(() {
                            _regenerate = true;
                            _draft = _fresh(app);
                          }),
                          soft: true,
                        ),
                        const SizedBox(height: 20),
                        PlanPreview(
                          plan: Map<String, dynamic>.from(app.plan),
                          tagline: name,
                          venue: app.profile?['venue'] == 'gym'
                              ? 'gym'
                              : 'home',
                        ),
                      ],
                    ),
            ),
            _library(p),
          ],
        ),
      );
    },
  );
}
