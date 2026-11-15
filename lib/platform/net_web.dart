import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// POST JSON，返回原始响应字节（调用方自己解 JSON）。
Future<Uint8List?> httpPostJson(String url, Map<String, dynamic> body) async {
  try {
    final headers = web.Headers();
    headers.set('Content-Type', 'application/json');
    final init = web.RequestInit(
      method: 'POST',
      headers: headers,
      body: jsonEncode(body).toJS,
    );
    final resp = await web.window.fetch(url.toJS, init).toDart;
    if (!resp.ok) return null;
    final buf = await resp.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}

/// GET 二进制（遮罩图 / 前景图）。
Future<Uint8List?> httpGetBytes(String url) async {
  try {
    final resp = await web.window.fetch(url.toJS).toDart;
    if (!resp.ok) return null;
    final buf = await resp.arrayBuffer().toDart;
    return buf.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
