import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/foods.dart';
import '../kit/menu.dart';
import '../kit/sheet.dart';
import '../sheets/food/portion_panel.dart';

/// 记录页右下角加号：列出所有新增入口，都记到所选日期 [date]。
Future<void> openLogAddMenu(BuildContext context, String date) async {
  final app = context.app;
  var configured = false;
  try {
    final secrets = await app.native.secretsGet();
    configured =
        secrets.modelKey.isNotEmpty &&
        '${app.settings.value['model'] ?? ''}'.isNotEmpty &&
        '${app.settings.value['baseUrl'] ?? ''}'.isNotEmpty;
  } on Object {
    // 读取失败按未配置处理，仍可先存照片。
  }
  if (!context.mounted) return;
  final picked = await showActionMenu(
    context,
    message: configured ? null : '未设置 AI，可先存照片',
    actions: const [
      MenuAction(id: 'train', label: '记一组', icon: 'train'),
      MenuAction(id: 'meal', label: '拍照记饮食', icon: 'camera'),
      MenuAction(id: 'powder', label: '加蛋白粉', icon: 'protein'),
      MenuAction(id: 'adjust', label: '加蛋白粉并调整份量', icon: 'protein'),
      MenuAction(id: 'quick', label: '搜索 / 手动记饮食', icon: 'search'),
    ],
  );
  if (!context.mounted) return;
  switch (picked?.id) {
    case 'train':
      openTrainSheet(context);
    case 'meal':
      openMealSheet(context, preset: {'date': date});
    case 'quick':
      openQuickFood(context, date: date);
    case 'powder':
      await app.addProteinPowder(date);
    case 'adjust':
      final entry = await showAppSheet<Map<String, dynamic>>(
        context,
        (_) => FoodPortionPanel(
          food: proteinPowderFood(
            (app.plan['protein'] as Map?)?['powder'] as Map?,
          ),
        ),
      );
      if (entry != null) await app.addProteinPowder(date, entry: entry);
  }
}
