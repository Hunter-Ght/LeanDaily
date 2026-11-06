import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';

/// 「我的」页的一行：单色线性图标 + 标题 + 次要色数值 + 箭头。
/// 取代带彩色方块图标的 GroupRow，行内结构与 GroupRow 保持一致，放进 GroupCard 使用。
class MeRow extends StatelessWidget {
  const MeRow({
    super.key,
    required this.label,
    required this.icon,
    this.value,
    this.sub,
    this.onTap,
  });
  final String label, icon;
  final String? value, sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final body = Container(
      constraints: BoxConstraints(minHeight: sub == null ? 50 : 60),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(width: 26, child: AppIcon(icon, size: 21, color: p.text)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LText(
                  label,
                  style: TextStyle(fontSize: 17, height: 1.25, color: p.text),
                ),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LText(sub!, style: AppText.hint(p)),
                  ),
              ],
            ),
          ),
          if (value != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.45,
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: LText(
                  value!,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    color: p.secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: AppIcon('right', size: 14, color: p.tertiary),
            ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [label, ?value, ?sub].map(AppMessages.of(context).text).join(' '),
      child: Pressable(scale: 0.99, onTap: onTap, child: body),
    );
  }
}
