import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/equipment.dart';
import '../../domain/guide.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/badge.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';
import '../kit/sheet.dart';
import 'train/controls.dart';
import 'train/exercise_info.dart';

/// 器械详情：上器械前先调好什么、这台器械能练的动作，点“记录这个动作”带回动作名。
class EquipmentSheet extends StatelessWidget {
  const EquipmentSheet({super.key, required this.equipment});
  final Equipment equipment;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = equipment;
    final app = context.app;
    final status = recoveryStatus(app);
    final recent = app.repo.recentByExercise();
    return AppSheet(
      title: e.name,
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (e.demo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: ColoredBox(
                  color: p.fill,
                  child: Image.asset(
                    frameAsset(e.demo!, 0),
                    fit: BoxFit.cover,
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    errorBuilder: (_, _, _) => Center(
                      child: ToneBadge.part(
                        partOfExercise(e.exercises.first),
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (e.setup.isNotEmpty) ...[
            _label(p, '上器械前先调好'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < e.setup.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: p.tint,
                              ),
                            ),
                          ),
                          Expanded(
                            child: LText(
                              e.setup[i],
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          _label(p, '能练的动作'),
          for (final name in e.exercises)
            _row(context, name, status, (recent['last'] as Map)[name] as Map?),
        ],
      ),
    );
  }

  Widget _label(AppPalette p, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: LText(text, style: AppText.hint(p)),
  );

  Widget _row(
    BuildContext context,
    String name,
    Map<String, dynamic> status,
    Map? last,
  ) {
    final p = context.pal;
    final part = partOfExercise(name);
    final info = exerciseInfo(AppMessages.of(context), status, name, part);
    final line = lastLineOf(last);
    return Container(
      key: ValueKey('equipment-exercise-$name'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseThumb(ex: {'name': name, 'part': part}, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      name,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (info.muscles.isNotEmpty)
                      LText(info.muscles, style: AppText.hint(p)),
                    if (info.ready != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RecoveryTag(info),
                        ),
                      ),
                    if (line.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: LText(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.hint(p),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 动作多的器械（龙门架有 7 个）不让每行都铺满大按钮。
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (guideFor({'name': name}) != null) ...[
                SheetButton('看示范', () => openGuide(context, name), soft: true),
                const SizedBox(width: 8),
              ],
              SheetButton(
                '记录这个动作',
                () => SheetController.of(context).close(name),
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 器械网格：按分类分区，手机 2 列，宽屏 3–4 列。
class EquipmentGrid extends StatelessWidget {
  const EquipmentGrid({super.key, required this.onOpen, this.owned = const {}});
  final ValueChanged<Equipment> onOpen;

  /// “我的健身房”的器械 id；非空时已有的排前面，没有的弱化但仍可点。
  final Set<String> owned;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth < 560 ? 2 : (box.maxWidth < 820 ? 3 : 4);
        const gap = 10.0;
        final width = (box.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final kind in equipmentKinds)
              if (equipmentList.any((e) => e.kind == kind)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: LText(kind, style: AppText.hint(p)),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final e in _ordered(kind))
                      SizedBox(
                        width: width,
                        child: owned.isEmpty || owned.contains(e.id)
                            ? _card(context, e)
                            : Opacity(opacity: 0.5, child: _card(context, e)),
                      ),
                  ],
                ),
              ],
          ],
        );
      },
    );
  }

  List<Equipment> _ordered(String kind) {
    final list = equipmentList.where((e) => e.kind == kind).toList();
    if (owned.isEmpty) return list;
    return [
      ...list.where((e) => owned.contains(e.id)),
      ...list.where((e) => !owned.contains(e.id)),
    ];
  }

  Widget _card(BuildContext context, Equipment e) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(e.name),
      child: Pressable(
        onTap: () => onOpen(e),
        child: Container(
          key: ValueKey('equipment-${e.id}'),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 3 / 2,
                child: ColoredBox(
                  color: p.fill,
                  child: e.demo == null
                      ? Center(
                          child: ToneBadge.part(
                            partOfExercise(e.exercises.first),
                            size: 44,
                          ),
                        )
                      : Image.asset(
                          frameAsset(e.demo!, 0),
                          fit: BoxFit.cover,
                          cacheWidth:
                              (320 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          errorBuilder: (_, _, _) => Center(
                            child: ToneBadge.part(
                              partOfExercise(e.exercises.first),
                              size: 44,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LText('${e.exercises.length} 个动作', style: AppText.hint(p)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
