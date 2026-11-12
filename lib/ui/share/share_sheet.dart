import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../core/native.dart' show NativeError;
import '../../l10n/app_messages.dart';
import '../../theme/theme.dart';
import '../kit/body_figure.dart';
import '../kit/form.dart';
import '../kit/segments.dart';
import '../kit/sheet.dart';
import '../sheets/train/controls.dart';
import 'share_card.dart';
import 'share_data.dart';

/// 打开分享预览：上面是卡片，下面是外观 / 比例 / 显示重量，底部「分享图片」。
Future<void> openShareSheet(BuildContext context, ShareContent content) =>
    showAppSheet<void>(context, (_) => ShareSheet(content: content));

/// 把卡片画成 PNG（宽 1080）。[boundary] 是包住 [ShareCard] 的 RepaintBoundary。
Future<Uint8List> renderShareCard(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: ShareRatio.exportScale);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('png');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.content});
  final ShareContent content;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _card = GlobalKey();
  final _button = GlobalKey();
  ShareLook? _look;
  bool _busy = false;
  bool _ready = BodyFigure.isLoaded;

  @override
  void initState() {
    super.initState();
    if (!_ready) {
      BodyFigure.load().then((_) {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  ShareContent get content => widget.content;
  bool get _weighted =>
      content is TrainShare && (content as TrainShare).hasWeightedRecord;

  String get _fileName => switch (content) {
    final TrainShare c => 'LeanDaily-workout-${c.iso}.png',
    final WeekShare c => 'LeanDaily-week-${c.start}.png',
  };

  Rect? _anchor() {
    final box = _button.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() async {
    if (_busy || !_ready) return;
    final app = context.app;
    final anchor = _anchor();
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await renderShareCard(boundary);
      await app.native.shareImage(bytes, _fileName, anchor: anchor);
    } on NativeError catch (e) {
      app.toast.show(AppController.message(e));
    } on Object {
      app.toast.show('生成图片失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // 默认跟随当前主题：训练页是固定深色，从那里打开就是深色。
    final look = _look ??= ShareLook(dark: p.bg.computeLuminance() < .5);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return AppSheet(
      title: '分享',
      cancelLabel: '关闭',
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      footer: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
        child: SizedBox(
          key: _button,
          width: double.infinity,
          child: SheetButton(
            '分享图片',
            _busy || !_ready ? null : _share,
            ink: true,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Preview(cardKey: _card, content: content, look: look, ready: _ready),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormLabel('外观'),
                    AppSegments(
                      labels: const ['浅色', '深色'],
                      selected: look.dark ? 1 : 0,
                      onChanged: (i) =>
                          setState(() => _look = _look!.copyWith(dark: i == 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormLabel('比例'),
                    AppSegments(
                      labels: [for (final r in ShareRatio.values) r.label],
                      selected: look.ratio.index,
                      onChanged: (i) => setState(
                        () => _look = _look!.copyWith(
                          ratio: ShareRatio.values[i],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_weighted)
            FormRow(
              '显示重量',
              child: FormSwitch(
                label: '显示重量',
                value: look.showWeight,
                onChanged: (v) =>
                    setState(() => _look = _look!.copyWith(showWeight: v)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 卡片预览：按真实尺寸排版，再整体缩小到版面里，所以和导出的图一模一样。
class _Preview extends StatelessWidget {
  const _Preview({
    required this.cardKey,
    required this.content,
    required this.look,
    required this.ready,
  });
  final GlobalKey cardKey;
  final ShareContent content;
  final ShareLook look;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(
      builder: (context, box) {
        const maxHeight = 380.0;
        final width = math.min(
          box.maxWidth - 32,
          maxHeight * look.ratio.aspect,
        );
        final height = width / look.ratio.aspect;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.sep, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Semantics(
                    image: true,
                    label: AppMessages.of(context).text('分享卡片预览'),
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          key: cardKey,
                          child: ready
                              ? ShareCard(content: content, look: look)
                              : SizedBox(
                                  width: ShareRatio.width,
                                  height: look.ratio.height,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
