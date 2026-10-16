import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/body.dart';

void main() {
  test('routes use neutral language and preserve safety limits', () {
    expect(
      [
        for (final s in ['cut', 'recomp', 'trim', 'refine', 'bulk', 'youth'])
          stageName(s),
      ],
      ['减脂路线', '重组路线', '微调路线', '精修路线', '增肌路线', '成长期'],
    );
    for (final sex in ['male', 'female']) {
      final target = buildTargets({
        ...profileDefaults,
        'sex': sex,
      }, goalOverride: 3);
      expect(target['goalBodyFat'], sex == 'male' ? 8 : 16);
      expect(
        target['kcal'] as num,
        greaterThanOrEqualTo(bmr({...profileDefaults, 'sex': sex})),
      );
    }
    final youth = buildTargets({...profileDefaults, 'age': 16});
    expect(
      '${youth['headline']} ${youth['warnings']}',
      isNot(matches('热量缺口|减脂')),
    );
  });
  test('source language avoids body labels', () {
    final banned = RegExp('偏高|微胖|偏瘦|肥胖|超重');
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      expect(
        banned.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });
}
