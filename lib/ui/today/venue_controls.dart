import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../kit/pressable.dart';
import '../kit/app_icon.dart';
import '../kit/sheet.dart';

/// The visible chip stays compact; padding keeps its touch target at 44 points.
class VenueChip extends StatelessWidget {
  const VenueChip({super.key, required this.gym, required this.onTap});
  final bool gym;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: '今天在哪练，当前${gym ? '健身房' : '居家'}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: p.fill2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gym ? '健身房' : '居家',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(width: 4),
                AppIcon('sync', size: 12, color: p.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Local confirm because the shared confirm API has a fixed “取消” label.
Future<bool?> showVenueDefaultConfirm(
  BuildContext context, {
  required String title,
}) => showSheetPanel<bool>(context, (context) {
  final p = context.pal;
  Widget action(String label, bool value) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Pressable(
      onTap: () => SheetController.of(context).close(value),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: value ? p.tintPress : p.secondary,
          ),
        ),
      ),
    ),
  );
  return Padding(
    padding: EdgeInsets.fromLTRB(
      8,
      0,
      8,
      8 + MediaQuery.paddingOf(context).bottom,
    ),
    child: Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              '之后这天会默认用这个场地，你随时可以在今日页改。',
              textAlign: TextAlign.center,
              style: AppText.hint(p),
            ),
          ),
          Container(height: .5, color: p.sep),
          action('好', true),
          Container(height: .5, color: p.sep),
          action('不用', false),
        ],
      ),
    ),
  );
});
