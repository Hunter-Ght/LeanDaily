import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart' show jsNumber;
import '../../core/haptics.dart';
import '../kit/pressable.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import 'record_calendar.dart';
import 'day_timeline.dart';
import 'log_add_menu.dart';
import '../kit/app_icon.dart';
import '../motion.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key, required this.wide, required this.two});
  final bool wide, two;
  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with TickerProviderStateMixin {
  AppController? controller;
  Set<String> knownIds = {};

  List<Map<String, dynamic>> lastAdd = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.app;
    if (controller == next) return;
    controller?.repo.removeListener(recordsChanged);
    controller = next;
    knownIds = (next.repo.state['sets'] as Map).keys.cast<String>().toSet();
    next.repo.addListener(recordsChanged);
  }

  void recordsChanged() {
    final rows = controller!.repo.state['sets'] as Map;
    final added = <Map<String, dynamic>>[
      for (final entry in rows.entries)
        if (!knownIds.contains(entry.key) &&
            (entry.value as Map)['deleted'] != true)
          Map<String, dynamic>.from(entry.value as Map),
    ];
    knownIds = rows.keys.cast<String>().toSet();
    if (added.isNotEmpty) {
      lastAdd = added;
    } else if (lastAdd.any(
      (s) => (rows[s['id']] as Map?)?['deleted'] == true,
    )) {
      lastAdd = [];
    }
    if (mounted) setState(() {});
  }

  String get iso => context.app.date;
  late final AnimationController expansion = AnimationController.unbounded(
    vsync: this,
  );
  final Map<String, ScrollController> _scrolls = {};
  bool persistent = false, _calendarOpen = false;
  ScrollController get scroll =>
      _scrolls.putIfAbsent(iso, () => ScrollController());

  /// 周历小点：train=当天练了（橙点）；meal=当天蛋白达到目标（黄点）。
  ({bool train, bool meal}) marks(String date) {
    final app = context.app;
    final protein = (app.repo.meals(date)['meals'] as List).fold<num>(
      0,
      (v, m) => v + jsNumber((m as Map)['protein']).toDouble(),
    );
    return (
      train: app.repo.hasTrain(date),
      meal: protein > 0 && protein >= app.proteinGoal,
    );
  }

  @override
  void dispose() {
    controller?.repo.removeListener(recordsChanged);
    expansion.dispose();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void toggle() {
    _calendarOpen = !_calendarOpen;
    final target = _calendarOpen ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      expansion.value = target;
    } else {
      springTo(expansion, target);
    }
  }

  /// 手指拖动日历：展开程度跟手，松手后按速度和位置弹到展开或收起。
  void dragCalendar(double dy) {
    expansion
      ..stop()
      ..value = (expansion.value + dy / Metrics.calExtra).clamp(0.0, 1.0);
  }

  void releaseCalendar(double velocity) {
    final fraction = velocity / Metrics.calExtra; // 每秒展开比例
    final open = expansion.value + fraction * .2 > .5;
    if (open != _calendarOpen) HapticScope.of(context)?.selection();
    _calendarOpen = open;
    final target = open ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      expansion.value = target;
    } else {
      springTo(expansion, target, velocity: fraction);
    }
  }

  void pick(String date, {bool collapse = false}) {
    context.app.setDate(date);
    if (collapse && !persistent) {
      _calendarOpen = false;
      if (MediaQuery.disableAnimationsOf(context)) {
        expansion.value = 0;
      } else {
        springTo(expansion, 0);
      }
    }
  }

  Widget pill(
    String label,
    String semantics,
    VoidCallback onTap, {
    bool on = false,
    String? key,
  }) {
    final p = context.pal;
    return Semantics(
      button: true,
      excludeSemantics: true,
      selected: on,
      label: AppMessages.of(context).text(semantics),
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          height: Metrics.touchTarget,
          child: Center(
            child: Container(
              key: key == null ? null : ValueKey(key),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              constraints: const BoxConstraints(minHeight: 34),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? p.primary : p.fill2,
                borderRadius: BorderRadius.circular(17),
              ),
              child: LText(
                label,
                style: AppText.navWeek(p)
                    .copyWith(color: on ? p.onPrimary : p.text),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 页面主标题：当前选中的日期；右侧「回到今天」和（手机上的）月历按钮。
  Widget hero() {
    final date = DateTime.parse(iso);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: LText(
              '${date.month}月${date.day}日',
              key: const ValueKey('record-date'),
              maxLines: 1,
              style: AppText.display(context.pal, size: 34),
            ),
          ),
        ),
        if (iso != context.app.today) ...[
          pill('回到今天', '回到今天', () => pick(context.app.today, collapse: true)),
        ],
        if (!persistent) ...[
          const SizedBox(width: 8),
          pill(
            '月历',
            _calendarOpen ? '收起月历' : '展开月历',
            toggle,
            on: _calendarOpen,
          ),
        ],
      ],
    );
  }

  Widget calendar() => RecordCalendar(
    iso: iso,
    today: context.app.today,
    marks: marks,
    progress: expansion,
    persistent: persistent,
    onPick: (date) => pick(date, collapse: true),
    onToggle: toggle,
    onDragUpdate: dragCalendar,
    onDragEnd: releaseCalendar,
    header: hero(),
  );

  /// 右下角墨色加号：所有新增入口都在这里。
  Widget addButton(double bottom) {
    final p = context.pal;
    return Positioned(
      right: widget.wide ? 24 : 18,
      bottom: bottom,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: AppMessages.of(context).text('添加记录'),
        child: Pressable(
          onTap: () => openLogAddMenu(context, iso),
          child: Container(
            key: const ValueKey('log-add'),
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AppIcon('plus', size: 26, color: p.onPrimary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([context.app, context.app.rest]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final screen = MediaQuery.sizeOf(context);
        persistent =
            screen.width >= Metrics.twoBreakpoint &&
            screen.height >= Metrics.minTallForWide;
        final top = Metrics.navBarHeight + MediaQuery.paddingOf(context).top;
        final dayContent = KeyedSubtree(
          key: const ValueKey('day-pager'),
          child: DayTimeline(
            key: PageStorageKey(iso),
            iso: iso,
            scrollController: scroll,
            lastAdd: lastAdd.isNotEmpty && lastAdd.first['date'] == iso
                ? lastAdd
                : const [],
            bottomPadding:
                Metrics.dockHeight +
                (context.app.rest.active ? 72 : 0) +
                MediaQuery.paddingOf(context).bottom +
                56,
          ),
        );
        final body = Padding(
          padding: EdgeInsets.only(top: top),
          child: persistent
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: Metrics.persistentCalendarWidth,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [calendar()],
                        ),
                      ),
                    ),
                    Expanded(child: dayContent),
                  ],
                )
              : AnimatedBuilder(
                  animation: expansion,
                  child: dayContent,
                  builder: (context, child) => PopScope(
                    canPop: expansion.value <= 0,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) {
                        _calendarOpen = false;
                        springTo(expansion, 0);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Leave room for a usable timeline
                        // above the dock, even with large fonts or a short screen.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                (box.maxHeight -
                                        top -
                                        Metrics.dockHeight -
                                        MediaQuery.paddingOf(context).bottom -
                                        Metrics.touchTarget * 2)
                                    .clamp(0.0, double.infinity),
                          ),
                          child: SingleChildScrollView(
                            key: const ValueKey('record-header-scroll'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [calendar()],
                            ),
                          ),
                        ),
                        Expanded(child: child!),
                      ],
                    ),
                  ),
                ),
        );
        final bottom = MediaQuery.paddingOf(context).bottom;
        return Stack(
          children: [
            Positioned.fill(child: body),
            addButton(
              widget.wide
                  ? 24 + bottom
                  : Metrics.dockHeight +
                        bottom +
                        14 +
                        (context.app.rest.active ? 72 : 0),
            ),
          ],
        );
      },
    ),
  );
}
