import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/guide.dart';
import '../../theme/theme.dart';
import 'badge.dart';
import 'pressable.dart';
import 'transitions.dart';

/// Only the active, uncovered exercise owns a playback timer.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({
    super.key,
    required this.ex,
    this.size = 200,
    this.autoplay = true,
  });
  final Map<String, dynamic> ex;
  final double size;
  final bool autoplay;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _frame = 0;
  bool _paused = false, _visible = true, _reduce = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        Visibility.of(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) _frame = 0;
    syncTimer();
  }

  @override
  void didUpdateWidget(ExerciseDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ex['name'] != widget.ex['name'] ||
        oldWidget.ex['img'] != widget.ex['img']) {
      _frame = 0;
      _paused = false;
      _timer?.cancel();
      _timer = null;
    }
    syncTimer();
  }

  void syncTimer() {
    final frames = guideFor(widget.ex)?['frames'] as List?;
    if (!_visible ||
        !_foreground ||
        _reduce ||
        _paused ||
        !widget.autoplay ||
        frames == null ||
        frames.length < 2) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _frame = 1 - _frame);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final frames = guideFor(widget.ex)?['frames'] as List?;
    if (frames == null || frames.isEmpty) {
      return SizedBox.square(
        dimension: widget.size,
        child: Center(
          child: ToneBadge.part(
            '${widget.ex['part'] ?? ''}',
            size: widget.size,
          ),
        ),
      );
    }
    final manual = _reduce || !widget.autoplay;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: AppMessages.of(context).text(
        manual
            ? '切换示范帧'
            : _paused
            ? '继续播放示范'
            : '暂停示范',
      ),
      child: Pressable(
        scale: 1,
        onTap: () {
          setState(() {
            if (manual) {
              _frame = 1 - _frame;
            } else {
              _paused = !_paused;
            }
          });
          syncTimer();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: widget.size,
            child: ColoredBox(
              color: p.fill,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < frames.length.clamp(0, 2); i++)
                    AnimatedOpacity(
                      key: ValueKey('demo-frame-$i'),
                      opacity: _frame == i ? 1 : 0,
                      duration: Duration(milliseconds: _reduce ? 0 : 450),
                      child: Image.asset(
                        '${frames[i]}',
                        fit: BoxFit.cover,
                        cacheWidth:
                            (widget.size *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        gaplessPlayback: true,
                        frameBuilder: revealImageFrame,
                        errorBuilder: (_, _, _) => Center(
                          child: ToneBadge.part(
                            '${widget.ex['part'] ?? ''}',
                            size: widget.size,
                          ),
                        ),
                      ),
                    ),
                  if (_paused || manual)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: p.scrim,
                          shape: BoxShape.circle,
                        ),
                        child: LText(
                          '▶',
                          style: TextStyle(fontSize: 14, color: p.onTint),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
