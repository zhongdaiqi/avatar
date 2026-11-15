import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 非 Web 平台（Android / HarmonyOS）实现：
/// 选图与保存都走 MethodChannel `avatar.host`，由各端原生代码落地。
///
/// 鸿蒙侧：EntryAbility.ets（PhotoViewPicker 选图 / DocumentViewPicker 另存 /
/// dataPreferences 本地存储）
/// Android 侧：MainActivity.kt（ACTION_GET_CONTENT / MediaStore / SharedPreferences）
const MethodChannel _channel = MethodChannel('avatar.host');

Future<Uint8List?> pickImageBytes() async {
  try {
    final result = await _channel.invokeMethod<dynamic>('pickImage');
    if (result is Uint8List) return result;
    if (result is List) {
      return Uint8List.fromList(result.cast<int>());
    }
    return null;
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// 返回给用户看的结果文案。
Future<String> saveImage(Uint8List bytes, String filename) async {
  try {
    final msg = await _channel.invokeMethod<String>('saveImage', <String, dynamic>{
      'bytes': bytes,
      'name': filename,
    });
    return msg ?? '已保存';
  } on PlatformException catch (e) {
    return e.message ?? '保存失败，请重试';
  }
}

final Map<String, String> _mem = <String, String>{};

/// 启动时从原生持久层（鸿蒙 dataPreferences / Android SharedPreferences）
/// 把所有键值灌进内存，之后的 readLocal 走同步内存读写。
Future<void> initLocalStore() async {
  try {
    final data = await _channel.invokeMethod<dynamic>('loadLocal');
    if (data is Map) {
      data.forEach((k, v) {
        if (k != null && v != null) _mem[k.toString()] = v.toString();
      });
    }
  } catch (_) {
    // 原生层还没就绪 / 老版本包没有该通道：退化为纯内存态
  }
}

String? readLocal(String key) => _mem[key];

void writeLocal(String key, String value) {
  _mem[key] = value;
  _channel
      .invokeMethod<void>('writeLocal', <String, dynamic>{'key': key, 'value': value})
      .then((_) {}, onError: (Object _) {});
}

void removeLocal(String key) {
  _mem.remove(key);
  _channel
      .invokeMethod<void>('removeLocal', <String, dynamic>{'key': key})
      .then((_) {}, onError: (Object _) {});
}

/// 用户拒绝隐私协议后的退出入口。
Future<void> exitApp() async {
  try {
    await _channel.invokeMethod<void>('exitApp');
  } catch (_) {}
}

bool get isWebHost => false;
