import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';

import 'package:leandaily/domain/movements.dart';

void main() {
  test('MuscleMap 四视图覆盖全部肌群，所有路径均有效且位于 viewBox 内', () {
    final data = jsonDecode(
      File('assets/muscle_map.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(data['source'], {
      'repo': 'https://github.com/melihcolpan/MuscleMap',
      'commit': '5f576a5d3d697c3720abfada8e618d1cef08ea32',
      'license': 'MIT',
    });
    final ids = MUSCLES.map((muscle) => muscle['id']!).toSet();
    for (final sex in ['male', 'female']) {
      final views = data[sex] as Map<String, dynamic>;
      expect(views.keys.toSet(), {'front', 'back'});
      final covered = <String>{};
      for (final entry in views.entries) {
        final view = entry.value as Map<String, dynamic>;
        final box = (view['viewBox'] as List).cast<num>();
        expect(box, hasLength(4));
        expect(box[2], greaterThan(0));
        expect(box[3], greaterThan(0));
        final muscles = view['muscles'] as Map<String, dynamic>;
        covered.addAll(muscles.keys);
        expect(ids.containsAll(muscles.keys), isTrue);
        final inert = (view['inert'] as List).cast<String>();
        expect(inert, isNotEmpty);
        final other = view['other'] as Map<String, dynamic>;
        expect(other, isNotEmpty);
        expect(inert, [for (final paths in other.values) ...paths as List]);
        final collections = <String, List<dynamic>>{
          'inert': inert,
          for (final section in ['muscles', 'other', 'groups'])
            for (final group in (view[section] as Map<String, dynamic>).entries)
              '$section/${group.key}': group.value as List,
        };
        for (final group in collections.entries) {
          expect(group.value, isNotEmpty);
          for (var i = 0; i < group.value.length; i++) {
            final label = '$sex/${entry.key}/${group.key}/$i';
            final path = group.value[i] as String;
            expect(path.trim(), isNotEmpty, reason: label);
            final bounds = parseSvgPathData(path).getBounds();
            expect(bounds.isEmpty, isFalse, reason: label);
            // 容许上游曲线转换产生最多 1 个坐标单位的舍入误差。
            const tolerance = 1.0;
            expect(
              bounds.left,
              greaterThanOrEqualTo(box[0] - tolerance),
              reason: label,
            );
            expect(
              bounds.top,
              greaterThanOrEqualTo(box[1] - tolerance),
              reason: label,
            );
            expect(
              bounds.right,
              lessThanOrEqualTo(box[0] + box[2] + tolerance),
              reason: label,
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(box[1] + box[3] + tolerance),
              reason: label,
            );
          }
        }
      }
      // 两种性别均有全部 16 个肌群；不需要缺失例外。
      expect(covered, ids, reason: sex);
    }
  });
}
