import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// 外层已经有水平内边距的页面/弹层用它包住分组控件：卡片不再自带 16 的外边距，标题只缩进 4，
/// 这样分组卡和旁边的普通卡片左右对齐。
class GroupScope extends InheritedWidget {
  const GroupScope({super.key, required super.child});
  static bool flush(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupScope>() != null;
  @override
  bool updateShouldNotify(GroupScope oldWidget) => false;
}

/// iOS 分组列表：同一组的行放进一张圆角卡，行间用缩进细线分隔。
/// 取代“每行一个独立胶囊”的旧写法；数值用次要色，只有可操作的文字才用 tint。
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      GroupScope.flush(context) ? 4 : 20,
      22,
      GroupScope.flush(context) ? 0 : 16,
      6,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.pal.secondary,
      ),
    ),
  );
}

class GroupFooter extends StatelessWidget {
  const GroupFooter(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      GroupScope.flush(context) ? 4 : 20,
      8,
      GroupScope.flush(context) ? 0 : 16,
      0,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: context.pal.secondary,
      ),
    ),
  );
}

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: GroupScope.flush(context) ? 0 : 16,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(height: 0.5, color: p.sep),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 一行：左标题（可带彩色小图标块）、右次要色数值、可选箭头。onTap 为空则不可点。
class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.label,
    this.value,
    this.sub,
    this.icon,
    this.iconColor,
    this.onTap,
    this.chevron = true,
    this.trailing,
    this.accent = false,
    this.danger = false,
    this.semanticLabel,
  });
  final String label;
  final String? value;
  final String? sub; // 标题下方一行小字
  final String? icon; // AppIcon 名
  final Color? iconColor; // 图标块底色（图标本身是白色）
  final VoidCallback? onTap;
  final bool chevron;
  final Widget? trailing;
  final bool accent; // 标题用 tint（如“添加计划”这类动作行）
  final bool danger;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = danger
        ? p.err
        : accent
        ? p.tint
        : p.text;
    final main = Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor ?? p.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: AppIcon(icon!, size: 17, color: p.onTint),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 17, height: 1.25, color: color),
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub!,
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
        if (value != null)
          // 标题 Expanded 吃掉剩余宽度，值按自身宽度靠右；箭头因此总在右边缘。
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                value!,
                maxLines: 2,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.25,
                  color: p.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        if (onTap != null && chevron && trailing == null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AppIcon('right', size: 14, color: p.tertiary),
          ),
      ],
    );
    final padded = Container(
      constraints: BoxConstraints(minHeight: sub == null ? 48 : 58),
      padding: EdgeInsets.fromLTRB(16, 8, trailing == null ? 16 : 4, 8),
      child: main,
    );
    final Widget tappable = onTap == null
        ? padded
        : Semantics(
            button: true,
            excludeSemantics: true,
            label: semanticLabel ?? [label, ?value, ?sub].join(' '),
            child: Pressable(scale: 0.99, onTap: onTap, child: padded),
          );
    if (trailing == null) return tappable;
    // 尾部控件（如“更多”按钮）与主体并列，各自独立可点、独立出现在无障碍树里。
    return Row(
      children: [
        Expanded(child: tappable),
        Padding(padding: const EdgeInsets.only(right: 12), child: trailing),
      ],
    );
  }
}
