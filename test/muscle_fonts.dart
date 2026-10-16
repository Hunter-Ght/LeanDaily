import 'dart:io';

import 'package:flutter/services.dart';

import 'support/fonts.dart';

/// PingFang's first TTC face may omit rare simplified glyphs (for example 腘).
/// Keep the shared loader, then register system fallbacks for screenshot coverage.
Future<void> loadMuscleTestFonts() async {
  await loadTestFonts();
  for (final entry in {
    'MuscleSongti': '/System/Library/Fonts/Supplemental/Songti.ttc',
    'MuscleUnicode': '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
  }.entries) {
    final file = File(entry.value);
    if (file.existsSync()) {
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
    }
  }
}

const muscleFontFallback = ['MuscleSongti', 'MuscleUnicode'];
