import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

import 'glass.dart';
import 'app_icon.dart';
import 'sheet.dart' show sheetDepth;

/// Only the horizontal navigation dock opts in. Other GlassSurfaces, Android,
/// web, older iOS and a missing native bridge keep the existing renderer.
class IosDockGlass extends StatefulWidget {
  const IosDockGlass({
    super.key,
    required this.child,
    required this.tab,
    required this.labels,
    required this.onTab,
    required this.tint,
    required this.dark,
    required this.updateDot,
  });
  final Widget child;
  final int tab;
  final List<String> labels;
  final ValueChanged<int> onTab;
  final Color tint;
  final bool dark;
  final bool updateDot;

  @override
  State<IosDockGlass> createState() => _IosDockGlassState();
}

class _IosDockGlassState extends State<IosDockGlass> {
  static const _channel = MethodChannel('leandaily/dock-glass');
  late final Future<bool> _supported = _checkSupport();

  List<Uint8List> _icons = const [];

  Future<bool> _checkSupport() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      if (await _channel.invokeMethod<bool>('isSupported') != true) {
        return false;
      }
      _icons = await AppIcon.navigationImages();
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _supported,
    builder: (context, snapshot) {
      if (snapshot.data != true) return GlassSurface(child: widget.child);
      // A Flutter sheet blurs/transforms the underlying scene. Native glass
      // cannot reliably participate in that backdrop pass, so use the original
      // surface while a sheet is present, including its entrance/exit animation.
      return ValueListenableBuilder<double>(
        valueListenable: sheetDepth,
        builder: (context, depth, _) {
          if (depth > 0) return GlassSurface(child: widget.child);
          return _NativeDock(
            icons: _icons,
            tab: widget.tab,
            labels: widget.labels,
            onTab: widget.onTab,
            tint: widget.tint,
            dark: widget.dark,
            updateDot: widget.updateDot,
          );
        },
      );
    },
  );
}

/// Own the channel for exactly one platform view; Flutter owns page state.
class _NativeDock extends StatefulWidget {
  const _NativeDock({
    required this.icons,
    required this.tab,
    required this.labels,
    required this.onTab,
    required this.tint,
    required this.dark,
    required this.updateDot,
  });
  final List<Uint8List> icons;
  final int tab;
  final List<String> labels;
  final ValueChanged<int> onTab;
  final Color tint;
  final bool dark, updateDot;
  @override
  State<_NativeDock> createState() => _NativeDockState();
}

class _NativeDockState extends State<_NativeDock> {
  MethodChannel? _channel;
  Map<String, Object> get _configuration => {
    'selected': widget.tab,
    'labels': widget.labels,
    'tint': widget.tint.toARGB32(),
    'dark': widget.dark,
    'updateDot': widget.updateDot,
  };
  void _created(int id) {
    _channel = MethodChannel('leandaily/dock-glass/$id');
    _channel!.setMethodCallHandler((call) async {
      if (!mounted || call.method != 'select') return;
      final tab = call.arguments;
      if (tab is int && tab >= 0 && tab < 4) widget.onTab(tab);
    });
    _update();
  }

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', _configuration);
    } on PlatformException {
      // The platform view may be disposed while a sheet is opening.
    } on MissingPluginException {
      // The native view has already been detached.
    }
  }

  @override
  void didUpdateWidget(_NativeDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: UiKitView(
      viewType: 'leandaily/dock-glass',
      layoutDirection: Directionality.of(context),
      creationParams: {..._configuration, 'icons': widget.icons},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _created,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    ),
  );
}
