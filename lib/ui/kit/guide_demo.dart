import 'package:flutter/widgets.dart';

import '../../domain/motion_library.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import 'guide_image.dart';
import 'motion_demo.dart';
import 'pressable.dart';

/// 动作要点里的示范：有矢量动画的动作默认播动画，右上角可切到真人照片；
/// 其余动作照旧两张照片交替。[frame] 只用于照片。
class GuideDemo extends StatefulWidget {
  const GuideDemo({
    super.key,
    required this.guide,
    required this.frame,
    required this.paused,
  });
  final Map<String, dynamic> guide;
  final int frame;
  final bool paused;

  @override
  State<GuideDemo> createState() => _GuideDemoState();
}

class _GuideDemoState extends State<GuideDemo> {
  bool _photo = false;

  @override
  void didUpdateWidget(GuideDemo old) {
    super.didUpdateWidget(old);
    if (old.guide['key'] != widget.guide['key']) _photo = false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final motion = motionLibrary[widget.guide['key']];
    final frames = (widget.guide['frames'] as List).cast<String>();
    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: p.scrim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LText(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.onTint,
        ),
      ),
    );
    if (motion == null || _photo) {
      return Stack(
        children: [
          GuideImage(frames: frames, frame: widget.frame),
          Positioned(
            left: 10,
            bottom: 10,
            child: pill(
              '${widget.frame == 0 ? '起始' : '发力'}${widget.paused ? ' · 已暂停' : ''}',
            ),
          ),
          if (motion != null) _switch(context, '动画示范', pill),
        ],
      );
    }
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 3 / 2,
          child: ColoredBox(
            color: p.fill2,
            child: MotionDemo(
              spec: motion,
              paused: widget.paused,
              still: MediaQuery.disableAnimationsOf(context),
              showPhase: true,
            ),
          ),
        ),
        _switch(context, '真人照片', pill),
      ],
    );
  }

  Widget _switch(
    BuildContext context,
    String label,
    Widget Function(String) pill,
  ) => Positioned(
    right: 4,
    top: 4,
    child: Semantics(
      button: true,
      excludeSemantics: true,
      label: AppMessages.of(context).text(label),
      child: Pressable(
        onTap: () => setState(() => _photo = !_photo),
        child: Padding(
          // 小标签，触控区仍有 44 点高。
          padding: const EdgeInsets.all(8),
          child: SizedBox(height: 28, child: Center(child: pill(label))),
        ),
      ),
    ),
  );
}
