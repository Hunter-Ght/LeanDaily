import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/format.dart';
import '../../domain/plan.dart' as plan;
import '../sheets/guide/guide_view.dart';

/// 手机弹层与内屏常驻栏共用的动作示范本体（版式在 [GuideView]）。
class GuideBody extends StatelessWidget {
  const GuideBody({super.key, required this.exercise, required this.iso});
  final Map<String, dynamic> exercise;
  final String iso;
  @override
  Widget build(BuildContext context) => GuideView(exercise: exercise, iso: iso);
}

Map<String, dynamic> guideExercise(AppController app, String name, String iso) {
  final slot = plan.workoutFor(app.plan, iso, jsonMap(app.dayStates[iso]));
  return plan
          .exercisesFor(
            app.plan,
            jsonMap(slot['workout']),
            iso,
            false,
            app.courseSetsOf(iso),
          )
          .where((e) => e['name'] == name)
          .firstOrNull ??
      {'name': name};
}
