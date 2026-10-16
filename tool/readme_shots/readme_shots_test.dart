// 生成 README 用的界面截图：
//   LEANDAILY_TEST_FONT="/System/Library/Fonts/Hiragino Sans GB.ttc" TZ=Asia/Shanghai \
//     flutter test tool/readme_shots/readme_shots_test.dart
// 输出到 out/shots/readme-*.png，再由 tool/readme_shots/compose.mjs 排版成展示图。
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/harness.dart';
import '../../test/today_sheets_test.dart' show loadExerciseImages;

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

String _body() {
  final entries = <Map<String, dynamic>>[];
  var w = 76.2;
  for (var i = 0; i < 70; i += 2) {
    final d = DateTime(2026, 10, 15).subtract(Duration(days: 70 - i));
    w -= .06 + (i % 6 == 0 ? .08 : 0);
    entries.add({
      'date':
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'weightKg': double.parse(w.toStringAsFixed(1)),
    });
  }
  return jsonEncode({'v': 1, 'entries': entries});
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    testWidgets('readme today $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        size: const Size(393, 852),
        seed: (n) {
          n.docs['fw-profile-v1'] = jsonEncode(_profile());
          n.docs['fw-body-v1'] = _body();
        },
      );
      await tester.pumpAndSettle();
      await loadExerciseImages(tester);
      await h.shot(tester, 'readme-today-$scheme');
    });
  }
}
