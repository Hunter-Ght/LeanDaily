import 'package:flutter/widgets.dart';

import 'transitions.dart';

import '../../domain/guide.dart';
import '../../theme/theme.dart';
import 'badge.dart';

/// 动作缩略图：有示范图用第一帧，没有就用部位图标。`ex` 是计划里的动作 Map（用 name / img / part）。
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({
    super.key,
    required this.ex,
    this.size = 56,
    this.radius = 14,
  });

  final Map<String, dynamic> ex;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final g = guideFor(ex);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: p.fill,
          child: g == null
              ? Center(child: ToneBadge.part('${ex['part'] ?? ''}', size: size))
              : Image.asset(
                  (g['frames'] as List).first as String,
                  frameBuilder: revealImageFrame,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (_, _, _) => Center(
                    child: ToneBadge.part('${ex['part'] ?? ''}', size: size),
                  ),
                ),
        ),
      ),
    );
  }
}
