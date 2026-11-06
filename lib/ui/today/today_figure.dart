import 'package:flutter/widgets.dart';

import '../../domain/format.dart';
import '../../domain/movements.dart' show GROUP, MUSCLE, muscleRoles;
import '../../domain/muscles.dart';

import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/body_figure.dart';
import 'today_model.dart';

/// 首页人体图的数据：今天练的肌肉（发力/辅助）与仍在恢复的肌肉。
class TodayFigureData {
  const TodayFigureData({
    required this.tones,
    required this.tiredGroups,
    required this.hasEffort,
  });
  final Map<String, MuscleTone> tones;

  /// 还在恢复的部位名 → 还需天数，天数大的在前。
  final List<MapEntry<String, num>> tiredGroups;
  final bool hasEffort;
  bool get isEmpty => tones.isEmpty;

  static TodayFigureData of(TodayModel m, {required bool training}) {
    final tones = <String, MuscleTone>{};
    var effort = false;
    if (training) {
      for (final e in m.all) {
        if (jsTruthy(e['optional']) || m.lite && !jsTruthy(e['core'])) continue;
        final roles = muscleRoles(e['name'], '${e['part']}');
        for (final id in roles.main) {
          tones[id] = MuscleTone.effort;
          effort = true;
        }
        for (final id in roles.assist) {
          tones.putIfAbsent(id, () => MuscleTone.assist);
        }
      }
    }
    final previous = Map<String, Map<String, dynamic>>.from(m.history)
      ..remove(m.iso);
    final status = muscleStatus(previous, m.app.clock().millisecondsSinceEpoch);
    final days = <String, num>{};
    if (jsNumber(status['setCount']) > 0) {
      for (final entry in jsonMap(status['byMuscle']).entries) {
        final s = jsonMap(entry.value);
        if (jsTruthy(s['recovered'])) continue;
        final left = jsNumber(s['daysLeft']);
        if (tones[entry.key] == null || tones[entry.key] == MuscleTone.assist) {
          tones[entry.key] = MuscleTone.recover;
        }
        final group = MUSCLE[entry.key]?['group'];
        final name = GROUP[group]?['name'] ?? '';
        if (name.isNotEmpty && left >= (days[name] ?? 0)) days[name] = left;
      }
    }
    final tired = days.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return TodayFigureData(tones: tones, tiredGroups: tired, hasEffort: effort);
  }
}

/// 前后人体图 + 图例。没有任何高亮时不占位。
class TodayFigure extends StatelessWidget {
  const TodayFigure({super.key, required this.data, this.height});
  final TodayFigureData data;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final p = context.pal;
    Widget dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    TextStyle small() => TextStyle(fontSize: 13, color: p.secondary);
    String left(num d) =>
        d < .75 ? '不到 1 天' : '约 ${fmt((d * 2).round() / 2)} 天';
    final tired = data.tiredGroups.take(1).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final h = height ?? (box.maxWidth * .62).clamp(170.0, 260.0);
        return Column(
          children: [
            BodyFigure(
              tones: data.tones,
              height: h,
              breathe: data.hasEffort,
              semanticLabel: AppMessages.of(context).text('今天练的肌肉和恢复情况'),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                if (data.hasEffort)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      dot(p.tint),
                      const SizedBox(width: 6),
                      LText('今天练', style: small()),
                    ],
                  ),
                if (tired.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      dot(p.recover),
                      const SizedBox(width: 6),
                      Flexible(
                        child: LText(
                          '恢复中 · ${tired.map((e) => '${e.key}${left(e.value)}').join('、')}',
                          style: small(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
