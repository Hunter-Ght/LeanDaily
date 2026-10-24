import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/catalog.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/domain/template_data.dart';

void main() {
  // 今日页、动作列表的封面取示范图第一帧：计划、模板、动作库里出现的每个动作都必须有。
  test('every exercise a user can meet has a cover photo', () {
    final names = <String>{
      ...catalog().keys,
      for (final days in templateDays.values)
        for (final d in days) ...[...d.home, ...d.gym],
    };
    final missing = <String>[];
    for (final name in names) {
      final g = guideFor({'name': name});
      final cover = g == null ? null : (g['frames'] as List).first as String;
      if (cover == null || !File(cover).existsSync()) missing.add(name);
    }
    expect(missing, isEmpty, reason: '没有封面图：$missing');
    expect(names.length, greaterThan(50));
  });
}
