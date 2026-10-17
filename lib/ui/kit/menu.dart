import '../../core/haptics.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'app_icon.dart';
import 'pressable.dart';
import 'sheet.dart';

/// 动作菜单项。
class MenuAction {
  const MenuAction({required this.id, required this.label, this.icon, this.danger = false, this.enabled = true});
  final String id;
  final String label;
  final String? icon;
  final bool danger;

  /// 为 false 时置灰且点不动（原因请写进菜单的 message）。
  final bool enabled;
}

/// 底部动作菜单。返回被点的项；点遮罩或“取消”返回 null。
Future<MenuAction?> showActionMenu(BuildContext context, {String? title, String? message, required List<MenuAction> actions}) {
  HapticScope.of(context)?.selection();
  return showSheetPanel<MenuAction>(context, (_) => _MenuPanel(title: title, message: message, actions: actions));
}

/// 确认框：返回 true 表示确认。
Future<bool> showConfirm(BuildContext context, {required String title, String? message, String confirm = '确定', bool danger = false}) async {
  final r = await showActionMenu(context, title: title, message: message, actions: [MenuAction(id: 'ok', label: confirm, danger: danger)]);
  return r?.id == 'ok';
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({this.title, this.message, required this.actions});
  final String? title;
  final String? message;
  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ctl = SheetController.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 7),
                  Container(width: 36, height: 5, decoration: BoxDecoration(color: p.grab, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 6),
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: Text(title!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.secondary)),
                    ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.35, color: p.secondary)),
                    ),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0 || title != null || message != null) Container(height: 0.5, color: p.sep),
                    _Row(action: actions[i], onTap: actions[i].enabled ? () => ctl.close(actions[i]) : null),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Pressable(
            onTap: ctl.requestClose,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
              child: Text('取消', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.tint)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.action, required this.onTap});
  final MenuAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = action.danger ? p.err : p.tint;
    return Pressable(
      onTap: onTap,
      scale: 1,
      dim: 0.55,
      child: Opacity(
        opacity: action.enabled ? 1 : 0.4,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[AppIcon(action.icon!, color: color, size: 18), const SizedBox(width: 8)],
              Text(action.label, style: TextStyle(fontSize: 20, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
