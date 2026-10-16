import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/guide.dart';

void main() {
  final g =
      jsonDecode(File('test/golden/catalog.json').readAsStringSync()) as Map;
  test('all Web guide content, overrides, fallbacks and video URLs', () {
    expect(LIB, g['lib']);
    expect(NAME_MAP, g['nameMap']);
    expect(LIB_OPTIONS, g['options']);
    for (final c in g['guides']) {
      final expected = c['expected'] == null
          ? null
          : Map<String, dynamic>.from(c['expected'] as Map);
      if (expected != null) {
        expected['frames'] = [
          for (final path in expected['frames']) 'assets$path',
        ];
      }
      expect(
        guideFor(
          c['input'] == null
              ? null
              : Map<String, dynamic>.from(c['input'] as Map),
        ),
        expected,
      );
    }
    for (final c in g['videos']) {
      expect(videoSearchUrl(c['name'] as String), c['expected']);
    }
  });
  test('each offline frame is bundled and registered', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final key in LIB.keys) {
      expect(pubspec, contains('    - assets/exercises/$key/'));
      for (final i in [0, 1]) {
        final file = File(frameAsset(key, i));
        expect(file.existsSync(), isTrue, reason: '${file.path} 缺失');
        expect(file.lengthSync(), greaterThan(1000), reason: '${file.path} 太小');
      }
    }
  });
}
