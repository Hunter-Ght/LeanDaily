import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app.dart';
import 'package:leandaily/app/boot_screen.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/app/shell.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/theme/tokens.dart';
import 'package:leandaily/ui/onboarding/onboarding_flow.dart';

import 'support/harness.dart';

class DelayedLaunchNative extends FakeNative {
  DelayedLaunchNative() : super(now: DateTime(2026, 10, 16, 9)) {
    final legacy = jsonDecode(
      File('test/fixtures/legacy_store.json').readAsStringSync(),
    ) as Map;
    docs['fw-plan-v1'] = legacy['fw-plan-v1'] as String;
    docs['fw-onboarded-v1'] = '1';
  }
  final ready = Completer<String>();
  @override
  Future<String> deviceTz() => ready.future;
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('launcher preserves background and fades into app $dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final native = DelayedLaunchNative();
      final oldError = FlutterError.onError;
      final oldWidget = ErrorWidget.builder;
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final oldDispatcherError = dispatcher.onError;
      addTearDown(() {
        FlutterError.onError = oldError;
        ErrorWidget.builder = oldWidget;
        dispatcher.onError = oldDispatcherError;
      });
      await runLeanDaily(native);
      FlutterError.onError = oldError;
      ErrorWidget.builder = oldWidget;
      dispatcher.onError = oldDispatcherError;
      await tester.pump();
      expect(find.byType(BootScreen), findsOneWidget);
      final palette = dark ? AppPalette.dark : AppPalette.light;
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox).first).color,
        palette.bg,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      native.ready.complete('Asia/Shanghai');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester
            .widgetList<FadeTransition>(find.byType(FadeTransition))
            .any((w) => w.opacity.value > 0 && w.opacity.value < 1),
        isTrue,
      );
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox).first).color,
        palette.bg,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PageHost), findsOneWidget);
      expect(
        tester.widget<WidgetsApp>(find.byType(WidgetsApp)).color,
        palette.bg,
      );
      final app = tester.widget<LeanDailyApp>(find.byType(LeanDailyApp));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
      app.controller.dispose();
    });
  }

  for (final reduced in [false, true]) {
    testWidgets('onboarding route honors reduced motion $reduced', (
      tester,
    ) async {
      await Harness.pump(tester);
      final ctx = tester.element(find.byType(PageHost));
      final navigator = Navigator.of(ctx, rootNavigator: true);
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpAndSettle();
      }
      openOnboarding(tester.element(find.byType(PageHost)), upgrade: true);
      await tester.pump();
      final flow = tester.element(find.byType(OnboardingFlow));
      final route = ModalRoute.of(flow)!;
      expect(
        route.transitionDuration,
        Duration(milliseconds: reduced ? 0 : 280),
      );
      expect(
        route.reverseTransitionDuration,
        Duration(milliseconds: reduced ? 0 : 220),
      );
      await tester.pump(const Duration(milliseconds: 80));
      if (!reduced) expect(route.animation!.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
