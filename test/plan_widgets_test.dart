import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/templates.dart';
import 'package:leandaily/domain/plan_insight.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/theme/theme.dart';
import 'package:leandaily/theme/tokens.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await MiniBody.load();
  });
  for (final width in [360.0, 393.0]) {
    for (final size in PlanCardSize.values) {
      testWidgets('$size at $width scaled', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final insight = planInsight(buildPlan('bochi-ppl-3'));
        await t.pumpWidget(
          PaletteScope(
            palette: AppPalette.light,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: Center(
                  child: SizedBox(
                    width: size == PlanCardSize.small ? 300 : width - 32,
                    child: PlanCard(
                      name: '薄肌三练 · 推拉腿',
                      tagline: '推、拉、腿轮着练，最经典的增肌节奏',
                      insight: insight,
                      size: size,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(CustomPaint), findsNWidgets(2));
        expect(
          find.bySemanticsLabel('薄肌三练 · 推拉腿，每周 3 天，周一推 周三拉 周五腿'),
          findsOneWidget,
        );
      });
    }
  }
}
