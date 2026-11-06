import '../../l10n/localized_text.dart';
import '../../core/haptics.dart';

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'app_icon.dart';
import 'pressable.dart';
import 'sheet.dart';

/// 动作菜单项。
class MenuAction {
  const MenuAction({
    required this.id,
    required this.label,
    this.icon,
    this.detail,
    this.group,
    this.effort = false,
    this.danger = false,
    this.enabled = true,
  });
  final String id;
  final String label;
  final String? icon;

  /// 标题下一行小字说明（可选）。
  final String? detail;

  /// 分组名：相邻同组的项归在一个小标题下（如「训练」「饮食」）。
  final String? group;

  /// 训练类动作：图标块用发力橙，其余一律中性。
  final bool effort;
  final bool danger;

  /// 为 false 时置灰且点不动（原因请写进菜单的 message）。
  final bool enabled;
}

/// 底部动作菜单。返回被点的项；点遮罩或“取消”返回 null。
Future<MenuAction?> showActionMenu(
  BuildContext context, {
  String? title,
  String? message,
  required List<MenuAction> actions,
}) {
  HapticScope.of(context)?.selection();
  return showSheetPanel<MenuAction>(
    context,
    (_) => _MenuPanel(title: title, message: message, actions: actions),
  );
}

/// 确认框：返回 true 表示确认。
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirm = '确定',
  bool danger = false,
}) async {
  HapticScope.of(context)?.selection();
  final r = await showSheetPanel<bool>(
    context,
    (_) => _ConfirmPanel(
      title: title,
      message: message,
      confirm: confirm,
      danger: danger,
    ),
  );
  return r ?? false;
}

/// 菜单和确认框共用的底板：一张贴底大圆角卡，抓手在上。
class _Panel extends StatelessWidget {
  const _Panel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: p.shadow.withValues(alpha: p.shadow.a * 2),
              blurRadius: 40,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.grab,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板底部的整宽按钮：[ink] 墨色主按钮、[danger] 红色、否则中性浅底。
class _PanelButton extends StatelessWidget {
  const _PanelButton(
    this.label, {
    required this.onTap,
    this.ink = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool ink, danger;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: danger
                ? p.err
                : ink
                ? p.primary
                : p.fill2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: LText(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: danger
                  ? p.onTint
                  : ink
                  ? p.onPrimary
                  : p.text,
            ),
          ),
        ),
      ),
    );
  }
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
    final rows = <Widget>[];
    String? group;
    for (final a in actions) {
      if (a.group != null && a.group != group) {
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(24, rows.isEmpty ? 4 : 14, 24, 4),
            child: LText(
              a.group!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.secondary,
              ),
            ),
          ),
        );
      }
      group = a.group;
      rows.add(_Row(action: a, onTap: a.enabled ? () => ctl.close(a) : null));
    }
    return _Panel(
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: LText(title!, style: AppText.title(p)),
          ),
        if (message != null)
          Padding(
            padding: EdgeInsets.fromLTRB(24, title == null ? 12 : 6, 24, 0),
            child: LText(
              message!,
              style: TextStyle(fontSize: 14, height: 1.4, color: p.secondary),
            ),
          ),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _PanelButton('取消', onTap: ctl.requestClose),
        ),
      ],
    );
  }
}

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({
    required this.title,
    this.message,
    required this.confirm,
    required this.danger,
  });
  final String title;
  final String? message;
  final String confirm;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ctl = SheetController.of(context);
    return _Panel(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: LText(title, style: AppText.title(p)),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: LText(
              message!,
              style: TextStyle(fontSize: 15, height: 1.45, color: p.secondary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Row(
            children: [
              Expanded(child: _PanelButton('取消', onTap: ctl.requestClose)),
              const SizedBox(width: 10),
              Expanded(
                child: _PanelButton(
                  confirm,
                  onTap: () => ctl.close(true),
                  ink: !danger,
                  danger: danger,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final a = action;
    final color = a.danger ? p.err : p.text;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: Opacity(
          opacity: a.enabled ? 1 : 0.4,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                if (a.icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: a.danger
                          ? p.err.withValues(alpha: .12)
                          : a.effort
                          ? p.tintSoft
                          : p.fill2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppIcon(
                      a.icon!,
                      size: 20,
                      color: a.danger
                          ? p.err
                          : a.effort
                          ? p.tint
                          : p.text,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LText(
                        a.label,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (a.detail != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: LText(
                            a.detail!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: p.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
