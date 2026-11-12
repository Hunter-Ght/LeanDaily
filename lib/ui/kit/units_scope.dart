import 'package:flutter/widgets.dart';

import '../../domain/units.dart';

/// 把当前单位制放进 Widget 树。读 [UnitsContext.units] 的界面会在切换单位后重建。
class UnitsScope extends InheritedWidget {
  const UnitsScope({super.key, required this.units, required super.child});
  final Units units;

  static Units? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UnitsScope>()?.units;

  @override
  bool updateShouldNotify(UnitsScope old) => old.units != units;
}

extension UnitsContext on BuildContext {
  /// 没有 [UnitsScope]（单独测试某个控件）时按公制。
  Units get units => UnitsScope.maybeOf(this) ?? Units.metric;
}
