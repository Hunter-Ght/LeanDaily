import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/kit/app_icon.dart';
import 'package:leandaily/ui/kit/sheet.dart';
import 'package:leandaily/ui/sheets/goals_sheet.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'support/fonts.dart';
class SettingsHarness {
  SettingsHarness(this.native, this.controller, this.shotKey, this.homeKey);
  final FakeNative native;
  final AppController controller;
  final GlobalKey shotKey, homeKey;
  static Future<void> setUpAll() async {
    TestWidgetsFlutterBinding.ensureInitialized(); await loadTestFonts(); await AppIcon.load();
  }
  static Future<SettingsHarness> pump(WidgetTester t, {bool dark = false, bool empty = false, Size size = const Size(393, 850)}) async {
    t.view.devicePixelRatio = 2; t.view.physicalSize = size * 2;
    addTearDown(() { t.view.resetPhysicalSize(); t.view.resetDevicePixelRatio(); });
    final native = FakeNative(now: DateTime.parse('2026-10-16T09:00:00'));
    final legacyDocs = (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map).cast<String, String>();
    native.docs['fw-plan-v1'] = legacyDocs['fw-plan-v1']!;
    native.docs['fw-onboarded-v1'] = '1';
    if (!empty) native.docs['android-state'] = jsonEncode(jsonDecode(File('test/fixtures/full_state.json').readAsStringSync())['state']);
    final app = AppController(native: native, clock: () => DateTime.parse('2026-10-16T09:00:00'));
    await app.boot();
    final shot = GlobalKey(), home = GlobalKey();
    final p = dark ? AppPalette.dark : AppPalette.light;
    await t.pumpWidget(RepaintBoundary(key: shot, child: WidgetsApp(color: p.bg, debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (c, a, b) => builder(c)),
      builder: (c, navigator) => PaletteScope(palette: p, child: AppScope(controller: app, child: DefaultTextStyle(style: AppText.body(p).copyWith(fontFamily: testFontFamily), child: navigator!))),
      home: ColoredBox(key: home, color: p.bg),
    )));
    addTearDown(() async { await t.pumpWidget(const SizedBox()); app.dispose(); });
    await t.pumpAndSettle();
    return SettingsHarness(native, app, shot, home);
  }
  void open(Widget sheet) { showAppSheet<void>(homeKey.currentContext!, (_) => sheet); }
  Future<void> shot(WidgetTester t, String name) async {
    final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    debugDisableShadows = false;
    boundary.markNeedsPaint();
    await t.pump();
    await t.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final f = File('out/shots/$name.png'); await f.parent.create(recursive: true); await f.writeAsBytes(bytes!.buffer.asUint8List()); picture.dispose();
    });
    debugDisableShadows = true;
  }
}


Future<void> settle(WidgetTester t) async { await t.pumpAndSettle(); await t.pumpAndSettle(); }
void main() {
  setUpAll(SettingsHarness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('goals ${dark ? "dark" : "light"}', (t) async {
      final h = await SettingsHarness.pump(t, dark: dark);
      h.open(const GoalsSheet());
      await settle(t);
      await h.shot(t, 'sheet-goals-${dark ? "dark" : "light"}');
      debugDisableShadows = true;
      final input = find.descendant(of: find.byWidgetPredicate((w) => w is FormInput && w.label == '每天正式组'), matching: find.byType(EditableText));
      await t.enterText(input, '18');
      await t.tap(find.text('2 分钟')); await settle(t);
      await t.tap(find.text('保存')); await settle(t);
      expect(jsonDecode(h.native.docs['fw-goals-v1']!)['sets'], 18);
      expect(jsonDecode(h.native.docs['fw-rest-v1']!)['sec'], 120);
      h.open(const GoalsSheet()); await settle(t);
      expect(find.text('18'), findsOneWidget);
    });
  }
  testWidgets('dirty cancellation and disabling rest', (t) async {
    final h = await SettingsHarness.pump(t);
    debugDisableShadows = true;
    h.open(const GoalsSheet()); await settle(t);
    await t.tap(find.byType(FormSwitch)); await settle(t);
    await t.tap(find.text('取消')); await settle(t);
    expect(find.text('已填的内容不会保存。'), findsOneWidget);
    await t.tap(find.text('取消').last); await settle(t);
    await t.tap(find.text('保存')); await settle(t);
    expect(h.controller.restEnabled, false);
    expect(h.controller.rest.active, false);
  });
}
