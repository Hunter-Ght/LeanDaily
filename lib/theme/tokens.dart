// 颜色来自 Web 版 app.css 的变量（spec/tokens.json）。新增的语义色（shadow/scrim/grab/onTint）在文件末尾标注。
import 'package:flutter/painting.dart';

class AppPalette {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.sep,
    required this.tint,
    required this.tintPress,
    required this.tintSoft,
    required this.ok,
    required this.err,
    required this.fill,
    required this.fill2,
    required this.studio,
    required this.ph,
    required this.seg,
    required this.segOn,
    required this.ink,
    required this.glassEdge,
    required this.glassHi,
    required this.glassLo,
    required this.glass,
    required this.volume,
    required this.detrain,
    required this.dotTrain,
    required this.dotMeal,
    required this.shadow,
    required this.scrim,
    required this.grab,
    required this.onTint,
    required this.kcal,
    required this.protein,
  });
  final Color bg;
  final Color card;
  final Color text;
  final Color secondary;
  final Color tertiary;
  final Color sep;
  final Color tint;
  final Color tintPress;
  final Color tintSoft;
  final Color ok;
  final Color err;
  final Color fill;
  final Color fill2;
  final Color studio; // 3D 示范影棚底色，烘焙进动画，两种主题相同
  final Color ph;
  final Color seg;
  final Color segOn;
  final Color ink;
  final Color glassEdge;
  final Color glassHi;
  final Color glassLo;
  final Color glass;
  final Color volume;
  final Color detrain;
  final Color dotTrain;
  final Color dotMeal;
  final Color shadow; // 浮层投影
  final Color scrim; // 弹层遮罩
  final Color grab; // 抓手条
  final Color onTint; // tint 底上的字
  final Color kcal; // 热量（青色）
  final Color protein; // 蛋白（橙色）。四件事：训练=tint，蛋白=protein，热量=kcal，坚持=ok

  static const light = AppPalette(
    bg: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF000000),
    secondary: Color(0x993C3C43),
    tertiary: Color(0x4C3C3C43),
    sep: Color(0x2E3C3C43),
    tint: Color(0xFFFF6A13),
    tintPress: Color(0xFFD9520A),
    tintSoft: Color(0x1FFF6A13),
    ok: Color(0xFF34C759),
    err: Color(0xFFFF3B30),
    fill: Color(0x29787880),
    fill2: Color(0x1F787880),
    studio: Color(0xFFEBEBEF),
    ph: Color(0x4C3C3C43),
    seg: Color(0x29787880),
    segOn: Color(0xFFFFFFFF),
    ink: Color(0xD11C1C1E),
    glassEdge: Color(0x24000000),
    glassHi: Color(0xE6FFFFFF),
    glassLo: Color(0x59FFFFFF),
    glass: Color(0xCCF4F4F6),
    volume: Color(0xFF34C759),
    detrain: Color(0xFF5E5CE6),
    dotTrain: Color(0xFFFF6A13),
    dotMeal: Color(0xFF30D158),
    shadow: Color(0x14000000),
    scrim: Color(0x52000000),
    grab: Color(0x5C787880),
    onTint: Color(0xFFFFFFFF),
    kcal: Color(0xFF32ADE6),
    protein: Color(0xFFFFB800),
  );

  static const dark = AppPalette(
    bg: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    text: Color(0xFFFFFFFF),
    secondary: Color(0x99EBEBF5),
    tertiary: Color(0x4CEBEBF5),
    sep: Color(0xA6545458),
    tint: Color(0xFFFF6A13),
    tintPress: Color(0xFFFF8F4F),
    tintSoft: Color(0x38FF6A13),
    ok: Color(0xFF30D158),
    err: Color(0xFFFF3B30),
    fill: Color(0x52787880),
    fill2: Color(0x3D787880),
    studio: Color(0xFFEBEBEF),
    ph: Color(0x4CEBEBF5),
    seg: Color(0x52787880),
    segOn: Color(0xFF636366),
    ink: Color(0xE02C2C2E),
    glassEdge: Color(0x2EFFFFFF),
    glassHi: Color(0x6BFFFFFF),
    glassLo: Color(0x14FFFFFF),
    glass: Color(0xC72A2A2C),
    volume: Color(0xFF30D158),
    detrain: Color(0xFF5E5CE6),
    dotTrain: Color(0xFFFF6A13),
    dotMeal: Color(0xFF30D158),
    shadow: Color(0x80000000),
    scrim: Color(0x52000000),
    grab: Color(0x5C787880),
    onTint: Color(0xFFFFFFFF),
    kcal: Color(0xFF64D2FF),
    protein: Color(0xFFFFC400),
  );
}

/// Layout metrics measured from the web app (CSS px == Flutter logical px at the same viewport width).
class Metrics {
  // Native touch targets and shared, restrained segmented-control geometry.
  static const double touchTarget = 44;
  static const double calendarSidePad = 16;
  static const double calendarChevronSize = 12;
  static const double calendarArrowSize = 17;
  static const double calendarGrabHeight = 4;
  static const double segmentRadius = 12;
  static const double segmentInset = 3;
  static const double segmentTextPad = 10;
  static const double segmentIconGap = 6;
  static const double segmentDeadZone = 4;
  static const double segmentShadow = 3;
  static const int musclePreviewCount = 5;
  static const double phoneMaxWidth = 480;
  static const double navBarHeight = 44; // + status bar inset
  static const double dockHeight =
      78; // phone: bottom tab bar block incl. margin
  static const double railWidth =
      92; // wide layouts (>=640 wide, >=480 tall): left nav rail
  static const double persistentCalendarWidth = 360; // >=780 wide
  static const double cardRadius = 22;
  static const double listCardRadius = 18;
  static const double pagePad = 16;
  static const double calRow =
      52; // calendar row height (week strip == one month row)
  static const double calExtra =
      52 * 5; // month panel height minus the one visible row
  static const double calTitle = 30;
  static const double calLabels = 20;
  static const double calGrab = 20;
  static const double calNum = 36; // day number circle diameter
  static const double calDot = 5;
  static const double wideBreakpoint = 640;
  static const double twoBreakpoint = 780;
  static const double colsBreakpoint = 1180;
  static const double minTallForWide = 480;
}

/// Motion constants (see reference/web-src/motion.js). Springs are response (seconds) + damping ratio, mass 1.
class Motion {
  static const selectionDuration = Duration(milliseconds: 180);
  static const calendarPageDuration = Duration(milliseconds: 260);
  static const double springResponse = 0.34;
  static const double pagerResponse = 0.32;
  static const double pagerDampingFast = 0.84; // when |velocity| > 240 px/s
  static const double pagerFlipFraction = 0.32;
  static const double pagerFlipMax = 150; // px
  static const double projectRate = 0.99; // decelerationRate used by project()
  static const double rubberConstant = 0.55;
  static const double calOpenThreshold =
      0.5; // projected progress > 0.5 -> open
  static const double weekFlipFraction = 0.28;
  static const double weekFlipMax = 120;
}
