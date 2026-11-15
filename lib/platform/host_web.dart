import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web 选图：临时造一个 file input 触发系统文件选择框。
Future<Uint8List?> pickImageBytes() {
  final completer = Completer<Uint8List?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/*';
  input.style.display = 'none';
  web.document.body?.appendChild(input);

  void finish(Uint8List? bytes) {
    input.remove();
    if (!completer.isCompleted) completer.complete(bytes);
  }

  input.onchange = ((web.Event event) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    file.arrayBuffer().toDart.then((buffer) {
      finish(buffer.toDart.asUint8List());
    }).catchError((Object _) {
      finish(null);
    });
  }).toJS;

  input.click();
  return completer.future;
}

/// Web 保存：Blob + 隐藏 <a download>，浏览器直接落到「下载」目录。
String downloadImage(Uint8List bytes, String filename) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return '已保存到下载目录：$filename';
}

/// 统一异步入口：Web 直接复用 a[download]。
Future<String> saveImage(Uint8List bytes, String filename) async =>
    downloadImage(bytes, filename);

String? readLocal(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeLocal(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {
    // 配额写满 / 隐私模式：静默失败，作品仍在内存里
  }
}

void removeLocal(String key) {
  try {
    web.window.localStorage.removeItem(key);
  } catch (_) {}
}

bool get isWebHost => true;

/// Web 端 localStorage 本身就是持久层，无需预加载。
Future<void> initLocalStore() async {}

/// Web 端不支持由应用发起退出（浏览器无此能力），空实现。
Future<void> exitApp() async {}
