import 'package:flutter/widgets.dart';

import '../../core/haptics.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';

/// Tap or scrub between discrete choices; writes happen only on release.
class AppSegments extends StatefulWidget {
  const AppSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.itemKeys,
    this.icons,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final List<Key>? itemKeys;
  final List<Widget>? icons;

  @override
  State<AppSegments> createState() => _AppSegmentsState();
}

class _AppSegmentsState extends State<AppSegments> {
  int? _preview;
  Offset _pointerStart = Offset.zero;
  bool _verticalMove = false;
  int get _selected => _preview ?? widget.selected;

  @override
  void didUpdateWidget(AppSegments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) _preview = null;
  }

  void _tap(int index) {
    if (_verticalMove || index == widget.selected) return;
    HapticScope.of(context)?.selection();
    widget.onChanged(index);
  }

  void _move(double x, double width) {
    if (_verticalMove) return;
    final cell = width / widget.labels.length;
    final next = (x / cell).floor().clamp(0, widget.labels.length - 1);
    if (next == _selected) return;
    // A small dead zone at each boundary stops chatter when the finger rests.
    final boundary = next > _selected ? next * cell : (next + 1) * cell;
    if ((x - boundary).abs() < Metrics.segmentDeadZone) return;
    HapticScope.of(context)?.selection();
    setState(() => _preview = next);
  }

  void _finish() {
    final value = _selected;
    setState(() => _preview = null);
    if (!_verticalMove && value != widget.selected) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (e) {
        _pointerStart = e.position;
        _verticalMove = false;
      },
      onPointerMove: (e) {
        final delta = e.position - _pointerStart;
        if (delta.dy.abs() > Metrics.segmentDeadZone * 2 &&
            delta.dy.abs() > delta.dx.abs()) {
          _verticalMove = true;
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.seg,
          borderRadius: BorderRadius.circular(Metrics.segmentRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Metrics.segmentInset),
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / widget.labels.length;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) =>
                    setState(() => _preview = widget.selected),
                onHorizontalDragUpdate: (d) =>
                    _move(d.localPosition.dx, box.maxWidth),
                onHorizontalDragEnd: (_) => _finish(),
                onHorizontalDragCancel: () => setState(() => _preview = null),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedAlign(
                        duration: reduced
                            ? Duration.zero
                            : Motion.selectionDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          widget.labels.length <= 1
                              ? 0
                              : -1 + 2 * _selected / (widget.labels.length - 1),
                          0,
                        ),
                        child: SizedBox(
                          width: width,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.segOn,
                              borderRadius: BorderRadius.circular(
                                Metrics.segmentRadius - Metrics.segmentInset,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: p.shadow,
                                  blurRadius: Metrics.segmentShadow,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < widget.labels.length; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == _selected,
                              label: widget.labels[i],
                              excludeSemantics: true,
                              onTap: () {
                                _verticalMove = false;
                                _tap(i);
                              },
                              child: GestureDetector(
                                key: widget.itemKeys?[i],
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _tap(i),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: Metrics.touchTarget,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Metrics.segmentInset,
                                      vertical: Metrics.segmentTextPad,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (widget.icons != null) ...[
                                            widget.icons![i],
                                            const SizedBox(
                                              width: Metrics.segmentIconGap,
                                            ),
                                          ],
                                          Flexible(
                                            child: Text(
                                              widget.labels[i],
                                              textAlign: TextAlign.center,
                                              style: AppText.navWeek(p)
                                                  .copyWith(
                                                    color: i == _selected
                                                        ? p.text
                                                        : p.secondary,
                                                    fontWeight: i == _selected
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    letterSpacing: 0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
