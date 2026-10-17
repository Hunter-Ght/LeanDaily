import 'package:leandaily/l10n/app_messages.dart';

import '../l10n/localized_text.dart';

import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../ui/kit/app_icon.dart';
import '../ui/kit/glass.dart';
import '../ui/kit/pressable.dart';
import '../ui/kit/rest_bar.dart';
import '../ui/kit/render_effects.dart';
import '../ui/kit/sheet.dart';
import '../ui/kit/transitions.dart';
import '../ui/log/log_page.dart';
import '../ui/stats/stats_page.dart';
import '../ui/me/me_page.dart';
import '../ui/me/about_pages.dart';
import '../ui/today/today_page.dart';
import '../ui/onboarding/onboarding_flow.dart';
import 'app_controller.dart';
import 'boot_screen.dart';
import 'routes.dart';

/// 四个标签页 + 底部玻璃标签栏（宽屏时是左侧竖条）+ 右上角按钮 + 休息条。
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final p = context.pal;
    return ColoredBox(
      color: p.bg,
      child: ValueListenableBuilder<double>(
        valueListenable: sheetDepth,
        builder: (context, depth, child) {
          // Avoid transforming/clipping a full-screen backdrop-filter scene on
          // Android's compatibility renderer. The sheet itself still animates.
          if (!RenderEffects.sheetBackgroundTransform ||
              MediaQuery.disableAnimationsOf(context)) {
            return child!;
          }
          // 弹层打开时，后面的页面轻轻后退（iOS 卡片式层叠）。
          final scale = 1 - 0.045 * depth;
          return Transform(
            alignment: const Alignment(0, -0.84),
            transform: Matrix4.diagonal3Values(scale, scale, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20 * depth),
              child: child,
            ),
          );
        },
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) => FadeSwitcher(
            child: KeyedSubtree(
              key: ValueKey(
                !app.booted
                    ? 'boot'
                    : app.needsOnboarding
                    ? 'onboarding'
                    : 'main',
              ),
              child: !app.booted
                  ? BootScreen(error: app.bootError, onRetry: app.boot)
                  : app.needsOnboarding
                  ? const OnboardingFlow(upgrade: false)
                  : LayoutBuilder(
                      builder: (context, box) {
                        final rail =
                            box.maxWidth >= Metrics.wideBreakpoint &&
                            box.maxHeight >= Metrics.minTallForWide;
                        final two =
                            box.maxWidth >= Metrics.twoBreakpoint &&
                            box.maxHeight >= Metrics.minTallForWide;
                        return _Chrome(rail: rail, two: two, box: box);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.rail, required this.two, required this.box});
  final bool rail;
  final bool two;
  final BoxConstraints box;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final safe = MediaQuery.paddingOf(context);
    final railW = rail ? Metrics.railWidth : 0.0;
    final dockBottom = math.max(10.0, safe.bottom);
    return Stack(
      children: [
        Positioned.fill(
          left: railW,
          child: PageHost(rail: rail, two: two),
        ),
        // 右上角按钮
        Positioned(
          top: 0,
          left: railW,
          right: 0,
          child: _NavButtons(tab: app.tab),
        ),
        // 休息条
        Positioned(
          left: rail ? railW + 12 : 12,
          right: rail ? null : 12,
          width: rail ? math.min(480.0, box.maxWidth - railW - 36) : null,
          bottom: rail ? 16 : dockBottom + 56 + 8 + 8,
          child: const RestBar(),
        ),
        if (rail)
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            width: 64,
            child: Center(
              child: Dock(vertical: true, tab: app.tab, onTab: app.setTab),
            ),
          )
        else
          Positioned(
            bottom: dockBottom,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: math.min(360.0, box.maxWidth - 20),
                child: Dock(vertical: false, tab: app.tab, onTab: app.setTab),
              ),
            ),
          ),
      ],
    );
  }
}

/// 四个页面。切换标签时保留各页滚动位置。
class PageHost extends StatefulWidget {
  const PageHost({super.key, required this.rail, required this.two});
  final bool rail;
  final bool two;

  @override
  State<PageHost> createState() => _PageHostState();
}

class _PageHostState extends State<PageHost>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 120),
  );
  int? _tab;
  final Set<int> _visited = {};
  @override
  void didUpdateWidget(PageHost old) {
    super.didUpdateWidget(old);
    final tab = context.app.tab;
    if (_tab != null && _tab != tab) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
    _tab = tab;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    _tab ??= app.tab;
    _visited.add(app.tab);
    final pages = <Widget Function()>[
      () => TodayPage(wide: widget.rail, two: widget.two),
      () => LogPage(wide: widget.rail, two: widget.two),
      () => StatsPage(wide: widget.rail, two: widget.two),
      () => MePage(wide: widget.rail),
    ];
    return FadeTransition(
      opacity: _fade,
      child: IndexedStack(
        index: app.tab,
        sizing: StackFit.expand,
        children: [
          for (var i = 0; i < pages.length; i++)
            TickerMode(
              enabled: app.tab == i,
              child: _visited.contains(i)
                  ? pages[i]()
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  const _NavButtons({required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 10, 0),
      child: SizedBox(
        height: Metrics.navBarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (tab == 1)
              _GlassIconButton(
                icon: 'plus',
                color: p.tint,
                label: '记一笔',
                onTap: () => openAddMenu(context),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final String icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppMessages.of(context).text(label),
    child: Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: GlassSurface(
            radius: 18,
            shadow: false,
            blur: 20,
            child: SizedBox.square(
              dimension: 36,
              child: Center(child: AppIcon(icon, color: color, size: 18)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 底部玻璃标签栏（或宽屏的左侧竖条）。选中块用弹簧滑动。
class Dock extends StatefulWidget {
  const Dock({
    super.key,
    required this.vertical,
    required this.tab,
    required this.onTab,
  });
  final bool vertical;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  State<Dock> createState() => _DockState();
}

class _DockState extends State<Dock> with SingleTickerProviderStateMixin {
  static const _labels = ['今日', '记录', '进度', '我的'];
  static const _icons = ['flame', 'train', 'rings', 'me'];
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.tab.toDouble(),
  );

  @override
  void didUpdateWidget(Dock old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pos.value = widget.tab.toDouble();
        return;
      }
      final sim = SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: 320,
          ratio: 0.82,
        ),
        _pos.value,
        widget.tab.toDouble(),
        _pos.velocity,
      );
      _pos.animateWith(sim);
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final vertical = widget.vertical;
    final itemH = vertical ? 60.0 : 48.0;
    const gap = 2.0;
    return GlassSurface(
      radius: vertical ? 32 : 30,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, box) {
            final itemW = vertical ? box.maxWidth : box.maxWidth / 4;
            final step = vertical ? itemH + gap : itemW;
            return SizedBox(
              height: vertical ? itemH * 4 + gap * 3 : itemH + 4,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _pos,
                    builder: (context, _) => Positioned(
                      left: vertical ? 0 : _pos.value * step,
                      top: vertical ? _pos.value * step : 0,
                      width: itemW,
                      height: itemH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.tintSoft,
                          borderRadius: BorderRadius.circular(
                            vertical ? 28 : 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: vertical ? 0 : i * step,
                      top: vertical ? i * step : 0,
                      width: itemW,
                      height: itemH,
                      child: Pressable(
                        scale: 0.94,
                        haptic: widget.tab != i,
                        onTap: () => widget.onTab(i),
                        child: _DockItem(
                          icon: _icons[i],
                          label: _labels[i],
                          selected: widget.tab == i,
                          updateDot: i == 3 && context.app.hasUnseenUpdate,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.updateDot = false,
  });
  final bool updateDot;
  final String icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = selected ? p.tint : p.secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: AppMessages.of(context).text(label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppIcon(icon, color: color, size: 25, solid: selected),
              if (updateDot)
                const Positioned(right: -6, top: -3, child: UpdateDot()),
            ],
          ),
          const SizedBox(height: 1),
          LText(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
