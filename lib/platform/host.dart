/// 平台能力：选图 / 保存图片 / 本地存储。
///
/// Web 走 package:web（文件选择框 + a[download] + localStorage），
/// 其它平台走 MethodChannel 原生实现（鸿蒙 PhotoViewPicker / Android Intent），保证同一份代码能编译到全平台。
export 'host_io.dart' if (dart.library.js_interop) 'host_web.dart';
