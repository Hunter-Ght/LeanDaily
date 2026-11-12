import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart';
import '../../domain/progress.dart';
import '../../theme/theme.dart';
import '../../l10n/app_messages.dart';
import '../kit/form.dart';
import '../kit/pressable.dart';
import '../kit/transitions.dart';
import '../share/share_data.dart';
import '../share/share_sheet.dart';

/// 本周回顾的内容：本周完成次数、近 4 周出勤、按肌肉的周组数对比上周与说明。
/// 外层标题由「坚持」里的可展开行提供。
class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key});
  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool expanded = false, hintOpen = false;
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final r = weeklyReview(
      app.plan,
      app.repo.allDays(),
      app.dayStates,
      app.today,
    );
    final share = WeekShare.build(
      app.repo.allDays().map((k, v) => MapEntry(k, jsonMap(v))),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${a['done']}', style: AppText.num(p, 40)),
            Text(
              ' / ${a['planned']} ',
              style: AppText.num(p, 20, color: p.secondary),
            ),
            LText('次训练', style: TextStyle(fontSize: 15, color: p.secondary)),
            const SizedBox(width: 12),
            Expanded(
              child: LText(
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
                    child: LText(
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
                                  child: ColoredBox(
                                    color: p.tertiary.withValues(alpha: .45),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: pct(g['week']),
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: p.tint,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                if (jsNumber(g['last']) > 0)
                                  Positioned(
                                    left: (box.maxWidth * pct(g['last']) - 1)
                                        .clamp(0, box.maxWidth - 2),
                                    width: 2,
                                    top: 0,
                                    bottom: 0,
                                    child: ColoredBox(color: p.secondary),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${g['week']}', style: AppText.num(p, 18)),
                              LText(
                                ' 组',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LText(
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
        const SizedBox(height: 4),
        LText(
          note,
          style: TextStyle(fontSize: 15, height: 1.45, color: p.text),
        ),
        Row(
          children: [
            Pressable(
              onTap: () => setState(() => hintOpen = !hintOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: LText(
                  hintOpen ? '收起说明' : '说明',
                  style: AppText.hint(p)
                      .copyWith(color: p.text, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Spacer(),
            if (share != null)
              Semantics(
                button: true,
                label: AppMessages.of(context).text('分享'),
                child: Pressable(
                  onTap: () => openShareSheet(context, share),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    alignment: Alignment.centerRight,
                    child: LText(
                      '分享',
                      style: AppText.hint(p)
                          .copyWith(color: p.text, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Reveal(
          visible: hintOpen,
          child: hintOpen
              ? LText(
                  '灰色区间是每周的参考范围（直接训练组数，一个动作的一组算一组），竖线是上周的组数。',
                  style: AppText.hint(p),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
