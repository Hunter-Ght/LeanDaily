import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_messages.dart';

import '../core/native.dart';
import '../core/haptics.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/kit/app_icon.dart';
import '../ui/kit/toast.dart';
import '../ui/kit/transitions.dart';
import 'app_controller.dart';
import 'diagnostics.dart';
import 'boot_screen.dart';
import 'shell.dart';
import 'frame_trace.dart';

/// 根组件：调色板（跟随系统深浅色）、控制器、导航栈、全局轻提示。
class LeanDailyApp extends StatefulWidget {
  const LeanDailyApp({
    super.key,
    required this.controller,
    this.fontFamily,
    this.fontFamilyFallback,
  });
  final AppController controller;

  /// 仅测试用：截图测试里指定一个带中文的字体。
  final String? fontFamily;

  /// 仅测试/截图用：主字体缺字时的回退字体。
  final List<String>? fontFamilyFallback;

  @override
  State<LeanDailyApp> createState() => _LeanDailyAppState();
}

class _LeanDailyAppState extends State<LeanDailyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FrameTrace.start();
    // The outgoing launcher still listens to Diagnostics during its fade.
    // Start after this build so boot notifications cannot dirty that sibling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.boot();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FrameTrace.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.resume();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
    widget.controller.refreshLocalizedReminders();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => WidgetsApp(
        color:
            MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark ||
                (MediaQuery.maybePlatformBrightnessOf(context) == null &&
                    WidgetsBinding
                            .instance
                            .platformDispatcher
                            .platformBrightness ==
                        Brightness.dark)
            ? AppPalette.dark.bg
            : AppPalette.light.bg,
        debugShowCheckedModeBanner: false,
        locale: controller.resolvedLocale,
        supportedLocales: AppMessages.locales,
        localizationsDelegates: const [
          AppMessages.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        builder: (context, navigator) {
          final dark =
              MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          final palette = dark ? AppPalette.dark : AppPalette.light;
          return PaletteScope(
            palette: palette,
            child: AppScope(
              controller: controller,
              child: HapticScope(
                haptics: controller.haptics,
                child: DefaultTextStyle(
                  style: AppText.body(palette).copyWith(
                    fontFamily: widget.fontFamily,
                    fontFamilyFallback: widget.fontFamilyFallback,
                  ),
                  child: ColoredBox(
                    color: palette.bg,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [?navigator, const ToastHost()],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: const AppShell(),
      ),
    );
  }
}

/// 启动：先把界面画出来（显示启动步骤），再加载图标、时区，创建控制器。
Future<void> runLeanDaily(Native native) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    Diagnostics.error(d.exceptionAsString(), d.stack);
    FlutterError.presentError(d);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    Diagnostics.error(e, st);
    return true;
  };
  ErrorWidget.builder = (d) => ErrorBox(text: d.exceptionAsString());
  runApp(_Launcher(native: native));
}

class _Launcher extends StatefulWidget {
  const _Launcher({required this.native});
  final Native native;
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  AppController? _controller;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      Diagnostics.at('加载图标');
      await AppIcon.load();
      Diagnostics.at('读取时区');
      String? tz;
      try {
        tz = await widget.native.deviceTz().timeout(const Duration(seconds: 5));
      } on Object catch (e) {
        Diagnostics.error('读取时区失败：$e');
      }
      if (!mounted) return;
      setState(
        () => _controller = AppController(native: widget.native, deviceTz: tz),
      );
    } on Object catch (e, st) {
      Diagnostics.error(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) {
          final palette =
              MediaQuery.platformBrightnessOf(context) == Brightness.dark
              ? AppPalette.dark
              : AppPalette.light;
          return Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: palette.bg,
              child: FadeSwitcher(
                child: c != null
                    ? LeanDailyApp(key: const ValueKey('app'), controller: c)
                    : const BootScreen(key: ValueKey('launcher-boot')),
              ),
            ),
          );
        },
      ),
    );
  }
}
