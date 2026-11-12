import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/ui/kit/body_figure.dart';
import 'package:leandaily/ui/kit/form.dart' show FormSwitch;
import 'package:leandaily/ui/share/share_card.dart';
import 'package:leandaily/ui/share/share_data.dart';
import 'package:leandaily/ui/share/share_sheet.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

import 'support/harness.dart';

/// 练了胸、背、腹；两条纪录（一条带重量、一条自重）。
TrainShare train({
  String name = '胸 + 背 + 腹',
  bool records = true,
  int minutes = 52,
}) => trainShareFrom(
  iso: '2026-10-16',
  workoutName: name,
  minutes: minutes,
  rows: [
    for (var i = 0; i < 4; i++) {'ex': '哑铃地板卧推', 'part': '胸'},
    for (var i = 0; i < 3; i++) {'ex': '单臂哑铃划船', 'part': '背'},
    for (var i = 0; i < 3; i++) {'ex': '反向卷腹', 'part': '核心'},
    for (var i = 0; i < 2; i++) {'ex': '高位下拉', 'part': '背'},
  ],
  records: records
      ? const [
          ShareRecord(name: '哑铃地板卧推', detail: '8 次', load: '22.5 kg × 8'),
          ShareRecord(name: '反向卷腹', detail: '18 次'),
        ]
      : const [],
);

Map<String, Map<String, dynamic>> daysOf(List<String> dates) => {
  for (final d in dates)
    d: {
      'sets': [
        for (var i = 0; i < 3; i++)
          {
            'id': '$d-$i',
            'ex': '高位俯卧撑',
            'part': '胸',
            'w': 0,
            'reps': 9,
            'type': '正式',
            'date': d,
          },
      ],
    },
};

/// 只练了一天的一周（休息很多）。
WeekShare lightWeek() => WeekShare.build(daysOf(['2026-10-14']), '2026-10-16')!;

Future<void> frames(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// 人体图的几何数据是真实 I/O 读出来的，要给真实时间。
Future<void> bodyReady(WidgetTester t) async {
  for (var i = 0; i < 30 && !BodyFigure.isLoaded; i++) {
    BodyFigure.load();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }
}

Future<void> open(WidgetTester t, ShareContent c) async {
  await bodyReady(t);
  openShareSheet(t.element(find.byType(TodayPage)), c);
  await frames(t, 8);
}

Future<void> close(WidgetTester t) async {
  final label = [
    '关闭',
    'Close',
    '關閉',
  ].firstWhere((l) => find.text(l).evaluate().isNotEmpty);
  await t.tap(find.text(label));
  await frames(t, 15);
  expect(find.byType(ShareCard), findsNothing);
}

/// 新增文案的英文要等主线程统一导入后才有；测试两种情况都认。
Finder either(String zh, String en) =>
    find.text(find.text(en).evaluate().isNotEmpty ? en : zh);

/// 只在卡片里找（卡片后面的页面也有同样的字）。
Finder inCard(String text) =>
    find.descendant(of: find.byType(ShareCard), matching: find.text(text));

Finder inCardContaining(String text) => find.descendant(
  of: find.byType(ShareCard),
  matching: find.textContaining(text),
);

Finder inCardEither(String zh, String en) => find.descendant(
  of: find.byType(ShareCard),
  matching: find.text(
    find
            .descendant(of: find.byType(ShareCard), matching: find.text(en))
            .evaluate()
            .isNotEmpty
        ? en
        : zh,
  ),
);

String get shotDir =>
    Platform.environment['LEANDAILY_SHOT_DIR'] ?? 'out/shots-share';

RenderRepaintBoundary cardBoundary(WidgetTester t) =>
    t.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byType(ShareCard),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );

/// 把当前预览里的卡片按导出的方式渲染成 PNG，写到截图目录；返回字节。
Future<Uint8List> exportCard(WidgetTester t, String name) async {
  final boundary = cardBoundary(t);
  return (await t.runAsync(() async {
    final png = await renderShareCard(boundary);
    final file = File('$shotDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png);
    return png;
  }))!;
}

(int, int) pngSize(Uint8List b) {
  final d = ByteData.sublistView(b);
  return (d.getUint32(16), d.getUint32(20));
}

List<String> cardTexts(WidgetTester t) => [
  for (final w in t.widgetList<Text>(
    find.descendant(of: find.byType(ShareCard), matching: find.byType(Text)),
  ))
    w.textSpan?.toPlainText() ?? w.data ?? '',
];

const forbidden = [
  'kg',
  'lb',
  'kcal',
  '千卡',
  '体重',
  '体脂',
  '腰围',
  '热量',
  '饮食',
  '磅',
  '蛋白',
  'weight',
  'calorie',
  'diet',
];

void expectPrivate(WidgetTester t) {
  final all = cardTexts(t).join('\n').toLowerCase();
  for (final word in forbidden) {
    expect(all.contains(word), isFalse, reason: '卡片上不应出现“$word”：$all');
  }
}

Future<void> shareNow(WidgetTester t, FakeNative native, int count) async {
  await t.tap(find.text('分享图片'));
  for (var i = 0; i < 40 && native.shared.length < count; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump();
  }
}

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('训练卡：内容、隐私、重量开关、导出与分享', (t) async {
    final h = await Harness.pump(t, size: const Size(393, 852));
    await open(t, train());
    // 有新纪录：标题、三个数字、两条记录、落款。
    expect(inCard('胸·背·腹'), findsOneWidget);
    expect(inCard('新纪录'), findsOneWidget);
    expect(inCard('哑铃地板卧推'), findsOneWidget);
    expect(inCard('反向卷腹'), findsOneWidget);
    expect(inCard('4'), findsOneWidget); // 4 个动作
    expect(inCard('12'), findsOneWidget); // 12 组
    expect(inCard('52'), findsOneWidget); // 52 分钟
    expect(inCard('LeanDaily'), findsOneWidget);
    // 重量默认不显示，自重动作的次数照常显示。
    expect(inCard('18 次'), findsOneWidget);
    expect(inCardContaining('22.5'), findsNothing);
    expectPrivate(t);
    await h.shot(t, 'sheet-train-light-45');

    // 打开“显示重量”后才出现重量；其余隐私词依然没有。
    await t.tap(find.byType(FormSwitch));
    await frames(t);
    expect(inCard('22.5 kg × 8'), findsOneWidget);
    await t.tap(find.byType(FormSwitch));
    await frames(t);
    expect(inCardContaining('22.5'), findsNothing);

    // 默认 4:5，导出 1080×1350。
    var bytes = await exportCard(t, 'card-train-light-45');
    expect(pngSize(bytes), (1080, 1350));

    await shareNow(t, h.native, 1);
    expect(h.native.shared, hasLength(1));
    final shared = h.native.shared.single;
    expect(shared.bytes, isNotEmpty);
    expect(shared.bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
    expect(pngSize(shared.bytes), (1080, 1350));
    expect(shared.name, 'LeanDaily-workout-2026-10-16.png');
    expect(shared.anchor, isNotNull);

    // 9:16 + 深色。
    await t.tap(find.text('9:16'));
    await frames(t);
    await t.tap(find.text('深色'));
    await frames(t);
    await h.shot(t, 'sheet-train-dark-916');
    bytes = await exportCard(t, 'card-train-dark-916');
    expect(pngSize(bytes), (1080, 1920));
    await shareNow(t, h.native, 2);
    expect(pngSize(h.native.shared.last.bytes), (1080, 1920));
    await close(t);

    // 无新纪录：不出现“新纪录”，也没有“显示重量”开关。
    await open(t, train(records: false));
    await t.tap(find.text('深色'));
    await frames(t);
    expect(inCard('新纪录'), findsNothing);
    expect(find.byType(FormSwitch), findsNothing);
    await exportCard(t, 'card-train-dark-45-norecord');
    await t.tap(find.text('9:16'));
    await frames(t);
    await t.tap(find.text('浅色'));
    await frames(t);
    await exportCard(t, 'card-train-light-916-norecord');
    await close(t);
  });

  testWidgets('分享失败时给出提示，按钮恢复可点', (t) async {
    final h = await Harness.pump(t, size: const Size(393, 852));
    await open(t, train());
    h.native.failNextShare = const NativeError('暂时无法打开分享面板');
    await shareNow(t, h.native, 1);
    await frames(t);
    expect(h.native.shared, isEmpty);
    await shareNow(t, h.native, 1);
    expect(h.native.shared, hasLength(1));
    await close(t);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('周卡：本周数据、休息很多的一周、隐私', (t) async {
    final h = await Harness.pump(t, size: const Size(393, 852));
    final app = h.controller;
    final week = WeekShare.build({
      for (final e in app.repo.allDays().entries)
        e.key: Map<String, dynamic>.from(e.value as Map),
    }, app.today)!;
    // 10 月 13、15、16 日练了；往前两周也练了，连续 3 周。
    expect(week.start, '2026-10-12');
    expect(week.end, '2026-10-18');
    expect(week.trained, [false, true, false, true, true, false, false]);
    expect(week.streakWeeks, 3);
    expect(week.sets, greaterThan(0));
    expect(week.heat, isNotEmpty);

    await open(t, week);
    expect(find.text('3'), findsWidgets);
    expect(inCard('天训练'), findsOneWidget);
    expect(inCard('周连续'), findsOneWidget);
    expect(inCard('10月12日 – 10月18日'), findsOneWidget);
    expectPrivate(t);
    await h.shot(t, 'sheet-week-light-45');
    var bytes = await exportCard(t, 'card-week-light-45');
    expect(pngSize(bytes), (1080, 1350));
    await t.tap(find.text('深色'));
    await frames(t);
    await exportCard(t, 'card-week-dark-45');
    await t.tap(find.text('9:16'));
    await frames(t);
    bytes = await exportCard(t, 'card-week-dark-916');
    expect(pngSize(bytes), (1080, 1920));
    // 周卡没有重量，也就没有“显示重量”。
    expect(find.byType(FormSwitch), findsNothing);
    await close(t);

    // 只练了一天：不到 2 周不写连续周数，改写动作数。
    final light = lightWeek();
    expect(light.trainDays, 1);
    expect(light.streakWeeks, 1);
    await open(t, light);
    expect(inCard('周连续'), findsNothing);
    expect(inCard('个动作'), findsOneWidget);
    await exportCard(t, 'card-week-light-45-restweek');
    await close(t);
  });

  testWidgets('英文：长部位名与长动作名不溢出', (t) async {
    final h = await Harness.pump(
      t,
      size: const Size(393, 852),
      locale: const Locale('en'),
    );
    await open(t, train(name: '胸 + 肩 + 背 + 腿 + 手臂 + 腹'));
    expect(t.takeException(), isNull);
    expect(
      cardTexts(t).any((s) => s.contains('Chest\u00A0· Shoulders')),
      isTrue,
    );
    await h.shot(t, 'sheet-train-en-long');
    await exportCard(t, 'card-train-en-long-45');
    await t.tap(either('深色', 'Dark'));
    await frames(t);
    await t.tap(find.text('9:16'));
    await frames(t);
    expect(t.takeException(), isNull);
    await exportCard(t, 'card-train-en-long-dark-916');
    await close(t);

    await open(t, train());
    expect(inCard('Chest\u00A0· Back\u00A0· Abs'), findsOneWidget);
    expect(inCard('exercises'), findsOneWidget);
    expect(inCard('New PB'), findsOneWidget);
    expect(inCard('Fri, Oct 16'), findsOneWidget);
    expect(t.takeException(), isNull);
    await exportCard(t, 'card-train-en-45');
    await close(t);

    await open(t, lightWeek());
    expect(inCard('Oct 12 – Oct 18'), findsOneWidget);
    expect(inCardEither('天训练', 'days trained'), findsOneWidget);
    expect(t.takeException(), isNull);
    await exportCard(t, 'card-week-en-45');
    await close(t);
  });

  testWidgets('繁体中文也不溢出', (t) async {
    await Harness.pump(
      t,
      size: const Size(393, 852),
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    );
    await open(t, train());
    expect(t.takeException(), isNull);
    await exportCard(t, 'card-train-hant-45');
    await close(t);
  });

  test('周卡数据：没有本周记录时为 null，连续周数按周断开', () {
    expect(WeekShare.build({}, '2026-10-16'), isNull);
    expect(WeekShare.build(daysOf(['2026-10-08']), '2026-10-16'), isNull);
    // 本周、上周、上上周练了，再往前隔一周：连续 3。
    expect(
      WeekShare.build(
        daysOf(['2026-10-14', '2026-10-08', '2026-10-01', '2026-09-17']),
        '2026-10-16',
      )!.streakWeeks,
      3,
    );
    // 热身组和待写入的组不算。
    final skipped = {
      '2026-10-14': {
        'sets': [
          {'id': 'w', 'ex': '高位俯卧撑', 'part': '胸', 'type': '热身'},
          {'id': 'pending-1', 'ex': '高位俯卧撑', 'part': '胸', 'type': '正式'},
        ],
      },
    };
    expect(WeekShare.build(skipped, '2026-10-16'), isNull);
  });

  test('训练卡数据：标题、肌肉、纪录上限', () {
    expect(TrainShare.titleOf('胸 + 背 + 腹', const []), '胸 · 背 · 腹');
    expect(TrainShare.titleOf('训练', const ['胸', '背', '胸']), '胸 · 背');
    expect(TrainShare.titleOf('', const []), '训练');
    final c = trainShareFrom(
      iso: '2026-10-16',
      workoutName: '胸',
      minutes: 0,
      rows: [
        {'ex': '哑铃地板卧推', 'part': '胸'},
      ],
      records: [
        for (var i = 0; i < 5; i++) ShareRecord(name: '动作$i', detail: '$i 次'),
      ],
    );
    expect(c.minutes, 1);
    expect(c.records, hasLength(2));
    expect(c.tones.values, contains(MuscleTone.effort));
    const loaded = ShareRecord(name: 'a', detail: '8 次', load: '60 kg × 8');
    expect(loaded.shown(false), isNull);
    expect(loaded.shown(true), '60 kg × 8');
    expect(const ShareRecord(name: 'b', detail: '8 次').shown(false), '8 次');
  });

  testWidgets('训练小结页：分享入口打开预览，纪录进入卡片，分享调用原生', (t) async {
    final h = await Harness.pump(
      t,
      empty: true,
      size: const Size(393, 852),
      seed: (n) {
        final plan = jsonDecode(n.docs['fw-plan-v1']!) as Map;
        plan['workouts']['w3']['exercises'] = [
          {
            'id': 'test-load',
            'name': '哑铃地板卧推',
            'part': '胸',
            'sets': 1,
            'min': 10,
            'max': 12,
            'weight': 5,
            'unit': 'reps',
            'core': true,
            'rest': 90,
          },
        ];
        n.docs['fw-plan-v1'] = jsonEncode(plan);
        // 以前练过更轻的：今天这组会破纪录。
        n.docs['android-state'] = jsonEncode({
          'version': 1,
          'revision': 1,
          'meals': {},
          'notes': {},
          'tasks': {},
          'idem': {},
          'sync': {'lastSuccess': '', 'error': ''},
          'sets': {
            'old': {
              'id': 'old',
              'ts': 1791889320000,
              'date': '2026-10-13',
              'part': '胸',
              'ex': '哑铃地板卧推',
              'no': 1,
              'w': 2.5,
              'reps': 5,
              'type': '正式',
              'notes': '',
            },
          },
        });
      },
    );
    openTrainingMode(
      t.element(find.byType(TodayPage)),
      exerciseId: 'test-load',
    );
    await frames(t, 10);
    if (find.text('跳过热身').evaluate().isNotEmpty) {
      await t.tap(find.text('跳过热身'));
      await frames(t, 8);
    }
    await t.tap(find.text('完成第 1 组'));
    await t.pump(const Duration(milliseconds: 900));
    await frames(t, 10);
    expect(find.text('练完了'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    await bodyReady(t);
    await t.tap(find.text('分享'));
    await frames(t, 10);
    expect(find.text('分享图片'), findsOneWidget);
    expect(cardTexts(t), contains('胸·背·腹'));
    expect(cardTexts(t), contains('哑铃地板卧推'));
    expect(find.text('新纪录'), findsWidgets);
    expectPrivate(t);
    await shareNow(t, h.native, 1);
    expect(h.native.shared, hasLength(1));
    expect(h.native.shared.single.bytes, isNotEmpty);
    await close(t);
    h.controller.rest.clear();
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('进度页「本周回顾」里有分享入口，空记录时没有', (t) async {
    final h = await Harness.pump(t, tab: 2, size: const Size(393, 2600));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(find.text('本周回顾'));
    await frames(t, 8);
    expect(find.text('分享'), findsOneWidget);
    await t.tap(find.text('分享'));
    await frames(t, 8);
    expect(find.byType(ShareCard), findsOneWidget);
    expect(inCard('天训练'), findsOneWidget);
    expect(find.text('分享图片'), findsOneWidget);
    await shareNow(t, h.native, 1);
    expect(h.native.shared.single.name, 'LeanDaily-week-2026-10-12.png');
    await close(t);
  });
}
