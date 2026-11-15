/// 极简 HTTP 能力：只够拉模板列表 / 下载遮罩图。
///
/// 与 host.dart 同样的条件导出套路：
/// Web 走 package:web 的 fetch（受浏览器 CORS 约束，服务端已放 `*`），
/// 移动端走 dart:io 的 HttpClient，其它平台返回 null（静默回退内置模板）。
export 'net_stub.dart'
    if (dart.library.js_interop) 'net_web.dart'
    if (dart.library.io) 'net_io.dart';
