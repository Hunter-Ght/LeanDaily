import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/domain/records.dart' show needsAfterPhoto;
import 'package:leandaily/ui/kit/number_field.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/kit/photo_image.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;

final Uint8List jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A/bCiiitDoP/Z',
);
Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is SheetInput && w.label == label),
  matching: find.byType(EditableText),
);
Future<void> openMeal(
  WidgetTester tester, {
  Map<String, dynamic>? preset,
}) async {
  openMealSheet(tester.element(find.byType(Navigator).first), preset: preset);
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(input(label).first);
  await tester.enterText(input(label).first, value);
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Map<String, dynamic> saved(Harness h) =>
    jsonDecode(h.native.docs['android-state']!) as Map<String, dynamic>;
Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('meal manual save and screenshots $dark', (tester) async {
      final h = await Harness.pump(tester, dark: dark, empty: true);
      await openMeal(tester);
      await h.shot(tester, 'sheet-meal-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('添加食物'));
      await tester.pumpAndSettle();
      await enter(tester, '食物', '米饭');
      await enter(tester, '份量', '约200g');
      await enter(tester, '热量', '232');
      await enter(tester, '蛋白', '4.5');
      await enter(tester, '碳水', '51');
      await enter(tester, '脂肪', '0.6');
      await tester.drag(find.byType(MealSheet), const Offset(0, 1200));
      await tester.pumpAndSettle();
      await h.shot(tester, 'sheet-meal-filled-${dark ? 'dark' : 'light'}');
      await save(tester);
      final m = (saved(h)['meals'] as Map).values.single as Map;
      expect(m['kcal'], 232);
      expect(m['protein'], 4.5);
      expect(m['source'], '手动填写');
      expect(m['meal'], '早餐');
      expect(m['time'], '09:00');
      expect(h.native.docs['android-meal-draft:${h.controller.date}'], 'null');
      expect(find.byType(MealSheet), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      h.controller.vision.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDisableShadows = true;
    });
  }
  testWidgets('draft restoration and explicit discard', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await openMeal(tester);
    await enter(tester, '补充', '米饭只吃了一半');
    await tester.pump(const Duration(milliseconds: 350));
    SheetController.of(tester.element(find.byType(MealSheet))).close();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await openMeal(tester);
    expect(tester.widget<EditableText>(input('补充')).controller.text, '米饭只吃了一半');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('放弃这餐？'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(h.native.docs['android-meal-draft:${h.controller.date}'], 'null');
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });
  testWidgets('empty save, invalid time and failed write stay open', (
    tester,
  ) async {
    final h = await Harness.pump(tester, empty: true);
    await openMeal(tester);
    await save(tester);
    expect(find.text('至少拍一张、写一个食物，或写一句备注'), findsOneWidget);
    await enter(tester, '补充', '备注');
    await enter(tester, '时间', '25:00');
    await save(tester);
    expect(find.text('时间无效'), findsOneWidget);
    await enter(tester, '时间', '12:00');
    await tester.pump(const Duration(milliseconds: 350));
    h.native.failNextPut = const NativeError('保存失败');
    await save(tester);
    expect(find.byType(MealSheet), findsOneWidget);
    expect(find.text('保存失败'), findsOneWidget);
    await save(tester);
    expect((saved(h)['meals'] as Map).length, 1);
    await tester.pump(const Duration(seconds: 3));
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });
  testWidgets('photo selection, per-phase limit, removal and edit', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    h.native.pickResult = List.filled(8, jpeg);
    await openMeal(tester);
    await tester.tap(find.text('相册').first);
    await tester.pumpAndSettle();
    // 每一栏最多 2 张：一次选 8 张，只收前 2 张。
    expect(find.byType(PhotoImage), findsNWidgets(2));
    // 这一栏满了，再点相册不会再加。
    await tester.tap(find.text('相册').first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoImage), findsNWidgets(2));
    await tester.tap(find.bySemanticsLabel(RegExp('移除照片')).first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoImage), findsNWidgets(1));
    await save(tester);
    final m = (saved(h)['meals'] as Map).values.single as Map;
    expect((m['photo_ids'] as List).length, 1);
    expect(m['photo_phases'], ['before']);
    expect(m['source'], '待分析');
    await openMeal(
      tester,
      preset: {'editId': m['record_id'], ...Map<String, dynamic>.from(m)},
    );
    expect(find.text('编辑饮食'), findsOneWidget);
    await enter(tester, '补充', '修改后的备注');
    await save(tester);
    final updated = (saved(h)['meals'] as Map).values.single as Map;
    expect(updated['note'], '修改后的备注');
    expect((updated['photo_ids'] as List).length, 1);
    expect(updated['photo_phases'], ['before']);
    await tester.pump(const Duration(seconds: 3));
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });
  for (final corrected in [false, true]) {
    testWidgets('AI result source corrected=$corrected', (tester) async {
      final h = await Harness.pump(
        tester,
        empty: true,
        seed: (native) {
          native.docs['android-settings'] = jsonEncode({
            'model': 'test',
            'baseUrl': 'https://example.test',
          });
          native.secrets = const Secrets(modelKey: 'test');
          native.onHttp = (_) => HttpReply(
            200,
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'items': [
                        {
                          'name': '鸡蛋',
                          'portion': '1个',
                          'kcal': 70,
                          'protein': 6,
                          'carbs': 1,
                          'fat': 5,
                        },
                      ],
                      'summary': '鸡蛋',
                      'confidence': '高',
                    }),
                  },
                },
              ],
            }),
          );
          native.pickResult = [jpeg];
        },
      );
      await openMeal(tester);
      await tester.tap(find.text('拍照').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('识别营养'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(input('食物'), findsOneWidget);
      if (corrected) await enter(tester, '热量', '80');
      await save(tester);
      final m = (saved(h)['meals'] as Map).values.single as Map;
      expect(m['source'], corrected ? 'AI识别+手动修正' : 'AI识别');
      expect(m['kcal'], corrected ? 80 : 70);
      await tester.pump(const Duration(seconds: 3));
      h.controller.vision.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDisableShadows = true;
    });
  }
  testWidgets('analysis cancellation and failure', (tester) async {
    final pending = Completer<HttpReply>();
    final h = await Harness.pump(
      tester,
      empty: true,
      seed: (native) {
        native.docs['android-settings'] = jsonEncode({
          'model': 'test',
          'baseUrl': 'https://example.test',
        });
        native.secrets = const Secrets(modelKey: 'test');
        native.pickResult = [jpeg];
        native.onHttp = (_) => pending.future;
      },
    );
    await openMeal(tester);
    await tester.tap(find.text('相册').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('识别营养'));
    await tester.pumpAndSettle();
    expect(find.text('取消识别'), findsOneWidget);
    await tester.tap(find.text('取消识别'));
    await tester.pumpAndSettle();
    expect(h.native.cancelledHttp, isNotEmpty);
    pending.complete(const HttpReply(500, '{}'));
    await tester.pumpAndSettle();
    h.native.onHttp = (_) => const HttpReply(500, '{}');
    await tester.tap(find.text('识别营养'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('识别失败，请检查接口、密钥和网络后手动重试'), findsOneWidget);
    expect(input('食物'), findsOneWidget);
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });
  Future<Harness> aiHarness(
    WidgetTester tester, {
    required Map<String, dynamic> reply,
    void Function(Map body)? onBody,
  }) => Harness.pump(
    tester,
    empty: true,
    seed: (native) {
      native.docs['android-settings'] = jsonEncode({
        'model': 'test',
        'baseUrl': 'https://example.test',
      });
      native.secrets = const Secrets(modelKey: 'test');
      native.pickResult = [jpeg];
      native.onHttp = (call) {
        onBody?.call(jsonDecode(call.body!) as Map);
        return HttpReply(
          200,
          jsonEncode({
            'choices': [
              {
                'message': {'content': jsonEncode(reply)},
              },
            ],
          }),
        );
      };
    },
  );
  Future<void> analyzeNow(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('before + after photos are sent in order and saved as a comparison', (
    tester,
  ) async {
    Map? body;
    final h = await aiHarness(
      tester,
      onBody: (b) => body = b,
      reply: {
        'items': [
          {'name': '米饭', 'portion': '吃了约150g（剩1/4）', 'kcal': 174, 'protein': 3.4, 'carbs': 38, 'fat': .5},
        ],
        'eaten_ratio': .75,
        'summary': '吃得不多',
        'confidence': '高',
      },
    );
    await openMeal(tester);
    await tester.tap(find.text('拍照').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('相册').last);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoImage), findsNWidgets(2));
    expect(find.text('按吃前吃后对比识别'), findsOneWidget);
    await analyzeNow(tester, '按吃前吃后对比识别');
    final content = (body!['messages'] as List).single['content'] as List;
    expect(
      content.where((e) => e['type'] == 'text').map((e) => e['text']).take(2),
      ['第1张（吃之前）', '第2张（吃完后）'],
    );
    // 前后对比算出的就是实际摄入，不再出现“吃了多少”。
    expect(find.text('这一餐你吃了多少？'), findsNothing);
    await save(tester);
    final m = (saved(h)['meals'] as Map).values.single as Map;
    expect(m['photo_phases'], ['before', 'after']);
    expect(m['basis'], '前后对比');
    expect(m['kcal'], 174);
    expect(m['source'], 'AI识别');
    await tester.pump(const Duration(seconds: 3));
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('only a before photo: estimate whole plate, then scale by what was eaten', (
    tester,
  ) async {
    final h = await aiHarness(
      tester,
      reply: {
        'items': [
          {'name': '鸡蛋', 'portion': '2个', 'kcal': 140, 'protein': 12, 'carbs': 2, 'fat': 10},
        ],
        'summary': '两个蛋',
        'confidence': '中',
      },
    );
    await openMeal(tester);
    await tester.tap(find.text('拍照').first);
    await tester.pumpAndSettle();
    await analyzeNow(tester, '识别营养');
    expect(find.text('这一餐你吃了多少？'), findsOneWidget);
    await tester.tap(find.text('½'));
    await tester.pumpAndSettle();
    expect(find.text('70'), findsWidgets);
    await save(tester);
    final m = (saved(h)['meals'] as Map).values.single as Map;
    expect(m['basis'], '仅吃前估算');
    expect(m['kcal'], 70);
    expect(m['protein'], 6);
    expect(m['items'].single['portion'], '2个（吃了约½）');
    expect(m['source'], 'AI识别');
    expect(m['photo_phases'], ['before']);
    await tester.pump(const Duration(seconds: 3));
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('我吃光了 settles the meal; otherwise a before-only meal asks for the after photo', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
      seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
    );
    h.native.pickResult = [jpeg];
    await openMeal(tester);
    await tester.tap(find.text('拍照').first);
    await tester.pumpAndSettle();
    await save(tester);
    var m = (saved(h)['meals'] as Map).values.single as Map;
    expect(needsAfterPhoto(m), true);
    // 首页营养条带给出一条轻提示，点它直接回到这餐补拍。
    expect(find.text('早餐还差一张吃完后的照片 ›'), findsOneWidget);
    await tester.tap(find.text('早餐还差一张吃完后的照片 ›'));
    await tester.pumpAndSettle();
    expect(find.text('编辑饮食'), findsOneWidget);
    await tester.tap(find.text('我吃光了'));
    await tester.pumpAndSettle();
    expect(find.text('已标记吃光了，不用补拍'), findsOneWidget);
    await save(tester);
    m = (saved(h)['meals'] as Map).values.single as Map;
    expect(m['after_skipped'], true);
    expect(needsAfterPhoto(m), false);
    expect(find.text('早餐还差一张吃完后的照片 ›'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    h.controller.vision.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDisableShadows = true;
  });

  testWidgets('keyboard keeps food fields and save reachable', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await openMeal(tester);
    await tester.tap(find.text('添加食物'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(input('脂肪'));
    await tester.enterText(input('脂肪'), '5');
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(input('脂肪')).dy, lessThanOrEqualTo(550));
    expect(find.text('保存').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 350));
    h.controller.vision.dispose();
    debugDisableShadows = true;
  });
}
