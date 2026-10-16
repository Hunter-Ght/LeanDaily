import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in device diagnostics, removed from normal release builds. These are
/// pipeline timings, not an FPS estimate from wall-clock widget tests.
class FrameTrace {
  FrameTrace._();
  static const enabled = bool.fromEnvironment('PERF_TRACE');
  static final _frames = <FrameTiming>[];
  static Timer? _timer;

  static void start() {
    if (!enabled || _timer != null) return;
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _report());
  }

  static void stop() {
    if (!enabled) return;
    _timer?.cancel();
    _timer = null;
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    _frames.clear();
  }

  static void _collect(List<FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length >= 120) _report();
  }

  static void _report() {
    if (_frames.isEmpty) return;
    final views = PlatformDispatcher.instance.views;
    final hz = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    debugPrint('[frame-trace] ${summarize(_frames, hz)}');
    _frames.clear();
  }

  @visibleForTesting
  static Map<String, num> summarize(List<FrameTiming> frames, double hz) {
    final rate = hz.isFinite && hz > 0 ? hz : 60.0;
    final budget = 1000 / rate;
    final builds =
        frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final rasters =
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    final starts =
        frames
            .map((f) => f.timestampInMicroseconds(FramePhase.vsyncStart))
            .toList()
          ..sort();
    final gaps = <double>[];
    for (var i = 1; i < starts.length; i++) {
      final gap = (starts[i] - starts[i - 1]) / 1000;
      // Exclude idle periods. Cadence is diagnostic evidence, not a count of
      // frames actually presented by SurfaceFlinger.
      if (gap > 0 && gap <= 50) gaps.add(gap);
    }
    gaps.sort();
    double p90(List<double> values) =>
        values.isEmpty ? 0 : values[(values.length * .9).ceil() - 1];
    return {
      'frames': frames.length,
      'refreshHz': rate,
      'budgetMs': budget,
      'buildP90Ms': p90(builds),
      'rasterP90Ms': p90(rasters),
      'vsyncGapP50Ms': gaps.isEmpty ? 0 : gaps[gaps.length ~/ 2],
      'pipelineOverBudget': frames
          .where(
            (f) =>
                f.buildDuration.inMicroseconds / 1000 > budget ||
                f.rasterDuration.inMicroseconds / 1000 > budget,
          )
          .length,
    };
  }
}
