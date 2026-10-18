// 宣传片的 App 画面：按固定时钟逐帧渲染（30 fps、iPhone 18 Pro 402×874 pt，@2.5 倍），写成 PNG 序列：
//   LEANDAILY_SAFE_AREA=1 LEANDAILY_SAFE_TOP=62 LEANDAILY_SAFE_BOTTOM=34 LEANDAILY_SHOT_SCALE=2.5 \
//   LEANDAILY_TEST_FONT=out/fonts/PingFangSC-Regular.ttf TZ=Asia/Shanghai \
//   flutter test tool/promo/promo_frames_test.dart [--plain-name today]
// 输出 out/promo/frames/<场景>/00000.png … 以及 events.json（点按的位置，供合成时画触点）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/stats/stats_page.dart';

import '../../test/support/harness.dart';
import '../../test/today_sheets_test.dart' show loadExerciseImages;
import '../../test/training_mode_test.dart' show seedPlan, images;

const _size = Size(402, 874);
const _fps = 30;

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

String _body() => jsonEncode({
  'v': 1,
  'entries': [
    for (var i = 0; i < 84; i++)
      {
        'date': DateTime(2026, 7, 25 + i).toIso8601String().substring(0, 10),
        'weightKg': double.parse((76.2 - .07 * i).toStringAsFixed(1)),
      },
  ],
});

/// 一个场景的录制器：每次 [frames] 前进若干帧并截图。
class Rec {
  Rec(this.t, this.h, this.name) {
    dir = Directory('out/promo/frames/$name')..createSync(recursive: true);
    for (final f in dir.listSync().whereType<File>()) {
      f.deleteSync();
    }
  }
  final WidgetTester t;
  final Harness h;
  final String name;
  late final Directory dir;
  int n = 0;
  final events = <Map<String, dynamic>>[];

  Future<void> grab() async {
    final boundary =
        h.shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: Harness.shotScale);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${dir.path}/${n.toString().padLeft(5, '0')}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    n++;
  }

  /// 前进 [ms] 毫秒，每 1/30 秒截一帧。
  Future<void> run(int ms) async {
    final count = (ms * _fps / 1000).round();
    for (var i = 0; i < count; i++) {
      await t.pump(const Duration(milliseconds: 1000 ~/ _fps));
      await grab();
    }
  }

  /// 点一下并记下位置（毫秒数换成帧号）。
  Future<void> tap(Finder f, {int after = 700}) async {
    final p = t.getCenter(f.first);
    events.add({'frame': n, 'x': p.dx, 'y': p.dy, 'type': 'tap'});
    await t.tap(f.first);
    await run(after);
  }

  void finish() => File(
    '${dir.path}/events.json',
  ).writeAsStringSync(jsonEncode({'fps': _fps, 'frames': n, 'events': events}));
}

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await MiniBody.load();
  });

  testWidgets('today', (t) async {
    final h = await Harness.pump(
      t,
      size: _size,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode(_profile());
        n.docs['fw-body-v1'] = _body();
      },
    );
    await t.pumpAndSettle();
    await loadExerciseImages(t);
    final r = Rec(t, h, 'today');
    await r.run(1200);
    // 慢慢往下滑，看“今日动作”列表。
    final g = await t.startGesture(const Offset(200, 600));
    for (var i = 0; i < 36; i++) {
      await g.moveBy(const Offset(0, -9));
      await r.run(34);
    }
    await g.up();
    await r.run(700);
    r.finish();
  });

  testWidgets('train', (t) async {
    final h = await Harness.pump(t, size: _size, empty: true, seed: seedPlan);
    await images(t);
    final r = Rec(t, h, 'train');
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await r.run(600);
    // 点“开始训练”进入训练模式，跳过热身，看示范图自己动。
    await r.tap(find.text('开始训练'), after: 900);
    await r.tap(find.text('热身完成'), after: 700);
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    }
    await r.run(3200);
    await r.tap(find.text('完成第 1 组'), after: 1600);
    r.finish();
  });

  testWidgets('plan', (t) async {
    final h = await Harness.pump(t, size: _size, newUser: true);
    final r = Rec(t, h, 'plan');
    await r.run(900);
    for (var i = 0; i < 3; i++) {
      await r.tap(find.bySemanticsLabel('继续'), after: 1100);
    }
    await r.tap(find.bySemanticsLabel('两边都会去'), after: 900);
    final main = find.byWidgetPredicate(
      (w) => w is PlanCard && w.size == PlanCardSize.large,
    );
    await t.ensureVisible(main);
    await r.run(1800);
    // 向左滑动对比其他推荐方案。
    final g = await t.startGesture(const Offset(300, 700));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-14, 0));
      await r.run(34);
    }
    await g.up();
    await r.run(1400);
    r.finish();
  });

  testWidgets('muscle', (t) async {
    final h = await Harness.pump(
      t,
      size: _size,
      tab: 2,
      seed: (n) {
        n.docs['fw-profile-v1'] = jsonEncode(_profile());
        n.docs['fw-body-v1'] = _body();
      },
    );
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pumpAndSettle();
    for (var i = 0; i < 30 && find.text('肌肉状态').evaluate().isEmpty; i++) {
      await t.drag(find.byType(StatsPage), const Offset(0, -300));
      await t.pumpAndSettle();
    }
    final r = Rec(t, h, 'muscle');
    await r.run(500);
    // 平滑滚到肌肉卡。
    final target = t.element(find.text('肌肉状态').first);
    // 不能 await：动画靠下面逐帧前进。
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.075,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      ),
    );
    await r.run(1500);
    await r.tap(find.text('训练量'), after: 1500);
    await r.tap(find.text('久未练'), after: 1500);
    await r.tap(find.text('恢复状态'), after: 1700);
    r.finish();
  });
}
