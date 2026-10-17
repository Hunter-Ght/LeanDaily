import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import 'app_icon.dart';

const _partIcons = {
  '胸': 'chest',
  '背': 'back',
  '腿': 'legs',
  '肩': 'shoulder',
  '手臂': 'arm',
  '核心': 'core',
  '全身': 'full',
  '有氧': 'cardio',
};
const _mealIcons = {'早餐': 'sunrise', '午餐': 'sun', '晚餐': 'moon', '加餐': 'snack'};

/// 训练部位 → 图标名（未知部位用 train）。
String partIcon(String part) => _partIcons[part] ?? 'train';

/// 餐次 → 图标名。
String mealIcon(String meal) => _mealIcons[meal] ?? 'meal';

/// 圆形图标徽章：训练部位 / 餐次的小图标，按类型着色（Web 的 .badge.tone-*）。
class ToneBadge extends StatelessWidget {
  const ToneBadge({
    super.key,
    required this.icon,
    this.size = 32,
    this.iconSize,
  });

  /// 图标名（chest / back / legs / shoulder / arm / core / full / cardio / sunrise / sun / moon / snack …）。
  final String icon;
  final double size;
  final double? iconSize;

  /// 按训练部位（胸、背、腿…）取徽章。
  factory ToneBadge.part(
    String part, {
    Key? key,
    double size = 32,
    double? iconSize,
  }) =>
      ToneBadge(key: key, icon: partIcon(part), size: size, iconSize: iconSize);

  static ({Color bg, Color fg}) tone(AppPalette p, String icon, bool dark) {
    Color c(int v) => Color(v);
    switch (icon) {
      case 'back' || 'core':
        return (
          bg: c(0x24 << 24 | 0x5856D6),
          fg: dark ? c(0xFFC4C2FF) : c(0xFF5856D6),
        );
      case 'legs' || 'snack':
        return (
          bg: c(0x29 << 24 | 0x34C759),
          fg: dark ? c(0xFF30D158) : c(0xFF248A3D),
        );
      case 'shoulder' || 'sun':
        return (
          bg: c(0x2E << 24 | 0xFF9F0A),
          fg: dark ? c(0xFFFFB340) : c(0xFFC93400),
        );
      case 'arm' || 'sunrise':
        return (
          bg: c(0x24 << 24 | 0xFF375F),
          fg: dark ? c(0xFFFF6482) : c(0xFFD30F45),
        );
      case 'cardio' || 'moon':
        return (
          bg: c(0x29 << 24 | 0x5E5CE6),
          fg: dark ? c(0xFFC4C2FF) : c(0xFF4F46E5),
        );
      case 'full':
        return (
          bg: c(0x29 << 24 | 0x0A84FF),
          fg: dark ? c(0xFF64D2FF) : c(0xFF007AFF),
        );
      default:
        return (bg: p.tintSoft, fg: p.tint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final dark = p.bg.computeLuminance() < 0.1;
    final t = tone(p, icon, dark);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      alignment: Alignment.center,
      child: AppIcon(icon, color: t.fg, size: iconSize ?? size * 0.56),
    );
  }
}
