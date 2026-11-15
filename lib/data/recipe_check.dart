import 'dart:convert';

import '../data/models.dart';

/// 测试辅助：走一次 JSON 序列化再解析，模拟"存到本地再读回来"
Recipe recipeRoundTrip(Recipe rec) {
  final map = jsonDecode(jsonEncode(rec.toJson()));
  return Recipe.fromJson((map as Map).cast<String, dynamic>());
}
