import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/plan_insight.dart';
import '../../domain/templates.dart';
import '../kit/form.dart';
import '../kit/plan_widgets.dart';
import '../kit/sheet.dart';
import '../kit/transitions.dart';

/// Returning from preview preserves the catalog filters and scroll offset.
class TemplateBrowserSheet extends StatefulWidget {
  const TemplateBrowserSheet({super.key, this.beforeActivate});
  final Future<bool> Function()? beforeActivate;
  @override
  State<TemplateBrowserSheet> createState() => _TemplateBrowserSheetState();
}

class _TemplateBrowserSheetState extends State<TemplateBrowserSheet> {
  Map<String, dynamic>? _selected;
  int _days = 0, _place = 0;
  bool _busy = false;
  String _error = '';
  final PageStorageBucket _bucket = PageStorageBucket();
  Future<bool> _back() async {
    if (_busy) return false;
    if (_selected == null) return true;
    setState(() {
      _selected = null;
      _error = '';
    });
    return false;
  }

  Future<void> _add(bool activate) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final app = context.app;
    try {
      if (activate &&
          widget.beforeActivate != null &&
          !await widget.beforeActivate!()) {
        return;
      }
      if (!mounted) return;
      await app.addTemplatePlan(_selected!['id'] as String, activate: activate);
      app.toast.show(activate ? '已添加并使用' : '已添加计划');
      if (mounted) SheetController.of(context).close();
    } on Object catch (e) {
      if (mounted) setState(() => _error = AppController.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _plan(Map<String, dynamic> t) => buildPlan(
    t['id'] as String,
    profile: context.app.profile,
    startDate: context.app.today,
  );
  Widget _catalog() {
    final app = context.app;
    final ranked = app.profile == null
        ? <Map<String, dynamic>>[]
        : recommend(app.profile!, app.targets ?? {});
    final ids = ranked.map((r) => r['templateId']).toList();
    final sorted = [...templates]
      ..sort((a, b) {
        int rank(Map t) {
          final i = ids.indexOf(t['id']);
          return i < 0
              ? ids.length + templates.indexOf(t.cast<String, dynamic>())
              : i;
        }

        return rank(a).compareTo(rank(b));
      });
    final visible = sorted
        .where(
          (t) =>
              (_days == 0 ||
                  (_days == 5
                      ? (t['days'] as int) >= 5
                      : t['days'] == _days)) &&
              (_place == 0 ||
                  (_place == 2
                      ? (t['venues'] as List).contains('gym')
                      : (t['venues'] as List).any(
                          (v) => v == 'dumbbell' || v == 'bodyweight',
                        ))),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormLabel('每周几天'),
        FormSegments(
          labels: const ['全部', '2', '3', '4', '5+'],
          selected: const [0, 2, 3, 4, 5].indexOf(_days),
          onChanged: (i) => setState(() => _days = const [0, 2, 3, 4, 5][i]),
        ),
        const FormLabel('场地'),
        FormSegments(
          labels: const ['全部', '在家', '健身房'],
          selected: _place,
          onChanged: (i) => setState(() => _place = i),
        ),
        FadeSwitcher(
          child: Column(
            key: ValueKey('$_days:$_place'),
            children: [
              if (visible.isEmpty) const FormHint('没有符合筛选条件的模板'),
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final t = visible[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PlanCard(
                      name: t['name'] as String,
                      tagline: t['tagline'] as String,
                      insight: planInsight(
                        _plan(t),
                        venue: app.profile?['venue'] == 'gym' ? 'gym' : 'home',
                      ),
                      feature: t['feature'] as String?,
                      level: templateLevel(t),
                      onTap: () => setState(() => _selected = t),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _bucket,
    child: AppSheet(
      key: PageStorageKey(_selected == null ? 'catalog' : 'preview'),
      title: _selected == null ? '从模板添加' : '${_selected!['name']}',
      cancelLabel: _selected == null ? '取消' : '返回',
      confirmClose: _back,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      footer: _selected == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: FormButton(
                      '使用这个方案',
                      filled: true,
                      onTap: _busy ? null : () => _add(true),
                    ),
                  ),
                  Expanded(
                    child: FormButton(
                      '仅添加',
                      onTap: _busy ? null : () => _add(false),
                    ),
                  ),
                ],
              ),
            ),
      child: PushSwitcher(
        direction: _selected == null ? -1 : 1,
        child: KeyedSubtree(
          key: ValueKey(_selected?['id'] ?? 'catalog'),
          child: _selected == null
              ? _catalog()
              : Column(
                  children: [
                    PlanPreview(
                      plan: _plan(_selected!),
                      tagline: _selected!['tagline'] as String,
                      venue: context.app.profile?['venue'] == 'gym'
                          ? 'gym'
                          : 'home',
                    ),
                    if (_error.isNotEmpty) FormHint(_error, error: true),
                  ],
                ),
        ),
      ),
    ),
  );
}
