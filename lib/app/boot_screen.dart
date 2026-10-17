import '../l10n/localized_text.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../theme/theme.dart';
import '../ui/kit/transitions.dart';
import '../ui/kit/pressable.dart';
import 'diagnostics.dart';

/// 启动中 / 启动失败的画面。启动卡住时能看见卡在哪一步和错误内容，而不是一片空白。
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, this.error = '', this.onRetry});
  final String error;
  final VoidCallback? onRetry;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Native bootstrap precedes WidgetsApp/PaletteScope. Follow the same
    // platform brightness until the app provides its palette.
    final p =
        context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ??
        ((MediaQuery.maybePlatformBrightnessOf(context) ??
                    WidgetsBinding
                        .instance
                        .platformDispatcher
                        .platformBrightness) ==
                Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
    final failed = widget.error.isNotEmpty;
    return ColoredBox(
      color: p.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              Diagnostics.step,
              Diagnostics.errors,
            ]),
            builder: (context, _) {
              final errors = Diagnostics.errors.value;
              final style = TextStyle(
                fontSize: 13,
                height: 1.45,
                color: p.secondary,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400,
              );
              return FadeSwitcher(
                child: Column(
                  key: ValueKey('$failed:$_slow:${errors.length}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (failed)
                      LText(
                        '打不开',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    if (failed) const SizedBox(height: 8),
                    if (failed)
                      LText(
                        widget.error,
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                    if (failed || _slow || errors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      LText(
                        '启动步骤：${Diagnostics.step.value}',
                        textAlign: TextAlign.center,
                        style: style,
                      ),
                      for (final e in errors)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: LText(
                            e,
                            textAlign: TextAlign.left,
                            style: style.copyWith(fontSize: 11),
                          ),
                        ),
                    ],
                    if (failed && widget.onRetry != null) ...[
                      const SizedBox(height: 16),
                      Pressable(
                        onTap: widget.onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: p.tintSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: LText(
                            '重试',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: p.tint,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 界面构建出错时的显示（替代发布版里的空白灰块），方便定位问题。
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppPalette.light.card,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: LText(
        text,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: AppPalette.light.err,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}
