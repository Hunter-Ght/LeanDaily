import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart';
import '../../domain/progress.dart';
import '../../theme/theme.dart';
import 'stat_widgets.dart';
import '../kit/form.dart';
import '../kit/transitions.dart';

class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key});
  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final r = weeklyReview(
      app.plan,
      app.repo.allDays(),
      app.dayStates,
      app.today,
    );
    final a = jsonMap(r['adherence']);
    final rows = jsonMap(r['groups']).values
        .map(jsonMap)
        .where(
          (g) =>
              jsNumber(g['band']['lo']) > 0 ||
              jsNumber(g['week']) > 0 ||
              jsNumber(g['last']) > 0,
        );
    final low = jsonRows(r['low']).take(2).map((g) => g['name']).join('、');
    final note = r['redFlag'] == true
        ? '最近标记过疼痛或状态很差，先不加量；持续不适请去看医生。'
        : jsNumber(a['planned']) >= 3 && jsNumber(a['rate']) < .6
        ? '最近出勤偏低：先把每周 3 次练稳，比加组数重要。'
        : low.isNotEmpty && weekNumber(app.plan, app.today) >= 2
        ? '$low上周偏少，如果有精力，可以把这些部位的动作优先做完。'
        : '节奏正常。继续把次数做稳，需要加量时「今日」页会给建议。';
    return StatBlock(
      title: '本周回顾',
      children: [
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text.rich(
              TextSpan(
                text: '${a['done']}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  letterSpacing: -.84,
                ),
                children: [
                  TextSpan(
                    text: ' / ${a['planned']} 次',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '近 4 周出勤${jsNumber(a['planned']) > 0 ? ' ${(jsNumber(a['rate']) * 100).round()}%' : '：还没到计划练的日子'}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final (index, g) in rows.indexed)
          Reveal(
            visible: expanded || index < 3,
            child: SizedBox(
              height: 38,
              child: Row(
                children: [
                  SizedBox(
                    width: 78.2, // .rv-list grid: 4.6em at the inherited 17px.
                    child: Text(
                      '${g['name']}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, box) {
                        final band = jsonMap(g['band']);
                        double pct(Object? v) =>
                            (jsNumber(v) / (jsNumber(band['hi']) + 2))
                                .clamp(0, 1)
                                .toDouble();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ColoredBox(color: p.fill),
                                ),
                                Positioned(
                                  left: box.maxWidth * pct(band['lo']),
                                  width:
                                      box.maxWidth *
                                      pct(
                                        jsNumber(band['hi']) -
                                            jsNumber(band['lo']),
                                      ),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p.tintSoft,
                                      border: Border.symmetric(
                                        vertical: BorderSide(
                                          color: p.tertiary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: pct(g['week']),
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color:
                                            jsNumber(g['week']) +
                                                    jsNumber(g['last']) >=
                                                jsNumber(band['lo'])
                                            ? p.ok
                                            : p.tertiary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 95.2, // .rv-list grid: 5.6em at the inherited 17px.
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${g['week']} 组',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                        ),
                        Text(
                          '上周 ${g['last']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (rows.length > 3)
          FormButton(
            expanded ? '收起' : '展开全部肌肉',
            plain: true,
            onTap: () => setState(() => expanded = !expanded),
          ),
        Text('浅色区间是每周的参考范围（直接训练组数，一个动作的一组算一组）。$note', style: AppText.hint(p)),
      ],
    );
  }
}
