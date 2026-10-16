import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import 'pressable.dart';
import 'transitions.dart';

/// 当前最靠前的弹层打开进度（0~1）。外壳据此把后面的页面轻轻缩小，做出 iOS 卡片式层叠感。
final ValueNotifier<double> sheetDepth = ValueNotifier(0);
final List<ValueNotifier<double>> _open = [];
void _publishDepth() => sheetDepth.value = _open.isEmpty
    ? 0
    : _open.map((n) => n.value).reduce(math.max);

/// 弹层控制：关闭、拖拽、与内部滚动联动。
class SheetController {
  SheetController._(this._state);
  final _SheetHostState<dynamic> _state;

  /// 关闭并带回结果（先走收起动画）。
  void close([Object? result]) => _state._dismiss(result: result);

  /// 走“取消”流程：有 [AppSheet.confirmClose] 时先询问。
  Future<void> requestClose() => _state._requestClose();

  ScrollPhysics get physics => _SheetPhysics(this);

  static SheetController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetScope>()!.controller;
  static SheetController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetScope>()?.controller;
}

class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.controller, required super.child});
  final SheetController controller;
  @override
  bool updateShouldNotify(_SheetScope old) => old.controller != controller;
}

/// 弹出一个全高弹层页。内容请返回 [AppSheet]。
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(_SheetRoute<T>(builder: builder, tall: true));

/// 贴底、按内容高度的面板（动作菜单 / 确认框）。
Future<T?> showSheetPanel<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(_SheetRoute<T>(builder: builder, tall: false));

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.builder, required this.tall});
  final WidgetBuilder builder;
  final bool tall;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => '关闭';
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _SheetHost<T>(tall: tall, builder: builder);
}

class _SheetHost<T> extends StatefulWidget {
  const _SheetHost({required this.tall, required this.builder});
  final bool tall;
  final WidgetBuilder builder;
  @override
  State<_SheetHost<T>> createState() => _SheetHostState<T>();
}

class _SheetHostState<T> extends State<_SheetHost<T>>
    with SingleTickerProviderStateMixin {
  static const double _panelRadius = 28;
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
    value: 4000,
  );
  final ValueNotifier<double> _progress = ValueNotifier(0);
  late final SheetController _ctl = SheetController._(this);
  double _h = 0; // 弹层高度（动画行程）
  bool _reduceMotion = false;
  bool _entered = false;
  bool _leaving = false;
  bool _dragging = false;
  Future<bool> Function()? confirmClose;

  @override
  void initState() {
    super.initState();
    _open.add(_progress);
    _y.addListener(_sync);
  }

  @override
  void dispose() {
    _open.remove(_progress);
    _y.dispose();
    _progress.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishDepth());
    super.dispose();
  }

  void _sync() {
    if (_h <= 0) return;
    _progress.value = (1 - _y.value / _h).clamp(0.0, 1.0);
    _publishDepth();
  }

  void _measured(double h) {
    if (_h == h) return;
    _h = h;
    if (!_entered) {
      _entered = true;
      _y.value = h;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_reduceMotion) {
            _y.value = 0;
          } else {
            springTo(_y, 0, response: 0.3);
          }
        }
      });
    }
  }

  void dragBy(double dy) {
    if (_leaving) return;
    _y.stop();
    _dragging = true;
    final next = _y.value + dy;
    _y.value = next < 0 ? -rubberband(-next, _h) : next;
  }

  Future<void> release(double velocity) async {
    if (_leaving) return;
    _dragging = false;
    final projected = _y.value + project(velocity, 0.995);
    if (projected > _h * 0.33 || velocity > 900) {
      await _requestClose(velocity: velocity);
    } else {
      _returnToTop(
        0,
        velocity: velocity,
        response: 0.3,
        damping: velocity.abs() > 240 ? 0.82 : 1,
      );
    }
  }

  Future<void> _returnToTop(
    double target, {
    double velocity = 0,
    double response = .3,
    double damping = 1,
  }) async {
    if (_reduceMotion) {
      _y.value = target;
    } else {
      await springTo(
        _y,
        target,
        velocity: velocity,
        response: response,
        damping: damping,
      );
    }
  }

  Future<void> _requestClose({double velocity = 0}) async {
    final ask = confirmClose;
    if (ask != null) {
      _returnToTop(0, velocity: velocity, response: 0.3);
      if (!await ask()) return;
    }
    await _dismiss(velocity: velocity);
  }

  Future<void> _dismiss({double velocity = 0, Object? result}) async {
    if (_leaving) return;
    _leaving = true;
    if (!_reduceMotion) {
      await springTo(
        _y,
        _h + 40,
        velocity: velocity,
        response: 0.3,
        damping: velocity.abs() > 240 ? 0.82 : 1,
      );
    }
    if (mounted) Navigator.of(context).pop(result as T?);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final wide =
              box.maxWidth >= Metrics.wideBreakpoint &&
              box.maxHeight >= Metrics.minTallForWide;
          final top = math.max(wide ? 24.0 : 10.0, media.padding.top);
          final tallH = box.maxHeight - top;
          final width = wide
              ? math.min(box.maxWidth, widget.tall ? 600.0 : 480.0)
              : box.maxWidth;
          if (widget.tall) _measured(tallH);
          return _SheetScope(
            controller: _ctl,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _requestClose,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (_, v, _) => ColoredBox(
                        color: p.scrim.withValues(alpha: p.scrim.a * v),
                      ),
                    ),
                  ),
                ),
                if (widget.tall)
                  Positioned(
                    top: top,
                    bottom: 0,
                    left: (box.maxWidth - width) / 2,
                    width: width,
                    child: AnimatedBuilder(
                      animation: _y,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _y.value),
                        child: child,
                      ),
                      child: _TallPanel(
                        radius: _panelRadius,
                        child: widget.builder(context),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: width,
                      child: _FitPanel<T>(host: this, builder: widget.builder),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TallPanel extends StatelessWidget {
  const _TallPanel({required this.radius, required this.child});
  final double radius;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: p.shadow.a * 2),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        child: child,
      ),
    );
  }
}

/// 贴底、按内容高度的面板（动作菜单）。
class _FitPanel<T> extends StatelessWidget {
  const _FitPanel({required this.host, required this.builder});
  final _SheetHostState<T> host;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onVerticalDragStart: (_) => host._y.stop(),
    onVerticalDragUpdate: (d) => host.dragBy(d.delta.dy),
    onVerticalDragEnd: (d) => host.release(d.velocity.pixelsPerSecond.dy),
    child: AnimatedBuilder(
      animation: host._y,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, host._y.value), child: child),
      child: _Measure(
        onSize: (s) => host._measured(s.height + 24),
        child: builder(context),
      ),
    ),
  );
}

class _Measure extends StatefulWidget {
  const _Measure({required this.child, required this.onSize});
  final Widget child;
  final ValueChanged<Size> onSize;
  @override
  State<_Measure> createState() => _MeasureState();
}

class _MeasureState extends State<_Measure> {
  Size? _last;
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.size;
      if (s != null && s != _last) {
        _last = s;
        widget.onSize(s);
      }
    });
    return widget.child;
  }
}

/// 把内部滚动内容在顶部的下拉，转成整张弹层的下移。
class _SheetPhysics extends ScrollPhysics {
  const _SheetPhysics(this.ctl, {super.parent});
  final SheetController ctl;

  @override
  _SheetPhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetPhysics(ctl, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final host = ctl._state;
    if (host._leaving) return 0;
    final atTop = position.pixels <= position.minScrollExtent + 0.5;
    if (offset > 0 && atTop) {
      host.dragBy(offset);
      return 0;
    }
    if (offset < 0 && host._y.value > 0.5) {
      final take = math.min(-offset, host._y.value);
      host.dragBy(-take);
      return offset + take;
    }
    return offset;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final host = ctl._state;
    if (host._dragging) {
      host.release(-velocity);
      return null;
    }
    return const ClampingScrollPhysics().createBallisticSimulation(
      position,
      velocity,
    );
  }
}

/// 全高弹层的标准版式：抓手 + 取消/标题/保存 + 可滚动正文。
class AppSheet extends StatefulWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.saveLabel = '保存',
    this.cancelLabel = '取消',
    this.saveEnabled = true,
    this.confirmClose,
    this.footer,
    this.scrollController,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final Widget child;

  /// 为 null 时不显示右上角按钮。
  final VoidCallback? onSave;
  final String saveLabel;
  final String cancelLabel;
  final bool saveEnabled;

  /// 有未保存内容时，关闭前询问；返回 false 则留下。
  final Future<bool> Function()? confirmClose;
  final Widget? footer;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  @override
  State<AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<AppSheet> {
  late final ScrollController _scroll =
      widget.scrollController ?? ScrollController();
  final ValueNotifier<double> _edge = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdge);
  }

  void _updateEdge() => _edge.value = _scroll.hasClients
      ? (_scroll.offset / 12).clamp(0.0, 1.0)
      : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SheetController.maybeOf(context)?._state.confirmClose = widget.confirmClose;
  }

  @override
  void didUpdateWidget(AppSheet old) {
    super.didUpdateWidget(old);
    SheetController.maybeOf(context)?._state.confirmClose = widget.confirmClose;
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateEdge);
    if (widget.scrollController == null) _scroll.dispose();
    _edge.dispose();
    super.dispose();
  }

  Widget _textButton(
    AppPalette p,
    String label,
    VoidCallback? onTap, {
    bool bold = false,
    bool enabled = true,
  }) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: FadeSwitcher(
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                fontSize: 17,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: p.tint,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ctl = SheetController.of(context);
    final host = ctl._state;
    final head = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => host._y.stop(),
      onVerticalDragUpdate: (d) => host.dragBy(d.delta.dy),
      onVerticalDragEnd: (d) => host.release(d.velocity.pixelsPerSecond.dy),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: p.grab,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _textButton(p, widget.cancelLabel, ctl.requestClose),
                  ),
                ),
                Expanded(
                  child: FadeSwitcher(
                    child: Text(
                      widget.title,
                      key: ValueKey(widget.title),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h2(p),
                    ),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: widget.onSave == null
                        ? null
                        : _textButton(
                            p,
                            widget.saveLabel,
                            widget.onSave,
                            bold: true,
                            enabled: widget.saveEnabled,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        head,
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: ctl.physics,
                  padding: widget.padding,
                  child: widget.child,
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 16,
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _edge,
                    builder: (_, v, _) => Opacity(
                      opacity: v,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [p.bg, p.bg.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}
