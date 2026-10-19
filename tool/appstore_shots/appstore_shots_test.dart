// 生成 App Store 截图用的真实界面（iPhone 18 Pro：402×874 pt，@3x = 1206×2622）：
//   LEANDAILY_SAFE_AREA=1 LEANDAILY_SAFE_TOP=62 LEANDAILY_SAFE_BOTTOM=34 LEANDAILY_SHOT_SCALE=3 \
//   LEANDAILY_SHOT_DIR=out/appstore/raw LEANDAILY_TEST_FONT=out/fonts/PingFangSC-Regular.ttf \
//   TZ=Asia/Shanghai flutter test tool/appstore_shots/appstore_shots_test.dart
// 再由 tool/appstore_shots/compose.py 排成 1320×2868 的商店图。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/app/routes.dart' show openQuickFood;
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';

import '../../test/support/harness.dart';
import '../../test/onboarding_test.dart' show next, settle;
import '../../test/today_sheets_test.dart' show loadExerciseImages;
import '../../test/training_mode_test.dart' show seedPlan, enter, tap, images;

// iPad 13" 用 LEANDAILY_SHOT_SIZE=1032x1376（@2x = 2064×2752）；默认是 iPhone 18 Pro。
final _size = () {
  final v = Platform.environment['LEANDAILY_SHOT_SIZE']?.split('x');
  return v == null ? const Size(402, 874) : Size(double.parse(v[0]), double.parse(v[1]));
}();

Map<String, dynamic> _profile() => {
  'sex': 'male',
  'age': 28,
  'heightCm': 175,
  'weightKg': 74,
  'bodyFatMethod': 'manual',
  'bodyFatPct': 19,
  'activity': 'light',
  'venue': 'both',
  'daysPerWeek': 3,
  'experience': 'new',
  'limits': <String>[],
};

String _body({double start = 76.2, double step = -.07, int days = 84}) =>
    jsonEncode({
      'v': 1,
      'entries': [
        for (var i = 0; i < days; i++)
          {
            'date': DateTime(
              2026,
              7,
              25 + i,
            ).toIso8601String().substring(0, 10),
            'weightKg': double.parse((start + step * i).toStringAsFixed(1)),
          },
      ],
    });

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });

  testWidgets('2 plan recommendation', (tester) async {
    final h = await Harness.pump(tester, newUser: true, size: _size);
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    await tester.tap(find.bySemanticsLabel('两边都会去'));
    await settle(tester);
    final main = find.byWidgetPredicate(
      (w) => w is PlanCard && w.size == PlanCardSize.large,
    );
    await tester.ensureVisible(main);
    await settle(tester);
    await h.shot(tester, '2-plan');
  });

  testWidgets('1 today', (tester) async {
    final h = await Harness.pump(
      tester,
      size: _size,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode(_profile());
        n.docs['fw-body-v1'] = _body();
      },
    );
    await tester.pumpAndSettle();
    await loadExerciseImages(tester);
    await h.shot(tester, '1-today');
  });

  testWidgets('4 training set', (tester) async {
    final h = await Harness.pump(
      tester,
      size: _size,
      empty: true,
      seed: seedPlan,
    );
    await images(tester);
    // 示范图按设备像素比解码（200pt × 3 = 600 px），预热对应尺寸的缓存。
    final context = tester.element(find.byType(TodayPage));
    await tester.runAsync(() async {
      for (final f
          in Directory('assets/exercises')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.jpg'))) {
        await precacheImage(
          ResizeImage(AssetImage(f.path), width: 600),
          context,
        );
      }
    });
    await enter(tester);
    await tap(tester, '热身完成');
    // 示范图是异步解码的，给真实 IO 一点时间再截图。
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }
    await h.shot(tester, '4-train');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('3 muscle recovery', (tester) async {
    final h = await Harness.pump(
      tester,
      size: _size,
      tab: 2,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode(_profile());
        n.docs['fw-body-v1'] = _body();
      },
    );
    await tester.pumpAndSettle();
    // 人体图路径是异步读资源文件的：给真实 IO 一点时间，肌肉卡才会出现。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('肌肉状态').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(StatsPage), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await Scrollable.ensureVisible(
      tester.element(find.text('肌肉状态').first),
      alignment: 0.075,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await h.shot(tester, '3-muscle');
  });

  testWidgets('5 progress', (tester) async {
    final h = await Harness.pump(
      tester,
      size: _size,
      tab: 2,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode({
          'age': 30,
          'heightCm': 180,
          'weightKg': 82,
          'bodyFatPct': 28,
          'bodyFatMethod': 'manual',
          'goalBodyFatPct': 15,
        });
        n.docs['fw-body-v1'] = _body(start: 82, step: -.045);
      },
    );
    await tester.pumpAndSettle();
    // 肌肉状态卡依赖异步读取的人体图，等它出现（现在排在体重路线后面第二位）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    await h.shot(tester, '5-progress');
  });

  testWidgets('6 meals', (tester) async {
    final h = await Harness.pump(
      tester,
      size: _size,
      empty: true,
      seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(_profile()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TodayPage));
    context.app.foods ??= Foods.parse(
      File('assets/foods.json').readAsStringSync(),
    );
    openQuickFood(context);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    for (final name in ['豆浆油条', '鸡蛋牛奶全麦面包早餐']) {
      await tester.tap(find.bySemanticsLabel('选择 $name'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('加入'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
    }
    await h.shot(tester, '6-meals');
  });
}
