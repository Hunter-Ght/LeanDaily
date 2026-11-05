import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart' show openGuide;
import '../../domain/equipment.dart';
import '../../domain/guide.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/badge.dart';
import '../kit/exercise_demo.dart';
import '../kit/pressable.dart';
import 'train/controls.dart';
import 'train/exercise_info.dart';
import 'train/muscle_focus.dart';

/// 器械详情页（记一组弹层里的一页）：自动播放示范、动作选择片、练哪里、恢复、上次记录、上器械前先调好。
/// 当前选中的动作由上层持有，返回到这一页时不丢；“记录这个动作”按钮在上层的底部栏。
class EquipmentDetail extends StatelessWidget {
  const EquipmentDetail({
    super.key,
    required this.equipment,
    required this.selected,
    required this.onSelect,
  });
  final Equipment equipment;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, e = equipment;
    final app = context.app;
    final status = recoveryStatus(app);
    final last = (app.repo.recentByExercise()['last'] as Map)[selected] as Map?;
    final part = partOfExercise(selected);
    final info = exerciseInfo(AppMessages.of(context), status, selected, part);
    final line = lastLineOf(last);
    final hasGuide = guideFor({'name': selected}) != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final size = [
                box.maxWidth,
                420.0,
                MediaQuery.sizeOf(context).height * .42,
              ].reduce((a, b) => a < b ? a : b);
              return Center(
                child: hasGuide
                    ? ExerciseDemo(
                        key: const ValueKey('equipment-demo'),
                        ex: {'name': selected, 'part': part},
                        size: size,
                      )
                    : _NoDemo(part: part, size: size),
              );
            },
          ),
          if (e.exercises.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final name in e.exercises)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _chip(context, name, name == selected),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: LText(
              selected,
              key: const ValueKey('equipment-selected'),
              style: TextStyle(
                color: p.text,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (info.ready != null) RecoveryTag(info),
                if (hasGuide)
                  SheetButton(
                    '动作要点',
                    () => openGuide(context, selected),
                    soft: true,
                  ),
              ],
            ),
          ),
          if (line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: LText(line, maxLines: 2, style: AppText.hint(p)),
            ),
          _label(p, '练哪里'),
          MuscleFocusCard(name: selected, part: part),
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
        ],
      ),
    );
  }

  Widget _label(AppPalette p, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: LText(text, style: AppText.hint(p)),
  );

  Widget _chip(BuildContext context, String name, bool on) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: on,
      label: AppMessages.of(context).text(name),
      child: Pressable(
        onTap: () => onSelect(name),
        child: Container(
          key: ValueKey('equipment-exercise-$name'),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? p.tint : p.card,
            borderRadius: BorderRadius.circular(999),
          ),
          child: LText(
            name,
            style: TextStyle(
              color: on ? p.onTint : p.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 还没有示范动画的动作：部位图标加说明，不留空白。
class _NoDemo extends StatelessWidget {
  const _NoDemo({required this.part, required this.size});
  final String part;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      key: const ValueKey('equipment-no-demo'),
      width: size,
      height: size * 0.62,
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToneBadge.part(part, size: 56),
          const SizedBox(height: 10),
          LText('示范制作中', style: AppText.hint(p)),
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

  // 练哪些大肌群：“练：胸 · 肩”；有氧器械没有肌群，写动作数。
  Widget _trains(BuildContext context, Equipment e) {
    final p = context.pal;
    final messages = AppMessages.of(context);
    final groups = equipmentTrains(e);
    return LText(
      groups.isEmpty
          ? '${e.exercises.length} 个动作'
          : '${messages.text('练：')}${groups.map(messages.text).join(' · ')}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.hint(p),
    );
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
                    _trains(context, e),
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
