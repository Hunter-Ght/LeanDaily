import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../theme/tokens.dart';

/// 线条图标。图形来自 Web 版 Icon.svelte（导出到 assets/icons.json）。
/// 少数图标（more / rings / 实心 train、meal、chart）在 Web 版里是单独画的，这里同样处理。
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    required this.color,
    this.size = 22,
    this.solid = false,
  });

  final String name;
  final Color color;
  final double size;
  final bool solid;

  static const double _box = 24;
  static const double _stroke = 1.75;
  static Map<String, List<Path>> _paths = {};

  /// 启动时调用一次。
  static Future<void> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/icons.json');
    final icons =
        (jsonDecode(raw) as Map<String, dynamic>)['icons']
            as Map<String, dynamic>;
    _paths = {
      for (final e in icons.entries)
        e.key: [
          for (final d in (e.value as List)) parseSvgPathData(d as String),
        ],
    };
  }

  static Future<List<Uint8List>>? _navigationImages;
  static List<Uint8List>? _navigationImageBytes;

  /// The native iOS bar uses the very same painter as the Flutter dock.
  /// Export both outline/selected variants at 3x; UIKit applies the tint.
  static Future<List<Uint8List>> navigationImages() {
    final cached = _navigationImageBytes;
    if (cached != null) return SynchronousFuture(cached);
    return _navigationImages ??= _renderNavigationImages();
  }

  static Future<List<Uint8List>> _renderNavigationImages() async {
    if (_paths.isEmpty) await load();
    final images = <Uint8List>[];
    for (final name in ['flame', 'train', 'rings', 'me']) {
      for (final solid in [false, true]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(3);
        _IconPainter(
          name,
          AppPalette.light.text, // UIKit templates use only the alpha channel.
          solid,
          _paths[name] ?? const [],
        ).paint(canvas, const Size.square(25));
        final picture = recorder.endRecording();
        final image = await picture.toImage(75, 75);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          images.add(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    }
    _navigationImageBytes = images;
    return images;
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _IconPainter(
        name,
        color,
        solid,
        _paths[name] ?? _paths['train'] ?? const [],
      ),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.name, this.color, this.solid, this.paths);

  final String name;
  final Color color;
  final bool solid;
  final List<Path> paths;

  RRect _r(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / AppIcon._box);
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppIcon._stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (name == 'me') {
      canvas.drawCircle(const Offset(12, 7.2), 3.4, solid ? fill : line);
      final shoulder = Path()
        ..moveTo(4, 21)
        ..lineTo(4, 19)
        ..cubicTo(4, 11.8, 20, 11.8, 20, 19)
        ..lineTo(20, 21);
      if (solid) shoulder.close();
      canvas.drawPath(shoulder, solid ? fill : line);
    } else if (name == 'more') {
      for (final x in [6.0, 12.0, 18.0]) {
        canvas.drawCircle(Offset(x, 12), 1.35, fill);
      }
    } else if (solid && name == 'train') {
      canvas.drawRRect(_r(2, 8, 2.5, 8, .7), fill);
      canvas.drawRRect(_r(5.1, 9.3, 1.6, 5.4, .4), fill);
      canvas.drawRRect(_r(6.7, 11, 10.6, 2, .5), fill);
      canvas.drawRRect(_r(17.3, 9.3, 1.6, 5.4, .4), fill);
      canvas.drawRRect(_r(19.5, 8, 2.5, 8, .7), fill);
    } else if (name == 'rings') {
      line.strokeWidth = solid ? 2.4 : 1.7;
      canvas.drawCircle(const Offset(12, 12), 8.2, line);
      canvas.drawCircle(const Offset(12, 12), 5, line);
      canvas.drawCircle(const Offset(12, 12), 1.7, fill);
    } else if (solid && name == 'chart') {
      canvas.drawRRect(_r(5, 11, 3.2, 7, .7), fill);
      canvas.drawRRect(_r(10.4, 7, 3.2, 11, .7), fill);
      canvas.drawRRect(_r(15.8, 9, 3.2, 9, .7), fill);
    } else if (solid && name == 'meal') {
      canvas.drawPath(
        parseSvgPathData('M4 8.4h16c-.5 5-3.3 8-8 8s-7.5-3-8-8z'),
        fill,
      );
      canvas.drawRRect(_r(10.3, 16.5, 3.4, 1.5, .4), fill);
      canvas.drawRRect(_r(8.4, 18.1, 7.2, 1.6, .5), fill);
    } else {
      for (final p in paths) {
        canvas.drawPath(p, line);
      }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.name != name ||
      old.color != color ||
      old.solid != solid ||
      old.paths != paths;
}
