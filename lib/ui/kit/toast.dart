import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../theme/theme.dart';
import 'pressable.dart';
import 'render_effects.dart';

/// 顶部的轻提示胶囊。从上方 12px 处淡入滑下。
class ToastHost extends StatelessWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context) {
    final toast = context.app.toast;
    return ListenableBuilder(
      listenable: toast,
      builder: (context, _) {
        final text = toast.text;
        return IgnorePointer(
          ignoring: toast.onAction == null,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
              ),
              child: MediaQuery.disableAnimationsOf(context)
                  ? (text == null
                        ? const SizedBox.shrink()
                        : _Pill(
                            text: text,
                            actionLabel: toast.actionLabel,
                            onAction: toast.onAction,
                          ))
                  : AnimatedSwitcher(
                      duration: Duration(
                        milliseconds: MediaQuery.disableAnimationsOf(context)
                            ? 0
                            : 220,
                      ),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, -0.4),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: text == null
                          ? const SizedBox.shrink(key: ValueKey('none'))
                          : _Pill(
                              key: ValueKey('${toast.seq}'),
                              text: text,
                              actionLabel: toast.actionLabel,
                              onAction: toast.onAction,
                            ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: p.shadow.withValues(alpha: p.shadow.a * 2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          enabled: RenderEffects.liveBlur,
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: p.ink,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: p.onTint,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (onAction != null) ...[
                    const SizedBox(width: 12),
                    Pressable(
                      onTap: onAction,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
                            actionLabel ?? '撤销',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.onTint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
