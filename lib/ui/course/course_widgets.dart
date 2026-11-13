import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/benchmarks.dart';
import '../../domain/course.dart';
import '../../domain/format.dart' show fmt, jsonRows;
import '../../domain/units.dart' show Units;
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import '../kit/units_scope.dart';
import '../today/today_widgets.dart' show TodayButton;
import 'benchmark_rows.dart';
import 'benchmark_sheet.dart';
import 'course_sheet.dart';

/// 今日页顶部的一行：「第 3 周 / 共 12 周 · 打底期」+ 12 格进度，点开路线弹层。
/// 要轻：没有底色、没有卡片。
class CourseLine extends StatelessWidget {
  const CourseLine({super.key, required this.state});
  final CourseState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final phase = state.phase;
    final label = phase == null
        ? '12 周课程已完成'
        : '第 ${state.week} 周 / 共 $courseWeeks 周 · ${coursePhaseNames[phase]}';
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        onTap: () => openCourseSheet(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Flexible(
                child: phase == null
                    ? LText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: LText(
                              '第 ${state.week} 周 / 共 $courseWeeks 周',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          LText(
                            coursePhaseNames[phase]!,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(fontSize: 15, color: p.secondary),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              _Ticks(state: state),
              const SizedBox(width: 6),
              AppIcon('right', size: 14, color: p.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 12 个小格：练完的周是绿色（坚持），现在这周是墨色，之后是浅灰。
class _Ticks extends StatelessWidget {
  const _Ticks({required this.state});
  final CourseState state;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 1; w <= courseWeeks; w++) ...[
          if (w > 1) const SizedBox(width: 2),
          Container(
            width: 3.5,
            height: 12,
            decoration: BoxDecoration(
              color: state.done || w < state.week
                  ? p.ok
                  : w == state.week
                  ? p.text
                  : p.fill2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

/// 阶段指引：一句话（余力说法），放在今日动作的标题下面。
class CoursePhaseTip extends StatelessWidget {
  const CoursePhaseTip({super.key, required this.phase});
  final CoursePhase phase;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LText(
        coursePhaseTips[phase]!,
        style: TextStyle(fontSize: 14, height: 1.45, color: p.secondary),
      ),
    );
  }
}

/// 第 1 周的「测个底」和第 12 周的「复测」小卡。
class CourseTestCard extends StatelessWidget {
  const CourseTestCard({super.key, required this.retest});
  final bool retest;
  @override
  Widget build(BuildContext context) {
    final p = context.pal, app = context.app;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            retest ? '12 周了，再测一次和第一次比比' : '花 3 分钟测个底，12 周后再比一次',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: p.text,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            retest ? '同样三项，数字只用来和自己比。' : '俯卧撑、平板支撑、拉的动作各测一次，做不了的项目直接跳过。',
            style: TextStyle(fontSize: 14, height: 1.45, color: p.secondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TodayButton(
                '现在测',
                ink: true,
                onTap: () => openBenchmarkSheet(context),
              ),
              TodayButton(
                '先不',
                soft: true,
                onTap: () => app.dismissCourseCard(retest ? 'retest' : 'intro'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 课程完成后的总结卡：练了几天、达标周数、小测试前后对比、进步最大的动作。
class CourseSummaryCard extends StatelessWidget {
  const CourseSummaryCard({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal, app = context.app, units = context.units;
    final summary = app.courseSummaryNow();
    if (summary == null) return const SizedBox.shrink();
    final start = app.course!['start'] as String;
    final rows = benchmarkRows(benchmarksSince(app.benchmarkEntries, start));
    final top = jsonRows(summary['top']);
    Widget stat(Object value, String unit, String caption) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$value', style: AppText.num(p, 32)),
            const SizedBox(width: 3),
            LText(unit, style: TextStyle(fontSize: 14, color: p.secondary)),
          ],
        ),
        const SizedBox(height: 2),
        LText(caption, style: TextStyle(fontSize: 13, color: p.secondary)),
      ],
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LText(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: p.ok, shape: BoxShape.circle),
                child: Center(child: AppIcon('check', size: 13, color: p.bg)),
              ),
              Expanded(child: LText('12 周课程完成了', style: AppText.title(p))),
              Semantics(
                button: true,
                label: AppMessages.of(context).text('关闭'),
                child: Pressable(
                  onTap: () => app.dismissCourseCard('summary'),
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
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                stat(summary['days'] as num, '天', '12 周里练了'),
                stat(summary['hitWeeks'] as num, '个整周', '练满了计划的天数'),
              ],
            ),
          ),
          if (rows.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: heading('小测试'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: BenchmarkRows(rows: rows),
            ),
          ],
          if (top.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: heading('进步最多的动作'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: LText('带重量的动作按估算极限比较，自重动作比次数。', style: AppText.hint(p)),
            ),
            for (final t in top)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: LText(
                        '${t['name']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                        ),
                      ),
                    ),
                    Text(
                      _top(units, t, 'from'),
                      style: AppText.num(p, 20, color: p.secondary),
                    ),
                    const SizedBox(width: 6),
                    AppIcon('right', size: 14, color: p.tertiary),
                    const SizedBox(width: 6),
                    Text(_top(units, t, 'to'), style: AppText.num(p, 24)),
                    const SizedBox(width: 4),
                    LText(switch (t['kind']) {
                      'weight' => units.weightUnit,
                      'sec' => '秒',
                      _ => '次',
                    }, style: TextStyle(fontSize: 13, color: p.secondary)),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 8, 0),
            child: TodayButton(
              '再来一轮',
              ink: true,
              onTap: () async {
                await app.restartCourse();
                app.toast.show('新一轮 12 周课程开始了');
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 带重量的动作按估算极限比较，显示时换算成当前单位。
  static String _top(Units units, Map<String, dynamic> t, String key) =>
      t['kind'] == 'weight' ? units.load(t[key] as num) : fmt(t[key]);
}
