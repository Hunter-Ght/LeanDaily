import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'grouped.dart';

/// 离线法律文本需要的少量 Markdown；不执行 HTML，也不加载外部资源。
class MarkdownLite extends StatelessWidget {
  const MarkdownLite(this.source, {super.key});
  final String source;

  List<InlineSpan> _inline(BuildContext context, String value) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    var end = 0;
    for (final m in pattern.allMatches(value)) {
      if (m.start > end) {
        spans.add(TextSpan(text: value.substring(end, m.start)));
      }
      spans.add(
        TextSpan(
          text: m[1] ?? m[2],
          style: TextStyle(
            fontWeight: m[1] != null ? FontWeight.w600 : null,
            fontFeatures: m[2] != null
                ? const [FontFeature.tabularFigures()]
                : null,
            backgroundColor: m[2] != null ? context.pal.fill2 : null,
          ),
        ),
      );
      end = m.end;
    }
    if (end < value.length) spans.add(TextSpan(text: value.substring(end)));
    return spans;
  }

  Widget _text(BuildContext context, String text, {int heading = 0}) =>
      Text.rich(
        TextSpan(children: _inline(context, text)),
        style: TextStyle(
          color: context.pal.text,
          fontSize: heading == 1
              ? 28
              : heading == 2
              ? 17
              : 15,
          fontWeight: heading > 0 ? FontWeight.w600 : FontWeight.w400,
          height: 1.6,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lines = source.replaceAll('\r', '').split('\n');
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('|')) {
        final rows = <Widget>[];
        var first = true;
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final cells = lines[i]
              .trim()
              .replaceFirst(RegExp(r'^\|'), '')
              .replaceFirst(RegExp(r'\|$'), '')
              .split('|')
              .map((s) => s.trim())
              .toList();
          if (!cells.every((s) => RegExp(r'^:?-+:?$').hasMatch(s))) {
            rows.add(
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _text(
                        context,
                        first ? '**${cells.first}**' : cells.first,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _text(
                        context,
                        first
                            ? '**${cells.skip(1).join(' · ')}**'
                            : cells.skip(1).join(' · '),
                      ),
                    ),
                  ],
                ),
              ),
            );
            first = false;
          }
          i++;
        }
        i--;
        children.add(GroupScope(child: GroupCard(children: rows)));
      } else if (line.startsWith('# ')) {
        children.add(
          Semantics(
            header: true,
            child: _text(context, line.substring(2), heading: 1),
          ),
        );
      } else if (line.startsWith('## ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              header: true,
              child: _text(context, line.substring(3), heading: 2),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(context, '•  '),
              Expanded(child: _text(context, line.substring(2))),
            ],
          ),
        );
      } else {
        final paragraph = StringBuffer(line);
        while (i + 1 < lines.length &&
            lines[i + 1].trim().isNotEmpty &&
            !RegExp(r'^(#|\||- )').hasMatch(lines[i + 1].trim())) {
          paragraph.write(' ${lines[++i].trim()}');
        }
        children.add(_text(context, paragraph.toString()));
      }
      children.add(const SizedBox(height: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
