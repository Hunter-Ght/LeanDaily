import 'package:flutter/widgets.dart';

/// 高度跟随当前内容，退出内容在原位置淡出，不占用最终高度。
Widget _layout(Widget? current, List<Widget> previous) => Stack(
  alignment: Alignment.topCenter,
  children: [
    for (final child in previous)
      Positioned(top: 0, left: 0, right: 0, child: IgnorePointer(child: child)),
    ?current,
  ],
);

/// 就地内容替换。调用方用 key 标识内容，而不是每次重建都重新播放。
class FadeSwitcher extends StatelessWidget {
  const FadeSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? true) return child;
    return LayoutBuilder(
      builder: (context, box) => AnimatedSize(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          layoutBuilder: box.hasBoundedHeight
              ? AnimatedSwitcher.defaultLayoutBuilder
              : _layout,
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}

/// 展开/收起时同时过渡高度与透明度，快速反向点击可打断。
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.visible,
    required this.child,
    this.alignment = Alignment.topCenter,
  });
  final bool visible;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return visible ? child : const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: _layout,
        child: visible
            ? KeyedSubtree(key: const ValueKey(true), child: child)
            : const SizedBox.shrink(key: ValueKey(false)),
      ),
    );
  }
}

/// 弹层内部的推入/返回。direction 为 1 时从右进入，-1 时从左返回。
class PushSwitcher extends StatelessWidget {
  const PushSwitcher({super.key, required this.child, this.direction = 1});
  final Widget child;
  final int direction;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? true) return child;
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          layoutBuilder: _layout,
          transitionBuilder: (child, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final exiting = animation.status == AnimationStatus.reverse;
              final t = Curves.easeOutCubic.transform(animation.value);
              return FractionalTranslation(
                translation: Offset(
                  (exiting ? -.08 : 1) * direction * (1 - t),
                  0,
                ),
                child: Opacity(opacity: t, child: child),
              );
            },
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Image.frameBuilder：解码前保留布局与底色，首帧准备好后淡入。
Widget revealImageFrame(
  BuildContext context,
  Widget child,
  int? frame,
  bool synchronous,
) => AnimatedOpacity(
  opacity: frame == null ? 0 : 1,
  duration: Duration(
    milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
  ),
  curve: Curves.easeOutCubic,
  child: child,
);

/// 小型可编辑列表：以稳定 key 保留输入状态，插入/删除仅重建该行。
/// 大型记录列表继续使用惰性构建；不要用它替换长 ListView。
class MotionList extends StatefulWidget {
  const MotionList({
    super.key,
    required this.children,
    this.axis = Axis.vertical,
  });
  final Axis axis;
  final List<Widget> children;
  @override
  State<MotionList> createState() => _MotionListState();
}

class _MotionListState extends State<MotionList> {
  late List<Widget> _rows = widget.children.toList();
  final Set<Key> _entering = {};
  @override
  void didUpdateWidget(MotionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.children.every((child) => child.key != null));
    final current = {for (final child in widget.children) child.key: child};
    final previous = {for (final child in _rows) child.key: child};
    _entering.addAll(
      current.keys.whereType<Key>().where((key) => !previous.containsKey(key)),
    );
    final next = widget.children.toList();
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (!current.containsKey(row.key)) {
        next.insert(i.clamp(0, next.length), row);
      }
    }
    _rows = next;
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.children.map((child) => child.key).toSet();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rows = widget.children.toList();
      _entering.clear();
      return Flex(
        direction: widget.axis,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.axis == Axis.vertical
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: widget.children,
      );
    }
    return Flex(
      direction: widget.axis,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.axis == Axis.vertical
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        for (final row in _rows)
          _MotionRow(
            key: row.key,
            axis: widget.axis,
            visible: keys.contains(row.key),
            entering: _entering.contains(row.key),
            onRemoved: () {
              if (mounted &&
                  !widget.children.any((child) => child.key == row.key)) {
                setState(() {
                  _rows.removeWhere((child) => child.key == row.key);
                  _entering.remove(row.key);
                });
              }
            },
            child: row,
          ),
      ],
    );
  }
}

class _MotionRow extends StatefulWidget {
  const _MotionRow({
    super.key,
    required this.visible,
    required this.axis,
    required this.entering,
    required this.onRemoved,
    required this.child,
  });
  final bool visible, entering;
  final Axis axis;
  final VoidCallback onRemoved;
  final Widget child;
  @override
  State<_MotionRow> createState() => _MotionRowState();
}

class _MotionRowState extends State<_MotionRow>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.entering ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
  );
  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !widget.visible) {
        widget.onRemoved();
      }
    });
    if (widget.entering) _motion.forward();
  }

  @override
  void didUpdateWidget(_MotionRow old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) {
      if (widget.visible) {
        _motion.forward();
      } else {
        _motion.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !widget.visible,
    child: ExcludeSemantics(
      excluding: !widget.visible,
      child: SizeTransition(
        axis: widget.axis,
        sizeFactor: _curve,
        child: FadeTransition(opacity: _curve, child: widget.child),
      ),
    ),
  );
}

/// 惰性记录列表：按稳定 key 对比变更，避免为长历史构建全部行。
class MotionLazyList extends StatefulWidget {
  const MotionLazyList({
    super.key,
    required this.items,
    this.controller,
    this.padding = EdgeInsets.zero,
  });
  final List<({Key key, WidgetBuilder builder})> items;
  final ScrollController? controller;
  final EdgeInsets padding;
  @override
  State<MotionLazyList> createState() => _MotionLazyListState();
}

class _MotionLazyListState extends State<MotionLazyList> {
  final _list = GlobalKey<AnimatedListState>();
  late final _items = widget.items.toList();
  @override
  void didUpdateWidget(MotionLazyList old) {
    super.didUpdateWidget(old);
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
    );
    for (var i = 0; i < widget.items.length; i++) {
      final next = widget.items[i];
      if (i < _items.length && _items[i].key == next.key) {
        _items[i] = next;
        continue;
      }
      final index = _items.indexWhere((item) => item.key == next.key, i);
      if (index >= 0) _remove(index, duration);
      _items.insert(i, next);
      _list.currentState!.insertItem(i, duration: duration);
    }
    while (_items.length > widget.items.length) {
      _remove(_items.length - 1, duration);
    }
  }

  void _remove(int index, Duration duration) {
    final previous = _items.removeAt(index);
    _list.currentState!.removeItem(
      index,
      (context, animation) => IgnorePointer(
        child: ExcludeSemantics(child: _row(previous, animation)),
      ),
      duration: duration,
    );
  }

  Widget _row(
    ({Key key, WidgetBuilder builder}) item,
    Animation<double> animation,
  ) => SizeTransition(
    sizeFactor: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
    child: FadeTransition(
      opacity: animation,
      child: KeyedSubtree(
        key: item.key,
        child: Builder(builder: item.builder),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedList(
    key: _list,
    controller: widget.controller,
    physics: const ClampingScrollPhysics(),
    padding: widget.padding,
    initialItemCount: _items.length,
    itemBuilder: (context, index, animation) => _row(_items[index], animation),
  );
}
