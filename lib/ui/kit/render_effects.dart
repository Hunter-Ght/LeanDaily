import 'package:flutter/foundation.dart';

/// Android currently uses Skia for device compatibility. Keep modal motion
/// inexpensive there; profile expensive effects explicitly before enabling them.
/// Dart defines allow A/B runs on the same device without changing app logic.
class RenderEffects {
  RenderEffects._();

  static bool get liveBlur =>
      _enabled(const String.fromEnvironment('LIVE_BLUR', defaultValue: 'auto'));

  static bool get sheetBackgroundTransform => _enabled(
    const String.fromEnvironment(
      'SHEET_BACKGROUND_TRANSFORM',
      defaultValue: 'auto',
    ),
  );

  static bool _enabled(String value) => switch (value) {
    'true' => true,
    'false' => false,
    _ => defaultTargetPlatform != TargetPlatform.android,
  };
}
