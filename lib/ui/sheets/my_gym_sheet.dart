import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/equipment.dart';
import '../../domain/guide.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/badge.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';

/// 我的健身房：勾选常去的健身房有的器械；一台都不勾表示不限。
class MyGymSheet extends StatefulWidget {
  const MyGymSheet({super.key});
  @override
  State<MyGymSheet> createState() => _MyGymSheetState();
}

class _MyGymSheetState extends State<MyGymSheet> {
  Set<String>? _ids;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final app = context.app;
    await app.saveMyGym(_ids ?? app.myGym);
    if (mounted) SheetController.of(context).close();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ids = _ids ??= Set.of(context.app.myGym);
    return AppSheet(
      title: '我的健身房',
      onSave: _save,
      saveEnabled: !_saving,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText('勾选你常去的健身房有的器械。不勾选任何器械表示不限。', style: AppText.hint(p)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SheetButton(
                  '全选',
                  () => setState(
                    () => ids.addAll(equipmentList.map((e) => e.id)),
                  ),
                  soft: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SheetButton('清空', () => setState(ids.clear), soft: true),
              ),
            ],
          ),
          for (final kind in equipmentKinds)
            if (equipmentList.any((e) => e.kind == kind)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: LText(kind, style: AppText.hint(p)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final e in equipmentList.where((e) => e.kind == kind))
                      _row(context, e, ids),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Equipment e, Set<String> ids) {
    final p = context.pal;
    final on = ids.contains(e.id);
    Widget fallback() => Center(
      child: ToneBadge.part(partOfExercise(e.exercises.first), size: 44),
    );
    return Semantics(
      button: true,
      toggled: on,
      label: AppMessages.of(context).text(e.name),
      child: Pressable(
        onTap: () => setState(() => on ? ids.remove(e.id) : ids.add(e.id)),
        child: Container(
          key: ValueKey('gym-${e.id}'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 44,
                  child: ColoredBox(
                    color: p.fill,
                    child: e.demo == null
                        ? fallback()
                        : Image.asset(
                            frameAsset(e.demo!, 0),
                            fit: BoxFit.cover,
                            cacheWidth:
                                (88 * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            errorBuilder: (_, _, _) => fallback(),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LText(
                  e.name,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: on ? p.tint : p.fill,
                  shape: BoxShape.circle,
                ),
                child: on
                    ? Center(child: AppIcon('check', size: 16, color: p.onTint))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
