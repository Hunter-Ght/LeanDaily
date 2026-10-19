import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// Reserve the demonstration's space before decoding, and keep the last image
/// visible until the next frame is ready. Shared by sheet and wide layouts.
class GuideImage extends StatefulWidget {
  const GuideImage({super.key, required this.frames, required this.frame});
  final List<String> frames;
  final int frame;

  @override
  State<GuideImage> createState() => _GuideImageState();
}

class _GuideImageState extends State<GuideImage> {
  AssetBundle? _bundle;
  bool _hasFrame = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(_bundle, bundle)) {
      _bundle = bundle;
      _preload();
    }
  }

  @override
  void didUpdateWidget(GuideImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.frames, widget.frames)) {
      _hasFrame = false;
      _preload();
    }
  }

  void _preload() {
    for (final path in widget.frames.take(2)) {
      precacheImage(
        AssetImage(path, bundle: _bundle),
        context,
        onError: (_, _) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 2,
    child: ColoredBox(
      color: context.pal.fill,
      child: widget.frames.isEmpty
          ? const SizedBox.expand()
          : Image.asset(
              widget.frames[widget.frame.clamp(0, widget.frames.length - 1)],
              // A different exercise must not inherit the previous one's image.
              key: ValueKey(widget.frames.join('|')),
              bundle: _bundle,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, synchronous) {
                if (frame != null) _hasFrame = true;
                // Fade only the first loaded frame. Fading to zero on every
                // asset change would hide the image retained by gaplessPlayback.
                return AnimatedOpacity(
                  opacity: _hasFrame ? 1 : 0,
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 200,
                  ),
                  curve: Curves.easeOutCubic,
                  child: child,
                );
              },
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    ),
  );
}
