import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/pressable.dart';
import 'today_model.dart';
import 'week_adherence.dart';
import 'workout_title.dart';
import 'today_widgets.dart';

class TodayWeekCard extends StatelessWidget {
  const TodayWeekCard({super.key, required this.model});
  final TodayModel model;

  @override
  Widget build(BuildContext context) {
    final m = model, p = context.pal;
    Widget text(
      String s, {
      double size = 14,
      bool bold = false,
      Color? color,
      double height = 1.45,
    }) => Text(
      s,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        height: height,
        color: color ?? context.pal.secondary,
      ),
    );
    Widget title(String s) =>
        text(s, size: 17, bold: true, color: context.pal.text);

    final adherence = weekAdherence(
      today: m.iso,
      history: m.history,
      savedDays: jsNumber(m.app.goals['weekDays']),
      planDays: jsonMap(m.app.plan['schedule']).length,
    );
    return TodayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: title(
                  '本周 ${adherence.count}/${fmt(adherence.target)} 天',
                ),
              ),
              if (adherence.streak > 0)
                text('连续 ${adherence.streak} 周', size: 13),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(box.maxWidth, 322),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in plan.weekPlan(
                      m.app.plan,
                      m.iso,
                      m.app.dayStates,
                      m.history,
                    ))
                      Expanded(
                        child: Semantics(
                          button: true,
                          label:
                              '预览 ${d['label']} ${workoutTitle('${d['name']}')}',
                          child: Pressable(
                            onTap: () => openDayPreview(context, '${d['iso']}'),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 64),
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: jsTruthy(d['today']) ? p.tintSoft : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  text(
                                    '${d['label']}',
                                    size: 12,
                                    color: jsTruthy(d['today'])
                                        ? p.text
                                        : p.secondary,
                                  ),
                                  SizedBox(
                                    height: 18,
                                    child: jsTruthy(d['done'])
                                        ? AppIcon(
                                            'check',
                                            size: 14,
                                            color: p.ok,
                                          )
                                        : text(
                                            d['kind'] == 'train' ? '●' : '·',
                                            size: 12,
                                            color: d['kind'] == 'rest'
                                                ? p.tertiary
                                                : p.tint,
                                          ),
                                  ),
                                  text(
                                    '${workoutTitle('${d['name']}')}${d['venue'] == 'gym' ? ' · 馆' : ''}',
                                    size: 12,
                                    height: 1.2,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
  }
}
