import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Extract extends RecursiveAstVisitor<void> {
  final values = <String>{};
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    // Model instructions are not interface messages.
    if (const {
      '_prompt',
      '_promptRules',
      '_promptBeforeOnly',
      '_promptCompare',
    }.contains(node.name.lexeme)) {
      return;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(node.value)) {
      try {
        final decoded = jsonDecode(node.value);
        void collect(Object? v) {
          if (v is String && RegExp(r'[\u4e00-\u9fff]').hasMatch(v)) {
            values.add(v);
          }
          if (v is Map) {
            for (final x in v.values) {
              collect(x);
            }
          }
          if (v is List) {
            for (final x in v) {
              collect(x);
            }
          }
        }

        if (decoded is Map || decoded is List) {
          collect(decoded);
          return;
        }
      } catch (_) {}
      if (node.value.length < 800 && !node.value.contains('只输出JSON')) {
        values.add(node.value);
      }
    }
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    var index = 0;
    final text = node.elements
        .map(
          (part) => part is InterpolationString ? part.value : '{p${index++}}',
        )
        .join();
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) values.add(text);
    super.visitStringInterpolation(node);
  }
}

void main() {
  final out = <String>{};
  for (final f
      in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'),
          )) {
    final visitor = Extract();
    parseString(content: f.readAsStringSync()).unit.accept(visitor);
    out.addAll(visitor.values);
  }
  final foods =
      jsonDecode(File('assets/foods.json').readAsStringSync()) as List;
  for (final f in foods) {
    for (final key in ['name', 'unit', 'category']) {
      out.add(f[key] as String);
    }
  }
  // Native errors surface through the same Dart presentation boundary.
  for (final root in ['ios/Runner/Native', 'android/app/src/main']) {
    for (final file in Directory(
      root,
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.swift') &&
          !file.path.endsWith('.java') &&
          !file.path.endsWith('.kt')) {
        continue;
      }
      for (final match in RegExp(
        r'"([^"\n]*[\u4e00-\u9fff][^"\n]*)"',
      ).allMatches(file.readAsStringSync())) {
        var value = match[1]!;
        var index = 0;
        value = value.replaceAllMapped(
          RegExp(r'\\\([^)]*\)'),
          (_) => '{p${index++}}',
        );
        if (!value.contains(r'\')) out.add(value);
      }
    }
  }
  final original = out.toList();
  out.addAll(original.map((s) => s.replaceAll('刺激', '练')));
  out.addAll(
    original.map(
      (s) => s
          .replaceAll('渐进升级', '可以加重量了')
          .replaceAll('刺激肌肉', '练到的肌肉')
          .replaceAll('刺激', '训练量')
          .replaceAll('不算失败', '按今天的状态练就好'),
    ),
  );
  out.removeWhere(
    (s) => s.startsWith('FakeNative.') || s.contains('Write human-readable'),
  );
  final values = out.toList()..sort();
  File('tool/l10n/source.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(values));
  stdout.writeln('${values.length} source messages');
}
