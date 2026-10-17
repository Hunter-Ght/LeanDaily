import 'dart:convert';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Presentation-only catalog. Canonical exercise names, JSON values, IDs and
/// user-written content are never rewritten in storage.
class AppMessages {
  AppMessages(this.locale);
  final Locale locale;
  static const locales = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];
  static const delegate = _MessagesDelegate();
  static final _catalogs = <String, Map<String, String>>{};
  static final _templates = <String, List<_Template>>{};
  static Future<void>? _loading;
  static Future<void> initialize() {
    if (_catalogs.length == 2) return SynchronousFuture<void>(null);
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    for (final code in ['en', 'zh_Hant']) {
      final bytes = await rootBundle.load('assets/l10n/$code.json');
      final raw = jsonDecode(
        utf8.decode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        ),
      ) as Map;
      final catalog = Map<String, String>.from(raw);
      _catalogs[code] = catalog;
      _templates[code] = [
        for (final e in catalog.entries)
          if (e.key.contains(RegExp(r'\{p\d+\}'))) _Template(e.key, e.value),
      ]..sort((a, b) => b.specificity.compareTo(a.specificity));
    }
  }

  static Locale resolve(String preference, List<Locale> device) {
    if (preference == 'en') return locales[0];
    if (preference == 'zh_Hans') return locales[1];
    if (preference == 'zh_Hant') return locales[2];
    for (final locale in device) {
      if (locale.languageCode == 'zh') {
        return locale.scriptCode == 'Hant' ||
                (locale.scriptCode != 'Hans' &&
                    const ['TW', 'HK', 'MO'].contains(locale.countryCode))
            ? locales[2]
            : locales[1];
      }
      if (locale.languageCode == 'en') return locales[0];
    }
    return locales[0];
  }

  String get code => locale.languageCode != 'zh'
      ? 'en'
      : locale.scriptCode == 'Hant' ||
            const ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? 'zh_Hant'
      : 'zh_Hans';
  static AppMessages of(BuildContext context) =>
      Localizations.of<AppMessages>(context, AppMessages) ??
      AppMessages(locales[1]);
  final _cache = <String, String>{};
  String text(String source) {
    if (_cache.length > 4096) _cache.clear();
    return _cache.putIfAbsent(source, () => _text(source, 0));
  }

  String _text(String source, int depth) {
    if (code == 'zh_Hans' ||
        depth > 4 ||
        !RegExp(r'[\u4e00-\u9fff]').hasMatch(source)) {
      return source;
    }
    final catalog = _catalogs[code];
    if (catalog == null) return source;
    if (catalog[source] case final exact?) return exact;
    for (final template in _templates[code] ?? <_Template>[]) {
      final match = template.pattern.firstMatch(source);
      if (match != null) {
        return template.target.replaceAllMapped(RegExp(r'\{p(\d+)\}'), (m) {
          final index = int.parse(m[1]!);
          return index < match.groupCount
              ? _text(match[index + 1] ?? '', depth + 1)
              : m[0]!;
        });
      }
    }
    // Compose existing display fragments (dates, units and labels). This is used
    // only at explicit presentation boundaries, never for persistence or logic.
    if (source.contains('\n')) {
      return source.split('\n').map((s) => _text(s, depth + 1)).join('\n');
    }
    final parts = source.split(' · ');
    if (parts.length > 1) {
      return parts.map((s) => _text(s, depth + 1)).join(' · ');
    }
    return source;
  }

  List<Map<String, dynamic>> foodSearch(
    List<Map<String, dynamic>> items,
    String query, {
    int limit = 30,
  }) {
    final q = query.trim().toLowerCase();
    return items
        .where(
          (f) => [
            f['name'],
            ...(f['aliases'] as List? ?? []),
            text('${f['name']}'),
          ].any((n) => '$n'.toLowerCase().contains(q)),
        )
        .take(limit)
        .toList();
  }
}

class _Template {
  _Template(this.source, this.target) {
    final tokens = RegExp(r'\{p\d+\}').allMatches(source).toList();
    var offset = 0;
    final out = StringBuffer('^');
    for (final token in tokens) {
      out.write(RegExp.escape(source.substring(offset, token.start)));
      // Adjacent fields such as weekday + workout name must not consume an
      // empty first field. The following field can still be an empty suffix.
      out.write(
        source.substring(token.end).startsWith(RegExp(r'\{p\d+\}'))
            ? '(.+?)'
            : '(.*?)',
      );
      offset = token.end;
    }
    out.write(RegExp.escape(source.substring(offset)));
    out.write(r'$');
    pattern = RegExp(out.toString(), dotAll: true);
  }
  final String source, target;
  int get specificity => source.replaceAll(RegExp(r'\{p\d+\}'), '').length;
  late final RegExp pattern;
}

class _MessagesDelegate extends LocalizationsDelegate<AppMessages> {
  const _MessagesDelegate();
  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';
  @override
  Future<AppMessages> load(Locale locale) {
    if (AppMessages._catalogs.length == 2) {
      return SynchronousFuture(AppMessages(locale));
    }
    return AppMessages.initialize().then((_) => AppMessages(locale));
  }

  @override
  bool shouldReload(_MessagesDelegate old) => false;
}
