import 'package:flutter/widgets.dart';

import 'guide/guide_view.dart';

/// 弹层内的示范排版；与宽屏常驻栏共用 [GuideView]，版式一致。
class SheetGuideBody extends StatelessWidget {
  const SheetGuideBody({super.key, required this.exercise, required this.iso});
  final Map<String, dynamic> exercise;
  final String iso;
  @override
  Widget build(BuildContext context) => GuideView(exercise: exercise, iso: iso);
}
