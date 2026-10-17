import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/native.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    this.build,
    required this.url,
    required this.notes,
  });
  final String version, url, notes;
  final int? build;
  String get identity => '$version+${build ?? 0}';
}

enum UpdateStatus { unconfigured, idle, checking, available, upToDate, failed }

bool _https(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

UpdateInfo? parseUpdate(String body, {TargetPlatform? platform}) {
  final ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final github = j.containsKey('tag_name');
    final raw = j[github ? 'tag_name' : 'version'];
    final notes = j[github ? 'body' : 'notes'];
    if (raw is! String || notes is! String) return null;
    final version = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(version)) {
      return null;
    }
    Object? url = j[github ? 'html_url' : 'url'];
    if (!ios && github && j['assets'] is List) {
      for (final a in j['assets']) {
        if (a is Map && a['browser_download_url'] is String) {
          final candidate = a['browser_download_url'] as String;
          if (Uri.tryParse(candidate)?.path.toLowerCase().endsWith('.apk') ==
                  true &&
              _https(candidate)) {
            url = candidate;
            break;
          }
        }
      }
    }
    if (url is! String || !_https(url)) return null;
    if (ios) {
      final destination = Uri.parse(url);
      if (!const {
            'apps.apple.com',
            'testflight.apple.com',
          }.contains(destination.host) ||
          destination.path.toLowerCase().endsWith('.apk')) {
        return null;
      }
    }
    final build = j['build'];
    if (build != null && (build is! int || build < 0)) return null;
    return UpdateInfo(
      version: version,
      build: build as int?,
      url: url,
      notes: notes,
    );
  } on Object {
    return null;
  }
}

bool isNewer(String remote, String local, {int? remoteBuild, int? localBuild}) {
  final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+[0-9A-Za-z.-]+)?$');
  final r = pattern.firstMatch(remote), l = pattern.firstMatch(local);
  // 预发布版本不提示。
  if (r == null) return false;
  final base = l ?? RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(local);
  if (base == null) return false;
  for (var i = 1; i <= 3; i++) {
    final a = int.parse(r[i]!), b = int.parse(base[i]!);
    if (a != b) return a > b;
  }
  return l == null ||
      (remoteBuild != null && localBuild != null && remoteBuild > localBuild);
}

Future<UpdateInfo?> fetchUpdate(Native native, String url) async {
  if (!_https(url)) return null;
  final id = 'update-${DateTime.now().microsecondsSinceEpoch}';
  try {
    final response = await native
        .http(
          HttpCall(
            id: id,
            url: url,
            headers: const {'User-Agent': 'LeanDaily'},
            timeoutMs: 8000,
          ),
        )
        .timeout(const Duration(seconds: 8));
    return response.status >= 200 && response.status < 300
        ? parseUpdate(response.body)
        : null;
  } on TimeoutException {
    unawaited(native.cancelHttp(id).catchError((Object _) {}));
    return null;
  } on Object {
    return null;
  }
}
