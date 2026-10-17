import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/ui/me/me_page.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/sheets/body_log_sheet.dart' show BodyLogSheet;
import 'package:leandaily/ui/kit/number_field.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('body log screenshot $dark', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        dark: dark,
        size: const Size(393, 852),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode({
            'weightKg': 70.2,
            'waistCm': 80,
          });
          n.docs['fw-body-v1'] = jsonEncode({
            'v': 1,
            'entries': [
              {'date': '2026-10-14', 'weightKg': 70.5},
              {'date': '2026-10-15', 'weightKg': 70.2},
            ],
          });
        },
      );
      openBodyLog(tester.element(find.byType(MePage)));
      await tester.pumpAndSettle();
      await h.shot(tester, 'r-body-log-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'save, same date overwrite, profile switch, yesterday, validation',
    (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        seed: (n) => n.docs['fw-profile-v1'] = jsonEncode({'weightKg': 70}),
      );
      Future<void> open() async {
        openBodyLog(tester.element(find.byType(MePage)));
        await tester.pumpAndSettle();
      }

      Future<void> input(String text) async {
        await tester.enterText(
          find.descendant(
            of: find.byType(SheetInput).first,
            matching: find.byType(EditableText),
          ),
          text,
        );
      }

      Future<void> save() async {
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
      }

      await open();
      await input('71.2');
      await save();
      expect(h.controller.bodyEntries.single['weightKg'], 71.2);
      expect(h.controller.profile!['weightKg'], 71.2);
      expect(jsonDecode(h.native.docs['fw-body-v1']!)['entries'], hasLength(1));
      await open();
      await input('72.3');
      await tester.tap(
        find.descendant(
          of: find.byType(BodyLogSheet),
          matching: find.byType(FormSwitch),
        ),
      );
      await tester.pumpAndSettle();
      await save();
      expect(h.controller.bodyEntries.single['weightKg'], 72.3);
      expect(h.controller.profile!['weightKg'], 71.2);
      await open();
      await input('10');
      await save();
      expect(find.textContaining('请输入 30'), findsOneWidget);
      await input('72.0');
      await tester.tap(find.text('昨天'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同时记腰围'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(SheetInput).last,
          matching: find.byType(EditableText),
        ),
        '81',
      );
      await save();
      expect(h.controller.bodyEntries, hasLength(2));
      expect(h.controller.bodyEntries.first['date'], '2026-10-15');
      expect(h.controller.bodyEntries.first['waistCm'], 81);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  // 备份恢复会把“没有记录”写成 JSON null；坏掉的文档也不能让之后每次保存都失败。
  for (final raw in ['null', 'oops', '{"v":2,"entries":[]}']) {
    testWidgets('stored body document "$raw" never blocks a valid weight', (
      tester,
    ) async {
      final h = await Harness.pump(
        tester,
        tab: 3,
        empty: true,
        seed: (n) {
          n.docs['fw-body-v1'] = raw;
          n.docs['fw-profile-v1'] = jsonEncode({'weightKg': 65});
        },
      );
      openBodyLog(tester.element(find.byType(MePage)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(BodyLogSheet), findsNothing);
      expect(find.textContaining('请输入'), findsNothing);
      expect(h.controller.bodyEntries.single['weightKg'], 65);
      expect(jsonDecode(h.native.docs['fw-body-v1']!)['entries'], hasLength(1));
      // 真正损坏的文档会另存一份，不会悄悄丢掉。
      expect(h.native.docs['fw-body-v1-corrupt'], raw == 'null' ? isNull : raw);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('out of range weight still shows the range hint', (tester) async {
    final h = await Harness.pump(
      tester,
      tab: 3,
      empty: true,
      seed: (n) => n.docs['fw-profile-v1'] = jsonEncode({'weightKg': 65}),
    );
    openBodyLog(tester.element(find.byType(MePage)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(SheetInput).first,
        matching: find.byType(EditableText),
      ),
      '5',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 30–250 kg 的体重，腰围为 20–200 cm'), findsOneWidget);
    expect(h.controller.bodyEntries, isEmpty);
  });
}
