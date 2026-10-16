import 'package:flutter/widgets.dart';

import '../../../app/app_controller.dart';
import '../../../theme/theme.dart';
import '../../kit/form.dart';
import '../../kit/grouped.dart';
import '../../kit/plan_widgets.dart';
import '../../../domain/plan_insight.dart';
import '../../kit/menu.dart';
import '../../kit/pressable.dart';
import '../../kit/sheet.dart';
import '../../kit/transitions.dart';
import '../template_browser_sheet.dart';

/// Library actions persist immediately; the editor owns its separate draft.
class PlanLibrarySection extends StatefulWidget {
  const PlanLibrarySection({
    super.key,
    required this.beforeChange,
    required this.onPlanChanged,
  });
  final Future<bool> Function() beforeChange;
  final VoidCallback onPlanChanged;
  @override
  State<PlanLibrarySection> createState() => _PlanLibrarySectionState();
}

class _PlanLibrarySectionState extends State<PlanLibrarySection> {
  bool _busy = false;
  String _error = '';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _use(Map<String, dynamic> item) async {
    final app = context.app;
    if (item['id'] == app.activePlanId) return;
    if (!await showConfirm(
      context,
      title: '使用「${item['name']}」？',
      message: '切换后今日页按这个计划走，训练记录不受影响',
      confirm: '使用',
    )) {
      return;
    }
    if (!mounted || !await widget.beforeChange() || !mounted) return;
    await app.usePlan(item['id'] as String);
    if (mounted) widget.onPlanChanged();
  }

  Future<void> _menu(Map<String, dynamic> item) async {
    final app = context.app;
    final reason = app.plans.length <= 1
        ? '最后一个方案不能删除'
        : item['id'] == app.activePlanId
        ? '当前使用的方案不能删除，请先切换方案'
        : '';
    final action = await showSheetPanel<String>(
      context,
      (panel) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(panel).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel('${item['name']}'),
            for (final entry in {
              'rename': '重命名',
              'copy': '复制',
              'delete': '删除',
              if (app.hasLegacySnapshot) 'restore': '恢复到升级前的方案',
            }.entries)
              FormButton(
                entry.value,
                plain: true,
                danger: entry.key == 'delete' || entry.key == 'restore',
                onTap: entry.key == 'delete' && reason.isNotEmpty
                    ? null
                    : () => SheetController.of(panel).close(entry.key),
              ),
            if (reason.isNotEmpty) FormHint(reason),
            FormButton('取消', onTap: () => SheetController.of(panel).close()),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final id = item['id'] as String;
    switch (action) {
      case 'rename':
        final name = await showAppSheet<String>(
          context,
          (_) => _RenamePlanSheet(name: '${item['name']}'),
        );
        if (name != null) await app.renamePlan(id, name);
      case 'copy':
        await app.duplicatePlan(id);
      case 'delete':
        if (await showConfirm(
          context,
          title: '删除「${item['name']}」？',
          message: '训练记录不受影响。',
          confirm: '删除',
          danger: true,
        )) {
          await app.deletePlan(id);
        }
      case 'restore':
        if (!await showConfirm(
          context,
          title: '恢复到升级前的方案？',
          message: '恢复升级前的计划、训练进度和每日状态。训练记录不受影响。',
          confirm: '恢复',
          danger: true,
        )) {
          return;
        }
        if (!mounted || !await widget.beforeChange() || !mounted) return;
        await app.restoreLegacy();
        if (mounted) widget.onPlanChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.app,
    builder: (context, _) {
      final app = context.app, p = context.pal;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GroupHeader('我的计划'),
          GroupCard(
            children: [
              MotionList(
                children: [
                  for (final item in app.plans)
                    KeyedSubtree(
                      key: ValueKey(item['id']),
                      child: Column(
                        children: [
                          if (item != app.plans.first)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Container(height: .5, color: p.sep),
                            ),
                          GroupRow(
                            label: '${item['name']}',
                            value: item['id'] == app.activePlanId
                                ? '使用中'
                                : null,
                            semanticLabel: '使用方案：${item['name']}',
                            onTap: _busy ? null : () => _run(() => _use(item)),
                            trailing: Semantics(
                              button: true,
                              label: '${item['name']}的更多操作',
                              excludeSemantics: true,
                              child: Pressable(
                                onTap: _busy
                                    ? null
                                    : () => _run(() => _menu(item)),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Text(
                                      '…',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: p.secondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Builder(
                              builder: (context) {
                                final insight = planInsight(
                                  Map<String, dynamic>.from(
                                    item['plan'] as Map,
                                  ),
                                  venue: app.profile?['venue'] == 'gym'
                                      ? 'gym'
                                      : 'home',
                                );
                                return Row(
                                  children: [
                                    Expanded(
                                      child: WeekDots(
                                        week: insight['week'] as List,
                                        diameter: 18,
                                        showWeekdays: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '约 ${insight['minutes']} 分钟',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.secondary,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              GroupRow(
                label: '＋ 从模板添加',
                accent: true,
                onTap: _busy
                    ? null
                    : () => _run(() async {
                        final previous = app.activePlanId;
                        await showAppSheet<void>(
                          context,
                          (_) => TemplateBrowserSheet(
                            beforeActivate: widget.beforeChange,
                          ),
                        );
                        if (mounted && previous != app.activePlanId) {
                          widget.onPlanChanged();
                        }
                      }),
              ),
            ],
          ),
          if (_error.isNotEmpty) FormHint(_error, error: true),
        ],
      );
    },
  );
}

class _RenamePlanSheet extends StatefulWidget {
  const _RenamePlanSheet({required this.name});
  final String name;
  @override
  State<_RenamePlanSheet> createState() => _RenamePlanSheetState();
}

class _RenamePlanSheetState extends State<_RenamePlanSheet> {
  late String _name = widget.name;
  @override
  Widget build(BuildContext context) => AppSheet(
    title: '重命名',
    saveEnabled: _name.trim().isNotEmpty,
    onSave: () => SheetController.of(context).close(_name.trim()),
    padding: const EdgeInsets.all(16),
    child: FormInput(
      label: '方案名称',
      value: _name,
      boxed: true,
      align: TextAlign.left,
      maxLength: 40,
      onChanged: (v) => setState(() => _name = v),
    ),
  );
}
