import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One policy for touch feedback. The system decides the device-specific effect.
class AppHaptics {
  AppHaptics({required this.isEnabled});
  final bool Function() isEnabled;

  bool? _enabledOverride;
  bool? get enabledOverride => _enabledOverride;
  set enabledOverride(bool? value) {
    _enabledOverride = value;
    if (value == false) _cancel();
  }

  Timer? _second;
  DateTime? _lastTick;
  bool get _enabled =>
      (enabledOverride ?? isEnabled()) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _play(Future<void> Function() effect) {
    if (_enabled) unawaited(effect().catchError((Object _) {}));
  }

  void selection() {
    if (_second == null) _play(HapticFeedback.selectionClick);
  }

  /// Long presses and sliders can generate many events in one frame.
  void tick() {
    if (!_enabled || _second != null) return;
    final now = DateTime.now();
    if (_lastTick != null && now.difference(_lastTick!).inMilliseconds < 80) {
      return;
    }
    _lastTick = now;
    _play(HapticFeedback.selectionClick);
  }

  void saved() {
    _cancel();
    _play(HapticFeedback.lightImpact);
  }

  void exerciseCompleted() {
    _cancel();
    _play(HapticFeedback.mediumImpact);
  }

  void completed() => _pair(HapticFeedback.mediumImpact);
  void restEnded() => _pair(HapticFeedback.lightImpact);

  void _pair(Future<void> Function() second) {
    _cancel();
    if (!_enabled) return;
    _play(HapticFeedback.lightImpact);
    _second = Timer(const Duration(milliseconds: 130), () {
      _second = null;
      _play(second);
    });
  }

  void _cancel() {
    _second?.cancel();
    _second = null;
  }

  void dispose() => _cancel();
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
