import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/goals.dart';
import '../../domain/format.dart' show fmt;
import '../kit/pressable.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../domain/calendar.dart';
import 'record_calendar.dart';
import 'day_cards.dart';
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
  ({bool train, bool meal}) marks(String date) => (
    train: context.app.repo.hasTrain(date),
    meal: context.app.repo.hasMeal(date),
  );

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

  Widget hero() {
    final date = DateTime.parse(iso);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.month}月${date.day}日',
                  key: const ValueKey('record-date'),
                  style: AppText.navDay(context.pal),
                ),
                const SizedBox(height: 2),
                Text(
                  '周${weekLabels[date.weekday - 1]}${iso == context.app.today ? ' · 今天' : ''}',
                  style: AppText.navWeek(context.pal)
                      .copyWith(height: AppText.body(context.pal).height),
                ),
              ],
            ),
          ),
          if (iso != context.app.today)
            Semantics(
              button: true,
              label: '回到今天',
              child: Pressable(
                onTap: () => pick(context.app.today, collapse: true),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  constraints: BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.pal.tintSoft,
                    borderRadius: BorderRadius.circular(Metrics.calRow),
                  ),
                  child: Text(
                    '回到今天',
                    style: AppText.navWeek(context.pal)
                        .copyWith(color: context.pal.tint),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget goal() {
    final count = weekDays(
      iso,
      context.app.today,
      marks,
    ).where((d) => d.train).length;
    final meals = (context.app.repo.meals(iso)['meals'] as List)
        .cast<Map<String, dynamic>>();
    final target = weekTargetFromHistory(
      context.app.goals['weekDays'] ?? 0,
      (context.app.plan['schedule'] as Map? ?? {}).length,
      context.app.repo.allDays(),
    );
    final kcal = meals.fold<num>(0, (v, m) => v + ((m['kcal'] as num?) ?? 0));
    final protein = meals.fold<num>(
      0,
      (v, m) => v + ((m['protein'] as num?) ?? 0),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, Metrics.pagePad, 0),
      child: Text(
        '本周 $count/${fmt(target)} 天${meals.isNotEmpty ? ' · ${kcal.round()} 千卡 · 蛋白 ${fmt(protein)} g' : ''}',
        style: AppText.weekGoal(context.pal)
            .copyWith(height: AppText.body(context.pal).height),
      ),
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
  );

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
          child: DayCards(
            key: PageStorageKey(iso),
            iso: iso,
            columns:
                screen.width >= Metrics.colsBreakpoint &&
                screen.height >= Metrics.minTallForWide,
            scrollController: scroll,
            lastAdd: lastAdd.isNotEmpty && lastAdd.first['date'] == iso
                ? lastAdd
                : const [],
            bottomPadding:
                Metrics.dockHeight +
                (context.app.rest.active ? 72 : 0) +
                MediaQuery.paddingOf(context).bottom,
          ),
        );
        return Padding(
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
                          children: [hero(), calendar(), goal()],
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
                        hero(),
                        calendar(),
                        goal(),
                        Expanded(child: child!),
                      ],
                    ),
                  ),
                ),
        );
      },
    ),
  );
}
