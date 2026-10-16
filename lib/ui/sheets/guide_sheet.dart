import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../kit/sheet.dart';
import '../today/guide_body.dart' show guideExercise;
import 'guide_content.dart';

class GuideSheet extends StatelessWidget {
  const GuideSheet({super.key, required this.exercise, this.iso});
  final String exercise;
  final String? iso;
  @override
  Widget build(BuildContext context) {
    final app = context.app, date = iso ?? context.app.today;
    return AppSheet(
      title: exercise,
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: SheetGuideBody(
        exercise: guideExercise(app, exercise, date),
        iso: date,
      ),
    );
  }
}
