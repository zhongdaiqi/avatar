import 'dart:typed_data';

/// 不支持的平台：一律当成"网络不可用"，调用方回退到内置 60 套模板。
Future<Uint8List?> httpPostJson(String url, Map<String, dynamic> body) async =>
    null;

Future<Uint8List?> httpGetBytes(String url) async => null;
