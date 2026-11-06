import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Text styles measured from the web app (see SPEC.md §3.1). Colors are applied by the caller via [AppPalette].
class AppText {
  static TextStyle navDay(AppPalette p) => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.03 * 34,
    height: 1.02,
    color: p.text,
  );
  static TextStyle navWeek(AppPalette p) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 15,
    color: p.secondary,
  );
  static TextStyle sect(AppPalette p) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 20,
    color: p.text,
  );
  static TextStyle calTitle(AppPalette p) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 15,
    color: p.secondary,
  );
  static TextStyle calLabel(AppPalette p) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.02 * 12,
    color: p.secondary,
  );
  static TextStyle calNum(
    AppPalette p, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontSize: 16,
    fontWeight: weight,
    letterSpacing: -0.02 * 16,
    color: color ?? p.text,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle weekGoal(AppPalette p) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.secondary);
  static TextStyle h2(AppPalette p) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.02 * 17,
    color: p.text,
  );
  static TextStyle body(AppPalette p) =>
      TextStyle(fontSize: 17, height: 1.35, color: p.text);
  static TextStyle hint(AppPalette p) =>
      TextStyle(fontSize: 13, height: 1.45, color: p.secondary);

  // 2026-11 设计规范：页面主标题、区块标题，以及数字读数（Numeral 字体、等宽数字）。
  static TextStyle display(AppPalette p, {double size = 32, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03 * size,
        height: 1.12,
        color: color ?? p.text,
      );
  static TextStyle title(AppPalette p) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 20,
    height: 1.2,
    color: p.text,
  );
  static TextStyle num(
    AppPalette p,
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => TextStyle(
    fontFamily: 'Numeral',
    fontSize: size,
    fontWeight: weight,
    height: 1.0,
    letterSpacing: -0.01 * size,
    color: color ?? p.text,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Provides the palette to the tree (light/dark follows the platform brightness).
class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});
  final AppPalette palette;
  static AppPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()!.palette;
  @override
  bool updateShouldNotify(PaletteScope old) => old.palette != palette;
}

extension PaletteX on BuildContext {
  AppPalette get pal => PaletteScope.of(this);
}
