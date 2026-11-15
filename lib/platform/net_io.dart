import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// 移动端（Android / 鸿蒙 / 桌面）的 HTTP 实现。
///
/// 超时压得很短：拉模板只是锦上添花，网络不好就该立刻回退内置模板，
/// 不能让首页卡在转圈上。
Future<Uint8List?> httpPostJson(String url, Map<String, dynamic> body) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close().timeout(const Duration(seconds: 10));
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final out = BytesBuilder(copy: false);
    await for (final chunk in resp) {
      out.add(chunk);
    }
    return out.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List?> httpGetBytes(String url) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close().timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final out = BytesBuilder(copy: false);
    await for (final chunk in resp) {
      out.add(chunk);
    }
    return out.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
