import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';

class Motion3dClip {
  const Motion3dClip({
    required this.file,
    required this.frames,
    required this.period,
    required this.peakFrame,
    required this.phases,
  });
  final String file;
  final int frames, peakFrame;
  final double period;
  final List<(int, String)> phases;
}

class Motion3dLibrary {
  static Map<String, Motion3dClip>? loaded;
  static Future<Map<String, Motion3dClip>>? _loading;

  static Future<Map<String, Motion3dClip>> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<Map<String, Motion3dClip>> _load(AssetBundle bundle) async {
    final manifest = jsonDecode(
      await bundle.loadString('assets/motion3d/manifest.json'),
    ) as Map;
    return loaded = (manifest['exercises'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        Motion3dClip(
          file: value['file'] as String,
          frames: value['frames'] as int,
          period: (value['period'] as num).toDouble(),
          peakFrame: value['peakFrame'] as int,
          phases: [
            for (final phase in value['phases'] as List)
              (phase[0] as int, phase[1] as String),
          ],
        ),
      ),
    );
  }
}

class Motion3dDemo extends StatefulWidget {
  const Motion3dDemo({
    super.key,
    required this.clip,
    this.paused = false,
    this.still = false,
    this.showPhase = false,
  });
  final Motion3dClip clip;
  final bool paused, still, showPhase;

  @override
  Motion3dDemoState createState() => Motion3dDemoState();
}

class Motion3dDemoState extends State<Motion3dDemo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  ui.Codec? _codec;
  ui.Image? _image;
  ui.FrameInfo? _next;
  Duration _duration = Duration.zero,
      _elapsed = Duration.zero,
      _last = Duration.zero;
  int _frame = 0, _generation = 0;
  bool _enabled = true;

  @visibleForTesting
  int get debugFrame => _frame;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(Motion3dDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip != widget.clip || oldWidget.still != widget.still) {
      _load();
    } else {
      _sync();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _ticker.stop();
    _codec?.dispose();
    _codec = null;
    _image?.dispose();
    _image = null;
    _next?.image.dispose();
    _next = null;
    _frame = 0;
    _elapsed = Duration.zero;
    final clip = widget.clip;
    final still = widget.still;
    final bytes = await rootBundle.load(clip.file);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    if (!mounted || generation != _generation) {
      codec.dispose();
      return;
    }
    _codec = codec;
    // 静态模式逐帧前进，立即释放略过的图像，不缓存整段动画。
    final target = still ? clip.peakFrame : 0;
    for (var i = 0; i <= target; i++) {
      final frame = await codec.getNextFrame();
      if (!mounted || generation != _generation) {
        frame.image.dispose();
        return;
      }
      _image?.dispose();
      _image = frame.image;
      _duration = frame.duration;
      _frame = i;
    }
    setState(() {});
    if (!still) _prefetch(generation, codec);
    _sync();
  }

  Future<void> _prefetch(int generation, ui.Codec codec) async {
    final next = await codec.getNextFrame();
    if (!mounted || generation != _generation) {
      next.image.dispose();
      return;
    }
    _next = next;
  }

  void _sync() {
    if (widget.paused || widget.still || !_enabled || _image == null) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    _elapsed += elapsed - _last;
    _last = elapsed;
    final next = _next;
    if (_elapsed < _duration || next == null) return;
    _elapsed -= _duration;
    _next = null;
    setState(() {
      _image?.dispose();
      _image = next.image;
      _duration = next.duration;
      _frame = (_frame + 1) % widget.clip.frames;
    });
    _prefetch(_generation, _codec!);
  }

  @override
  void dispose() {
    _generation++;
    _ticker.dispose();
    _codec?.dispose();
    _image?.dispose();
    _next?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    var phase = '';
    for (final entry in widget.clip.phases) {
      if (entry.$1 > _frame) break;
      phase = entry.$2;
    }
    return ColoredBox(
      color: p.studio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RawImage(
            image: _image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          if (widget.showPhase)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.scrim,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: LText(
                  '$phase${widget.paused ? ' · 已暂停' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.onTint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
