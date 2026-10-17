import 'dart:convert';

import '../core/native.dart';
import '../core/sha256.dart';
import '../domain/records.dart';

/// Consent binds to the exact endpoint + protocol. It is never exported in a
/// backup. No network, photo or secret access is required to inspect consent.
class AiConsent {
  AiConsent(this.native);
  final Native native;
  static const storageKey = 'leandaily-ai-consent-v1';
  static const revision = 1;
  static String destination(Map<String, dynamic> settings) {
    final uri = Uri.tryParse('${settings['baseUrl'] ?? ''}');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const DomainError('请填写不含账号、查询参数或片段的 HTTPS 接口地址');
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static String fingerprint(Map<String, dynamic> settings) => sha256(
    utf8.encode(
      '$revision|${destination(settings)}|${settings['protocol'] ?? 'chat'}',
    ),
  );
  Future<bool> granted(Map<String, dynamic> settings) async {
    final raw = (await native.all())[storageKey];
    return raw == fingerprint(settings);
  }

  Future<void> grant(Map<String, dynamic> settings) =>
      native.put(storageKey, fingerprint(settings));
  Future<void> revoke() => native.put(storageKey, '');
}
