import '../../core/haptics.dart';

import 'package:flutter/widgets.dart';

/// 所有可点元素的按压反馈：按下缩到 0.97、松手回弹。可打断，不重建子树。
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.dim = 1,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// 按下时的不透明度（1 = 不变）。
  final double dim;

  /// 点按时给一次轻触觉。
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) {
        if (!reduced) _c.forward();
      },
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: () {
        if (widget.haptic) HapticScope.of(context)?.selection();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Opacity(
          opacity: reduced ? 1 : 1 - (1 - widget.dim) * _t.value,
          child: Transform.scale(
            scale: reduced ? 1 : 1 - (1 - widget.scale) * _t.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
