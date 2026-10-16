import 'dart:io';

import 'package:flutter/services.dart';

/// Loads a real Chinese font from macOS into the widget-test engine so golden screenshots show real glyphs
/// (flutter test otherwise renders every glyph as a box). Call once in setUpAll.
Future<void> loadTestFonts() async {
  final wordmark = FontLoader('Wordmark')
    ..addFont(rootBundle.load('assets/fonts/SmileySans-Wordmark.ttf'));
  await wordmark.load();
  // 截图素材（README）用 LEANDAILY_TEST_FONT 指定简体字形更完整的字体，例如 Hiragino Sans GB。
  final candidates = <String>[
    if (Platform.environment['LEANDAILY_TEST_FONT'] != null)
      Platform.environment['LEANDAILY_TEST_FONT']!,
  ];
  final assets = Directory('/System/Library/AssetsV2');
  if (assets.existsSync()) {
    for (final d in assets.listSync()) {
      if (d.path.contains('com_apple_MobileAsset_Font')) {
        for (final sub in Directory(d.path).listSync()) {
          final f = File('${sub.path}/AssetData/PingFang.ttc');
          if (f.existsSync()) candidates.add(f.path);
        }
      }
    }
  }
  candidates.addAll([
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
  ]);
  // 回退字体：主字体缺符号（如“−”“›”）时用 PingFang/其他系统字体补。
  final fallbacks = <String>[
    ...candidates.where((p) => p.contains('PingFang')),
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
  ];
  final fallbackPath = fallbacks.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => '',
  );
  if (fallbackPath.isNotEmpty) {
    final fb = FontLoader('TestCJKFallback')
      ..addFont(
        Future.value(
          ByteData.sublistView(File(fallbackPath).readAsBytesSync()),
        ),
      );
    await fb.load();
  }
  final path = candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => '',
  );
  if (path.isEmpty) return;
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader('TestCJK')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Use as `fontFamily` for text in golden tests (set once on the app's DefaultTextStyle).
const testFontFamily = 'TestCJK';
const testFontFallback = ['TestCJKFallback'];
