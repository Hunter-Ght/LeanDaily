import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

import '../../core/haptics.dart';
import '../../domain/calendar.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';

/// Horizontal paging switches weeks/months; dragging the date rows or the grab
/// bar vertically expands or collapses the calendar (the month title still
/// toggles it too). Browsing a page does not change the selected record day.
class RecordCalendar extends StatefulWidget {
  const RecordCalendar({
    super.key,
    required this.iso,
    required this.today,
    required this.marks,
    this.cardio,
    required this.progress,
    required this.persistent,
    required this.onPick,
    required this.onToggle,
    this.onDragUpdate,
    this.onDragEnd,
    this.header,
  });
  final String iso, today;

  /// 顶部一行（标题等）与星期标签之间插入的内容。
  final Widget? header;
  final Marks marks;

  /// 这天有有氧记录：另一种颜色（绿）的点，不冒充力量训练的橙点。
  final bool Function(String iso)? cardio;
  final AnimationController progress;
  final bool persistent;
  final ValueChanged<String> onPick;
  final VoidCallback onToggle;

  /// Vertical drag on the rows / grab bar: pixels moved, then fling velocity (px/s).
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;

  @override
  State<RecordCalendar> createState() => _RecordCalendarState();
}

class _RecordCalendarState extends State<RecordCalendar> {
  static const _base = '0001-01-01'; // Monday, proleptic Gregorian calendar.
  late PageController _weeks, _months;
  late int _week, _month;
  int weekIndex(String iso) =>
      daysApart(_base, mondayOf(iso)) ~/ weekLabels.length;
  int monthIndex(String iso) => monthsApart(_base, iso);
  String get _viewMonth => shiftMonth(_base, _month);

  @override
  void initState() {
    super.initState();
    _week = weekIndex(widget.iso);
    _month = monthIndex(widget.iso);
    _weeks = PageController(initialPage: _week, keepPage: false);
    _months = PageController(initialPage: _month, keepPage: false);
  }

  @override
  void didUpdateWidget(RecordCalendar old) {
    super.didUpdateWidget(old);
    if (old.iso != widget.iso) {
      _week = weekIndex(widget.iso);
      _month = monthIndex(widget.iso);
      if (_weeks.hasClients) {
        _weeks.jumpToPage(_week);
      } else {
        _weeks.dispose();
        _weeks = PageController(initialPage: _week, keepPage: false);
      }
      if (_months.hasClients) {
        _months.jumpToPage(_month);
      } else {
        _months.dispose();
        _months = PageController(initialPage: _month, keepPage: false);
      }
    }
  }

  @override
  void dispose() {
    _weeks.dispose();
    _months.dispose();
    super.dispose();
  }

  void _step(int direction, bool month) {
    final controller = month ? _months : _weeks;
    final index = month ? _month : _week;
    final last = month ? monthIndex(widget.today) : weekIndex(widget.today);
    final next = (index + direction).clamp(0, last);
    if (!controller.hasClients || next == index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(next);
    } else {
      controller.animateToPage(
        next,
        duration: Motion.calendarPageDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _row(List<DayCell> days) => SizedBox(
    height: Metrics.calRow,
    child: Row(
      children: [
        for (final day in days)
          Expanded(
            child: Semantics(
              button: true,
              selected: day.iso == widget.iso,
              enabled: !day.future,
              label: AppMessages.of(context).text(
                '${day.iso}${day.today ? '，今天' : ''}${day.train ? '，有训练' : ''}${widget.cardio?.call(day.iso) == true ? '，有有氧' : ''}${day.meal ? '，蛋白达标' : ''}',
              ),
              child: Pressable(
                scale: 1,
                onTap: day.future
                    ? null
                    : () {
                        if (day.iso != widget.iso) {
                          HapticScope.of(context)?.selection();
                        }
                        widget.onPick(day.iso);
                      },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      key: ValueKey('date-${day.iso}'),
                      width: Metrics.calNum + 4,
                      height: Metrics.calNum,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: day.iso == widget.iso
                            ? context.pal.primary
                            : null,
                        border: day.today && day.iso != widget.iso
                            ? Border.all(color: context.pal.primary, width: 1.5)
                            : null,
                      ),
                      child: LText(
                        '${day.num}',
                        style: AppText.num(
                          context.pal,
                          18,
                          weight: day.today ? FontWeight.w800 : FontWeight.w600,
                          color: day.iso == widget.iso
                              ? context.pal.onPrimary
                              : day.future || day.out
                              ? context.pal.tertiary
                              : context.pal.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: Metrics.segmentInset),
                    SizedBox(
                      height: Metrics.calDot,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (day.train) _dot(context.pal.tint),
                          if (widget.cardio?.call(day.iso) == true) ...[
                            if (day.train)
                              const SizedBox(width: Metrics.segmentInset),
                            _dot(context.pal.ok),
                          ],
                          if ((day.train ||
                                  widget.cardio?.call(day.iso) == true) &&
                              day.meal)
                            const SizedBox(width: Metrics.segmentInset),
                          if (day.meal) _dot(context.pal.protein),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dot(Color color) => Container(
    width: Metrics.calDot,
    height: Metrics.calDot,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// 小标题：展开月历时是月份；周历时是「月份 · 第几周」（含 1 号的那周算第 1 周）。
  Widget _caption(bool month, String title) {
    final style = AppText.calTitle(context.pal);
    if (month) return LText(title, style: style);
    final thursday = shiftDate(_base, _week * weekLabels.length + 3);
    final n =
        daysApart(mondayOf(monthStart(thursday)), mondayOf(thursday)) ~/ 7 + 1;
    return Row(
      children: [
        LText(title, style: style),
        Text(' · ', style: style),
        Flexible(child: LText('第 $n 周', maxLines: 1, style: style)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.progress,
    builder: (context, _) {
      final p = widget.persistent ? 1.0 : widget.progress.value.clamp(0.0, 1.0);
      final month = p > 0;
      final transitioning = !widget.persistent && p > 0 && p < 1;
      final index = month ? _month : _week;
      final last = month ? monthIndex(widget.today) : weekIndex(widget.today);
      final title = month
          ? monthTitle(_viewMonth)
          : monthTitle(shiftDate(_base, _week * weekLabels.length + 3));
      final grid = monthGrid(_viewMonth, widget.today);
      final topClip = month
          ? rowOf(grid, widget.iso) * Metrics.calRow * (1 - p)
          : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Metrics.calendarSidePad,
        ),
        child: Column(
          children: [
            SizedBox(
              height: Metrics.touchTarget,
              child: Row(
                children: [
                  Expanded(child: _caption(month, title)),
                  for (final direction in [-1, 1])
                    Semantics(
                      button: true,
                      enabled: direction < 0 ? index > 0 : index < last,
                      label: AppMessages.of(context).text(
                        month
                            ? (direction < 0 ? '上个月' : '下个月')
                            : (direction < 0 ? '上一周' : '下一周'),
                      ),
                      child: Pressable(
                        onTap:
                            transitioning ||
                                (direction < 0 ? index == 0 : index == last)
                            ? null
                            : () => _step(direction, month),
                        child: SizedBox.square(
                          dimension: Metrics.touchTarget,
                          child: Center(
                            child: AppIcon(
                              direction < 0 ? 'left' : 'right',
                              color:
                                  (direction < 0 ? index == 0 : index == last)
                                  ? context.pal.tertiary
                                  : context.pal.secondary,
                              size: Metrics.calendarArrowSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.header != null) widget.header!,
            SizedBox(
              height: Metrics.calLabels,
              child: Row(
                children: [
                  for (final label in weekLabels)
                    Expanded(
                      child: LText(
                        label,
                        textAlign: TextAlign.center,
                        style: AppText.calLabel(context.pal),
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: widget.persistent
                  ? null
                  : (d) => widget.onDragUpdate?.call(d.delta.dy),
              onVerticalDragEnd: widget.persistent
                  ? null
                  : (d) =>
                        widget.onDragEnd?.call(d.velocity.pixelsPerSecond.dy),
              child: Column(
                children: [
                  ClipRect(
                    child: SizedBox(
                      height: Metrics.calRow + Metrics.calExtra * p,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: Metrics.calRow + Metrics.calExtra,
                        child: Transform.translate(
                          offset: Offset(0, -topClip),
                          child: SizedBox(
                            height: month
                                ? Metrics.calRow + Metrics.calExtra
                                : Metrics.calRow,
                            child: PageView.builder(
                              key: ValueKey(
                                month ? 'month-pages' : 'week-pages',
                              ),
                              controller: month ? _months : _weeks,
                              physics: transitioning
                                  ? const NeverScrollableScrollPhysics()
                                  : const PageScrollPhysics(
                                      parent: ClampingScrollPhysics(),
                                    ),
                              itemCount: last + 1,
                              onPageChanged: (value) => setState(() {
                                // 只在手指翻页时震；点选日期带动的自动翻页不重复震。
                                if ((month ? _months : _weeks)
                                        .position
                                        .userScrollDirection !=
                                    ScrollDirection.idle) {
                                  HapticScope.of(context)?.selection();
                                }
                                if (month) {
                                  _month = value;
                                } else {
                                  _week = value;
                                }
                              }),
                              itemBuilder: (context, index) => month
                                  ? Column(
                                      children: monthGrid(
                                        shiftMonth(_base, index),
                                        widget.today,
                                        widget.marks,
                                      ).rows.map(_row).toList(),
                                    )
                                  : Align(
                                      alignment: Alignment.topCenter,
                                      child: _row(
                                        weekDays(
                                          shiftDate(
                                            _base,
                                            index * weekLabels.length,
                                          ),
                                          widget.today,
                                          widget.marks,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.persistent)
                    Pressable(
                      scale: 1,
                      onTap: widget.onToggle,
                      child: SizedBox(
                        height: Metrics.calGrab,
                        child: Center(
                          child: Container(
                            width: Metrics.calNum,
                            height: Metrics.calendarGrabHeight,
                            decoration: BoxDecoration(
                              color: context.pal.grab,
                              borderRadius: BorderRadius.circular(
                                Metrics.calendarGrabHeight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
