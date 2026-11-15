import 'dart:typed_data';

/// 非 Web 平台占位实现：选图与保存需要系统相册/文件能力，
/// 当前版本的交付目标是 Web，移动端先退回内存态。
Future<Uint8List?> pickImageBytes() async => null;

String downloadImage(Uint8List bytes, String filename) =>
    '当前平台暂不支持直接保存，请用 Web 版导出';

final Map<String, String> _mem = <String, String>{};

String? readLocal(String key) => _mem[key];

void writeLocal(String key, String value) => _mem[key] = value;

void removeLocal(String key) => _mem.remove(key);

bool get isWebHost => false;
