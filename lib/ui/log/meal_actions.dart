import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/foods.dart';
import '../../l10n/localized_text.dart';
import '../../l10n/app_messages.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import '../kit/grouped.dart';
import '../kit/sheet.dart';
import '../sheets/food/portion_panel.dart';

/// Primary meal actions stay ahead of the history on every date and screen size.
class MealActions extends StatefulWidget {
  const MealActions({super.key, required this.date});
  final String date;
  @override
  State<MealActions> createState() => _MealActionsState();
}

class _MealActionsState extends State<MealActions> {
  bool _saving = false, _hasKey = false;
  int? _lastTab;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_lastTab == app.tab) return;
    _lastTab = app.tab;
    if (app.tab != 1) return;
    app.native
        .secretsGet()
        .then((s) {
          if (mounted) setState(() => _hasKey = s.modelKey.isNotEmpty);
        })
        .catchError((Object _) {});
  }

  Future<void> _powder({bool adjust = false}) async {
    if (_saving) return;
    final app = context.app;
    final date = widget.date;
    setState(() => _saving = true);
    try {
      Map<String, dynamic>? entry;
      if (adjust) {
        entry = await showAppSheet<Map<String, dynamic>>(
          context,
          (_) => FoodPortionPanel(
            food: proteinPowderFood(
              (app.plan['protein'] as Map?)?['powder'] as Map?,
            ),
          ),
        );
        if (entry == null) return;
      }
      await app.addProteinPowder(date, entry: entry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final configured =
        _hasKey &&
        '${app.settings.value['model'] ?? ''}'.isNotEmpty &&
        '${app.settings.value['baseUrl'] ?? ''}'.isNotEmpty;
    final subtitle = configured ? '估算热量与蛋白质' : '未设置 AI，可先存照片';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GroupScope(
        child: GroupCard(
          children: [
            Semantics(
              button: true,
              excludeSemantics: true,
              label: [
                AppMessages.of(context).text('拍照记饮食'),
                'AI',
                AppMessages.of(context).text(subtitle),
              ].join(' · '),
              child: Pressable(
                onTap: () =>
                    openMealSheet(context, preset: {'date': widget.date}),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.tintSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: AppIcon('camera', size: 20, color: p.tint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 7,
                              runSpacing: 3,
                              children: [
                                LText(
                                  '拍照记饮食',
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: p.text,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.fill2,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'AI',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: p.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            LText(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: p.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppIcon('right', size: 14, color: p.tertiary),
                    ],
                  ),
                ),
              ),
            ),
            _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() => LayoutBuilder(
    builder: (context, box) {
      final p = context.pal;
      final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
      // Keep full-size labels readable when the effective column width is small.
      final stacked = box.maxWidth / textScale < 320;
      final powder = Row(
        children: [
          Expanded(
            child: _action(
              '加蛋白粉',
              'plus',
              _saving ? null : () => _powder(),
              saving: _saving,
            ),
          ),
          Semantics(
            button: true,
            enabled: !_saving,
            label: AppMessages.of(context).text('调整份量'),
            child: Pressable(
              onTap: _saving ? null : () => _powder(adjust: true),
              child: SizedBox(
                width: 44,
                height: 48,
                child: Center(
                  child: AppIcon('more', size: 16, color: p.secondary),
                ),
              ),
            ),
          ),
        ],
      );
      final search = _action(
        '搜索 / 手动',
        'search',
        () => openQuickFood(context, date: widget.date),
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            powder,
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Container(height: .5, color: p.sep),
            ),
            search,
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: powder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(width: .5, color: p.sep),
            ),
            Expanded(child: search),
          ],
        ),
      );
    },
  );

  Widget _action(
    String label,
    String icon,
    VoidCallback? onTap, {
    bool saving = false,
  }) {
    final p = context.pal;
    final shown = saving ? '记录中…' : label;
    return Semantics(
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label: AppMessages.of(context).text(shown),
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 16, color: p.secondary),
              const SizedBox(width: 6),
              Flexible(
                child: LText(
                  shown,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
