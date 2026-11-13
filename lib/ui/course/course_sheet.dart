import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/course.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/grouped.dart';
import '../kit/sheet.dart';
import '../sheets/train/controls.dart' show SheetButton;
import 'benchmark_sheet.dart';

/// 课程路线弹层：四段路线的简图，标出现在在哪，每段一句话说明做什么、为什么。
Future<void> openCourseSheet(BuildContext context) =>
    showAppSheet<void>(context, (_) => const CourseSheet());

String coursePhaseWeeksLabel(CoursePhase phase) {
  final (from, to) = coursePhaseWeeks[phase]!;
  return from == to ? '第 $from 周' : '第 $from～$to 周';
}

class CourseSheet extends StatelessWidget {
  const CourseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final st = app.courseNow;
    if (st == null) return const AppSheet(title: '12 周课程', child: SizedBox());
    final current = st.phase;
    return AppSheet(
      title: '12 周课程',
      cancelLabel: '关闭',
      footer: st.done
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SheetButton('再来一轮', () async {
                await app.restartCourse();
                app.toast.show('新一轮 12 周课程开始了');
                if (context.mounted) SheetController.of(context).close();
              }, ink: true),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (st.done)
            LText('12 周完成了', style: AppText.display(p, size: 30))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${st.week}', style: AppText.num(p, 44)),
                const SizedBox(width: 6),
                LText(
                  '/ 12 周',
                  style: TextStyle(fontSize: 17, color: p.secondary),
                ),
              ],
            ),
          const SizedBox(height: 18),
          _RouteBar(state: st),
          const SizedBox(height: 18),
          for (final phase in CoursePhase.values)
            _PhaseRow(
              phase: phase,
              here: phase == current,
              passed: st.done || phase.index < (current?.index ?? 0),
            ),
          const SizedBox(height: 8),
          GroupCard(
            children: [
              GroupRow(
                label: '小测试',
                sub: '俯卧撑、平板支撑、拉的动作，随时可以测一次',
                icon: 'chart',
                onTap: () => openBenchmarkSheet(context),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: LText('按练了的周数算，中途停一两周也不会耗掉课程。', style: AppText.hint(p)),
          ),
        ],
      ),
    );
  }
}

/// 12 周分成四段的路线：练完的周是绿色，现在这一周是墨色，还没到的是浅灰。
class _RouteBar extends StatelessWidget {
  const _RouteBar({required this.state});
  final CourseState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color of(int week) => state.done || week < state.week
        ? p.ok
        : week == state.week
        ? p.text
        : p.fill2;
    return Semantics(
      container: true,
      label: '${state.week} / $courseWeeks',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (i, phase) in CoursePhase.values.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              flex:
                  coursePhaseWeeks[phase]!.$2 - coursePhaseWeeks[phase]!.$1 + 1,
              child: Row(
                children: [
                  for (
                    var w = coursePhaseWeeks[phase]!.$1;
                    w <= coursePhaseWeeks[phase]!.$2;
                    w++
                  ) ...[
                    if (w > coursePhaseWeeks[phase]!.$1)
                      const SizedBox(width: 3),
                    Expanded(
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: of(w),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.phase,
    required this.here,
    required this.passed,
  });
  final CoursePhase phase;
  final bool here, passed;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: here ? p.card : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1, right: 12),
            decoration: BoxDecoration(
              color: passed ? p.ok : (here ? p.text : null),
              shape: BoxShape.circle,
              border: passed || here
                  ? null
                  : Border.all(color: p.tertiary, width: 1.5),
            ),
            child: passed
                ? Center(child: AppIcon('check', size: 13, color: p.bg))
                : here
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: p.bg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: LText(
                        coursePhaseNames[phase]!,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    LText(
                      coursePhaseWeeksLabel(phase),
                      style: TextStyle(fontSize: 13, color: p.secondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LText(
                  coursePhaseDo[phase]!,
                  style: TextStyle(fontSize: 15, height: 1.4, color: p.text),
                ),
                const SizedBox(height: 2),
                LText(
                  coursePhaseWhy[phase]!,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: p.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
