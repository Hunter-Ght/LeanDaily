import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/format.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/pressable.dart';

String routeName(Object? stage) =>
    const {
      'cut': '减脂路线',
      'recomp': '重组路线',
      'trim': '微调路线',
      'refine': '精修路线',
      'bulk': '增肌路线',
      'youth': '成长期',
    }[stage] ??
    '你的路线';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app, p = context.pal;
    final profile = app.profile, t = app.targets;
    final weeks = t?['weeksRange'] as List?;
    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LText(
            profile == null ? '你的起点' : routeName(t?['stage']),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: p.text,
            ),
          ),
          const SizedBox(height: 10),
          LText(
            profile == null
                ? '填几个数字，得到适合你身材的计划和每日目标'
                : '体脂约 ${fmt((t?['bodyFat'] as Map?)?['value'])}% · 体重 ${fmt(profile['weightKg'])} kg${t?['stage'] == 'youth' ? '' : ' · 目标体脂 ${fmt(t?['goalBodyFat'])}%'}',
            style: TextStyle(fontSize: 15, height: 1.5, color: p.secondary),
          ),
          const SizedBox(height: 16),
          if (profile == null)
            FormButton(
              '开始评估',
              filled: true,
              onTap: () => openOnboarding(context, upgrade: true),
            )
          else
            Row(
              children: [
                for (final item in [
                  ('每日热量', '${app.kcalGoal}'),
                  ('每日蛋白', '${app.proteinGoal} g'),
                  (
                    '预计周数',
                    weeks == null ? '—' : '${weeks.first}–${weeks.last}',
                  ),
                ])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText(
                          item.$2,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LText(item.$1, style: AppText.hint(p)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
    return profile == null
        ? content
        : Semantics(
            button: true,
            label: AppMessages.of(context).text('查看我的资料与目标'),
            child: Pressable(onTap: () => openProfile(context), child: content),
          );
  }
}
