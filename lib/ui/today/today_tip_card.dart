import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import 'today_model.dart';

class TodayTipCard extends StatelessWidget {
  const TodayTipCard({
    super.key,
    required this.model,
    required this.heading,
    required this.body,
    required this.actions,
    this.good = false,
    this.warn = false,
    this.extra,
    this.priority = 3,
    this.content,
  });
  final TodayModel model;
  final String heading, body;
  final List<Widget> actions;
  final bool good, warn;
  final int priority;
  final Widget? extra, content;
  @override
  Widget build(BuildContext context) {
    if (content != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: content,
      );
    }
    Widget text(
      String s, {
      double size = 14,
      bool bold = false,
      Color? color,
      double height = 1.45,
    }) => Text(
      s,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        height: height,
        color: color ?? context.pal.secondary,
      ),
    );

    final p = context.pal;
    return Container(
      // 外层的 Reveal/FadeSwitcher 给的是松约束，必须显式撑满，否则卡片缩成内容宽度并居中。
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
        border: good || warn
            ? Border(left: BorderSide(color: warn ? p.err : p.ok, width: 4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(todayTipWording(heading), size: 16, bold: true, color: p.text),
          const SizedBox(height: 6),
          text(todayTipWording(body)),
          Reveal(
            visible: extra != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: extra ?? const SizedBox.shrink(),
            ),
          ),
          Reveal(
            visible: actions.isNotEmpty,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ),
        ],
      ),
    );
  }
}

/// 低调的一行提示：左边两行字，右边一个“记一次”小胶囊和一个关闭。用于体重提醒这类不紧急的事。
class TodayNudgeRow extends StatelessWidget {
  const TodayNudgeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });
  final String icon, title, subtitle, actionLabel;
  final VoidCallback onAction, onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 20, color: p.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: p.secondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: actionLabel,
            child: Pressable(
              onTap: onAction,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: p.tintSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.tintPress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: '先不',
            child: Pressable(
              onTap: onDismiss,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AppIcon('close', size: 16, color: p.tertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String todayTipWording(String value) => value
    .replaceAll('渐进升级', '可以加重量了')
    .replaceAll('刺激肌肉', '练到的肌肉')
    .replaceAll('刺激', '训练量')
    .replaceAll('不算失败', '按今天的状态练就好');
