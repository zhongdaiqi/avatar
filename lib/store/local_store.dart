import 'dart:convert';
import 'dart:typed_data';

import '../data/models.dart';
import '../platform/host.dart';

const String _kWorks = 'avatar_works';
const String _kDraft = 'avatar_draft';
const String _kFlags = 'avatar_flags';

const int maxWorks = 30;
const int _draftTtlMs = 7 * 24 * 3600 * 1000;

String dataUrl(Uint8List bytes, [String mime = 'image/png']) =>
    'data:$mime;base64,${base64Encode(bytes)}';

Uint8List? decodeDataUrl(String src) {
  final idx = src.indexOf('base64,');
  if (idx < 0) return null;
  try {
    return base64Decode(src.substring(idx + 7));
  } catch (_) {
    return null;
  }
}

class Work {
  Work({
    required this.id,
    required this.name,
    required this.thumb,
    required this.recipe,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 缩略图（data URL）。存 data URL 而不是文件路径，Web/移动端都能直接显示。
  final String thumb;
  final Recipe recipe;
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'thumb': thumb,
        'recipe': recipe.toJson(),
        'createdAt': createdAt,
      };

  static Work fromJson(Map<String, dynamic> j) => Work(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '我的头像').toString(),
        thumb: (j['thumb'] ?? '').toString(),
        recipe: Recipe.fromJson(
            ((j['recipe'] as Map?) ?? {}).cast<String, dynamic>()),
        createdAt: (j['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );

  String get timeLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(createdAt);
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '${d.month}月${d.day}日 ${pad(d.hour)}:${pad(d.minute)}';
  }
}

class LocalStore {
  static List<Work> getWorks() {
    final raw = readLocal(_kWorks);
    if (raw == null || raw.isEmpty) return <Work>[];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Work.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return <Work>[];
  }

  static void _writeWorks(List<Work> list) {
    writeLocal(_kWorks, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  /// 返回被挤掉的那条（超出 30 个上限时），调用方据此提示用户
  static Work? saveWork(Work work) {
    final list = getWorks();
    final idx = list.indexWhere((w) => w.id == work.id);
    if (idx >= 0) {
      list[idx] = work;
    } else {
      list.insert(0, work);
    }
    Work? evicted;
    while (list.length > maxWorks) {
      evicted ??= list.last;
      list.removeLast();
    }
    try {
      _writeWorks(list);
    } catch (_) {
      // 配额写满：退化成"只存缩略图丢失的照片"，至少记录还在内存
    }
    return evicted;
  }

  static void removeWork(String id) {
    final list = getWorks()..removeWhere((w) => w.id == id);
    _writeWorks(list);
  }

  static void clearWorks() => removeLocal(_kWorks);

  static Work? getWork(String id) {
    for (final w in getWorks()) {
      if (w.id == id) return w;
    }
    return null;
  }

  static String uid() =>
      'w${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${(DateTime.now().microsecond % 46656).toRadixString(36)}';

  // ---------------- 草稿 ----------------

  static void setDraft(Recipe recipe, {String workId = ''}) {
    writeLocal(
      _kDraft,
      jsonEncode({
        'recipe': recipe.toJson(),
        'at': DateTime.now().millisecondsSinceEpoch,
        'workId': workId,
      }),
    );
  }

  static DraftRecord? getLiveDraft() {
    final raw = readLocal(_kDraft);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final map = j.cast<String, dynamic>();
      final at = (map['at'] as num?)?.toInt() ?? 0;
      if (at == 0 || map['recipe'] is! Map) return null;
      if (DateTime.now().millisecondsSinceEpoch - at > _draftTtlMs) {
        clearDraft();
        return null;
      }
      return DraftRecord(
        recipe: Recipe.fromJson((map['recipe'] as Map).cast<String, dynamic>()),
        at: at,
        workId: (map['workId'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static void clearDraft() => removeLocal(_kDraft);

  // ---------------- 提示标记 ----------------

  static bool flag(String k) {
    final raw = readLocal(_kFlags);
    if (raw == null || raw.isEmpty) return false;
    try {
      final m = jsonDecode(raw);
      if (m is Map) return m[k] == true;
    } catch (_) {}
    return false;
  }

  static void setFlag(String k, bool v) {
    Map<String, dynamic> m = <String, dynamic>{};
    final raw = readLocal(_kFlags);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) m = decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    m[k] = v;
    writeLocal(_kFlags, jsonEncode(m));
  }
}

class DraftRecord {
  DraftRecord({required this.recipe, required this.at, required this.workId});
  final Recipe recipe;
  final int at;
  final String workId;

  String get agoLabel {
    final d = DateTime.now().millisecondsSinceEpoch - at;
    if (d < 60 * 1000) return '刚刚';
    if (d < 3600 * 1000) return '${(d / 60000).floor()} 分钟前';
    if (d < 24 * 3600 * 1000) return '${(d / 3600000).floor()} 小时前';
    return '${(d / 86400000).floor()} 天前';
  }
}
