import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One policy for touch feedback. The system decides the device-specific effect.
class AppHaptics {
  AppHaptics({required this.isEnabled});
  final bool Function() isEnabled;

  void _play(Future<void> Function() effect) {
    if (isEnabled()) unawaited(effect().catchError((Object _) {}));
  }

  void selection() => _play(HapticFeedback.selectionClick);
  void saved() => _play(HapticFeedback.lightImpact);
  void completed() => _play(HapticFeedback.mediumImpact);
}

class HapticScope extends InheritedWidget {
  const HapticScope({super.key, required this.haptics, required super.child});
  final AppHaptics haptics;

  static AppHaptics? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HapticScope>()?.haptics;

  @override
  bool updateShouldNotify(HapticScope oldWidget) =>
      haptics != oldWidget.haptics;
}
