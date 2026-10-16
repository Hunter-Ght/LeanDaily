import 'dart:convert';

import '../core/native.dart';
import '../domain/records.dart';
import 'state_doc.dart';

Future<Map<String, dynamic>> request(
  Native native,
  String url, {
  String method = 'GET',
  Map<String, String> headers = const {},
  Object? body,
  MultipartBody? multipart,
  String? id,
  int timeout = 120000,
}) async {
  if (!url.startsWith('https://')) throw const DomainError('接口必须使用 HTTPS');
  final r = await native.http(
    HttpCall(
      id: id ?? newId(),
      url: url,
      method: method,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
      multipart: multipart,
      timeoutMs: timeout,
    ),
  );
  Object? data;
  try {
    data = jsonDecode(r.body);
  } catch (_) {
    throw DomainError('接口未返回 JSON（HTTP ${r.status}）');
  }
  if (r.status < 200 || r.status >= 300) {
    final d = data is Map ? data : const {};
    final error = d['error'];
    throw DomainError(
      '接口 HTTP ${r.status}：${(error is Map ? error['message'] : null) ?? d['msg'] ?? '请求失败'}',
    );
  }
  return Map<String, dynamic>.from(data as Map);
}
