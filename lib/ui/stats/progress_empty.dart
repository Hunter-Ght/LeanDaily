import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/body_figure.dart';
import '../sheets/train/controls.dart' show SheetButton;

/// 还没有训练记录：一个引导（淡化的人体 + 一句说明 + 下一步按钮）。
class ProgressEmpty extends StatelessWidget {
  const ProgressEmpty({super.key, this.height = 240});
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Opacity(opacity: .5, child: BodyFigure(height: height)),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: LText(
              '练 3 次后，这里会出现你的身体热力图和力量变化',
              textAlign: TextAlign.center,
              style: AppText.body(p),
            ),
          ),
          const SizedBox(height: 20),
          SheetButton('开始今天的训练', () => context.app.setTab(0), primary: true),
        ],
      ),
    );
  }
}
