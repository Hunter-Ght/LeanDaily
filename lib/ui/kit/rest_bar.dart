import 'package:leandaily/l10n/app_messages.dart';

import '../../l10n/localized_text.dart';

import 'dart:async';

import '../../core/haptics.dart';

import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../theme/theme.dart';
import 'glass.dart';
import 'pressable.dart';

/// 组间休息倒计时条：浮在底部标签栏上方。
class RestBar extends StatefulWidget {
  const RestBar({super.key});
  @override
  State<RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<RestBar> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _ensureTick(bool on) {
    if (on && _tick == null) {
      _tick = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => setState(() {}),
      );
    } else if (!on) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.rest, app]),
      builder: (context, _) {
        final active = app.rest.active;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureTick(active);
        });
        return MediaQuery.disableAnimationsOf(context)
            ? (active ? _Bar(app: app) : const SizedBox.shrink())
            : AnimatedSwitcher(
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 260,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: active
                    ? _Bar(key: const ValueKey('rest'), app: app)
                    : const SizedBox.shrink(key: ValueKey('idle')),
              );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.app});
  final AppController app;

  void _pick(int sec) {
    if (app.restSeconds != sec || !app.rest.active) app.haptics.selection();
    app.saveRestPrefs({...app.restPrefs, 'sec': sec});
    app.startRest(sec);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final left =
        ((app.rest.untilMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil()
            .clamp(0, 99999);
    final label = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    Widget chip(String text, VoidCallback onTap, {bool on = false}) =>
        Pressable(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.tintSoft : p.tintSoft.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: LText(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.tint,
              ),
            ),
          ),
        );
    return Semantics(
      label: AppMessages.of(context).text('组间休息 $label'),
      child: GlassSurface(
        radius: 26,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: LText(
                    label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.66,
                      color: p.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                chip('90 秒', () => _pick(90), on: app.restSeconds == 90),
                chip('2 分钟', () => _pick(120), on: app.restSeconds == 120),
                chip('+30', () {
                  HapticScope.of(context)?.selection();
                  app.rest.add(30);
                }),
                chip('跳过', () {
                  app.haptics.selection();
                  app.rest.clear();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
