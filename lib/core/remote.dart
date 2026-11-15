import 'dart:convert';
import 'dart:typed_data';

import '../data/presets.dart';
import '../platform/host.dart' show readLocal, writeLocal;
import '../platform/net.dart';

/// 在线模板：从头像模板服务（zhangtian 后台）下拉装修配方。
///
/// 红线（沿用小程序约定）：这条通道只**下载**模板参数与素材图，
/// 不上传任何用户内容（照片/作品/行为都不发）。
/// 断网、接口挂了、域名没配，全部静默回退到内置 60 套，功能不缺。
///
/// 缓存：localStorage 存最近一批，启动时先合并缓存（秒开），超过 TTL 再后台刷新。
///
/// REMOTE_BASE 可用 --dart-define 覆盖（本地联调代理用），默认走正式服务。
const String remoteBaseUrl = String.fromEnvironment(
  'REMOTE_BASE',
  defaultValue: 'https://avatar.zuime.com',
);

/// 后台「应用管理」里登记的 app_id，与模板表 app_id 一致
const String remoteAppId = 'com.zuime.avatar';

const String _cacheKey = 'remote_tpl_v1';
const int _ttlMs = 6 * 3600 * 1000;
const int _pageSize = 20;
const int _maxPages = 5;

class RemoteTemplates {
  /// 遮罩图内存缓存：同一张图在预览/导出里会被反复取用，别重复下载
  static final Map<String, Uint8List> _imgCache = <String, Uint8List>{};

  static bool _loading = false;

  /// 拉在线模板并合并进内置列表。**永不抛异常**，返回当前在线模板总数。
  static Future<int> load() async {
    final cache = _readCache();
    var count = 0;
    if (cache != null && cache.items.isNotEmpty) {
      count = mergeRemoteRows(_toRows(cache.items));
    }
    final fresh = cache != null &&
        DateTime.now().millisecondsSinceEpoch - cache.at < _ttlMs;
    if (fresh || _loading) return count;
    _loading = true;
    try {
      final rows = await _fetchAll();
      if (rows.isEmpty) return count;
      _writeCache(rows);
      count = mergeRemoteRows(_toRows(rows));
    } finally {
      _loading = false;
    }
    return count;
  }

  /// 下载一张远程素材图（遮罩图 / 前景图）。失败返回 null，调用方给出重试入口。
  ///
  /// http↔https 双候选：后台可能漏配协议，正式站只认 https，
  /// 本地/内网又常常只有 http，各试一次就都照顾到了。
  static Future<Uint8List?> fetchBytes(String url, {bool retry = false}) async {
    final u = cleanUrl(url);
    if (u.isEmpty) return null;
    if (retry) _imgCache.remove(u);
    final hit = _imgCache[u];
    if (hit != null) return hit;
    for (final candidate in _candidates(u)) {
      final bytes = await httpGetBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) {
        _imgCache[u] = bytes;
        return bytes;
      }
    }
    return null;
  }

  static void clearImageCache() => _imgCache.clear();

  static List<String> _candidates(String url) {
    if (url.startsWith('http://')) {
      return [url.replaceFirst('http://', 'https://'), url];
    }
    if (url.startsWith('https://')) {
      return [url, url.replaceFirst('https://', 'http://')];
    }
    return [url];
  }

  /// Java 侧空值有时会被序列化成字符串 "None"/"null"，不能当 URL 用
  static String cleanUrl(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty ||
        s == 'None' ||
        s == 'null' ||
        s == 'undefined' ||
        s.toLowerCase() == 'none') {
      return '';
    }
    return s;
  }

  static List<Map<String, dynamic>> _toRows(List<Map<String, dynamic>> items) {
    return items.map((it) {
      final id = (it['avatarTemplateId'] ?? '').toString();
      final category = (it['category'] ?? '').toString();
      return <String, dynamic>{
        'id': id.isEmpty ? '' : 'r$id',
        'name': it['name'] ?? '',
        'cat': category.isEmpty ? 'online' : category,
        'recipe': it['recipe'],
        'templateType': it['templateType'] ?? 'recipe',
        'maskUrl': cleanUrl(it['maskUrl']),
        'overlayUrl': cleanUrl(it['overlayUrl']),
        'coverUrl': cleanUrl(it['coverUrl']),
      };
    }).where((r) => (r['id'] as String).isNotEmpty).toList();
  }

  static Future<Map<String, dynamic>?> _fetchPage(int page) async {
    final bytes = await httpPostJson(
      '$remoteBaseUrl/api/public/avatar/template/list',
      <String, dynamic>{'appId': remoteAppId, 'page': page, 'size': _pageSize},
    );
    if (bytes == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      final body = decoded.cast<String, dynamic>();
      if (body['success'] != true) return null;
      final data = (body['data'] as Map?)?.cast<String, dynamic>();
      return data ?? <String, dynamic>{'list': <dynamic>[], 'total': 0};
    } catch (_) {
      return null;
    }
  }

  /// 翻页拉全量。首页无条件多翻一页确认（total 可能不可靠），
  /// 之后按 total 与页数上限收口。
  static Future<List<Map<String, dynamic>>> _fetchAll() async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= _maxPages; page++) {
      final data = await _fetchPage(page);
      if (data == null) break;
      final list = ((data['list'] as List?) ?? <dynamic>[])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      all.addAll(list);
      if (list.isEmpty) break;
      final total = (data['total'] as num?)?.toInt() ?? all.length;
      if (page == 1) continue;
      if (all.length >= total) break;
    }
    return all;
  }

  static _Cache? _readCache() {
    final raw = readLocal(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final at = (j['at'] as num?)?.toInt() ?? 0;
      final items = ((j['items'] as List?) ?? <dynamic>[])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (at == 0 || items.isEmpty) return null;
      return _Cache(at, items);
    } catch (_) {
      return null;
    }
  }

  static void _writeCache(List<Map<String, dynamic>> items) {
    try {
      writeLocal(
        _cacheKey,
        jsonEncode({
          'at': DateTime.now().millisecondsSinceEpoch,
          'items': items,
        }),
      );
    } catch (_) {
      // 配额写满：这次不缓存，下次重新拉，不影响本次展示
    }
  }
}

class _Cache {
  _Cache(this.at, this.items);
  final int at;
  final List<Map<String, dynamic>> items;
}
