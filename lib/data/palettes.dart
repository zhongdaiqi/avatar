import 'package:flutter/painting.dart';

import '../core/px.dart';

/// 配色方案：一组同时定义背景、边框、文字、点缀四色。
/// 换配色 = 整套联动换装。
class Palette {
  const Palette(this.id, this.name, this.bg1, this.bg2, this.frame, this.text,
      this.accent);

  final String id;
  final String name;
  final Color bg1;
  final Color bg2;
  final Color frame;
  final Color text;
  final Color accent;
}

const List<Palette> paletteList = [
  Palette('pure', '纯白', Color(0xFFFFFFFF), Color(0xFFF1F1F4), Color(0xFF1A1A1A),
      Color(0xFF1A1A1A), Color(0xFFFF6B6B)),
  Palette('ink', '墨黑', Color(0xFF1A1A1A), Color(0xFF303038), Color(0xFFFFFFFF),
      Color(0xFFFFFFFF), Color(0xFFFFFFFF)),
  Palette('morandi', '莫兰迪', Color(0xFFDCD2C6), Color(0xFFBCAE9D),
      Color(0xFFFFFFFF), Color(0xFF4A4038), Color(0xFF7E6B58)),
  Palette('cream', '奶油', Color(0xFFFFF7EC), Color(0xFFFFE2C2), Color(0xFFC98B4B),
      Color(0xFF8A5A28), Color(0xFFC98B4B)),
  Palette('coral', '珊瑚', Color(0xFFFFE6E4), Color(0xFFFFB3AE), Color(0xFFFFFFFF),
      Color(0xFFB03A38), Color(0xFFE24B4A)),
  Palette('rose', '玫瑰', Color(0xFFFCE6EE), Color(0xFFF0B4C9), Color(0xFFFFFFFF),
      Color(0xFFA63A66), Color(0xFFC2477A)),
  Palette('lilac', '紫藤', Color(0xFFF1EBFF), Color(0xFFD0BEF7), Color(0xFFFFFFFF),
      Color(0xFF5A3FA0), Color(0xFF6C48C7)),
  Palette('sky', '天空', Color(0xFFE7F2FF), Color(0xFFB2D5FF), Color(0xFFFFFFFF),
      Color(0xFF2F5FA8), Color(0xFF2F6FD0)),
  Palette('mint', '薄荷', Color(0xFFE4F7EF), Color(0xFFAEE5CD), Color(0xFFFFFFFF),
      Color(0xFF1D6B52), Color(0xFF1D7A5C)),
  Palette('forest', '森林', Color(0xFFDCEBD8), Color(0xFFA5C89C), Color(0xFF2C4A2A),
      Color(0xFF28462A), Color(0xFF2C4A2A)),
  Palette('sand', '沙丘', Color(0xFFF6ECDE), Color(0xFFDEC6A5), Color(0xFFFFFFFF),
      Color(0xFF8A6A44), Color(0xFF9A7A52)),
  Palette('dusk', '暮色', Color(0xFF2F2C3C), Color(0xFF4C4364), Color(0xFFE8DFF5),
      Color(0xFFFFFFFF), Color(0xFFC9B6E8)),
  Palette('cyber', '赛博', Color(0xFF191046), Color(0xFF3A1E7A), Color(0xFF00F0FF),
      Color(0xFFFFFFFF), Color(0xFF00F0FF)),
  Palette('neon', '霓虹', Color(0xFF12002B), Color(0xFF3A0050), Color(0xFFFF2D95),
      Color(0xFFFFFFFF), Color(0xFFFF2D95)),
  Palette('blood', '暗红', Color(0xFF2A0A0A), Color(0xFF5A1212), Color(0xFFE8B4B4),
      Color(0xFFFFFFFF), Color(0xFFE24B4A)),
  Palette('festive', '新年', Color(0xFF8B1A1A), Color(0xFFC0392B), Color(0xFFF5D76E),
      Color(0xFFFFFFFF), Color(0xFFF5D76E)),
  Palette('gold', '鎏金', Color(0xFF3A2E12), Color(0xFF6B5220), Color(0xFFF0C860),
      Color(0xFFFFF3D2), Color(0xFFF0C860)),
  Palette('snow', '圣诞', Color(0xFF0E3A2D), Color(0xFF1B5E45), Color(0xFFFFFFFF),
      Color(0xFFFFFFFF), Color(0xFFE24B4A)),
  Palette('moon', '中秋', Color(0xFF101B3A), Color(0xFF1E3160), Color(0xFFF5E6A8),
      Color(0xFFFFF8E1), Color(0xFFF5E6A8)),
  Palette('peach', '蜜桃', Color(0xFFFFEEE6), Color(0xFFFFC9AC), Color(0xFFFFFFFF),
      Color(0xFFB25A33), Color(0xFFE07B4B)),
  Palette('lavender', '薰衣草', Color(0xFFEEEAFA), Color(0xFFC7BCE8),
      Color(0xFFFFFFFF), Color(0xFF6A549E), Color(0xFF7A66B8)),
  Palette('ocean', '深海', Color(0xFF06283C), Color(0xFF0B4A66), Color(0xFF7FE3FF),
      Color(0xFFFFFFFF), Color(0xFF7FE3FF)),
  Palette('clay', '陶土', Color(0xFFE9D6C5), Color(0xFFC9A88C), Color(0xFFFFFFFF),
      Color(0xFF7A5436), Color(0xFF8C6242)),
  Palette('mono', '灰调', Color(0xFFEDEDEF), Color(0xFFC8C8CE), Color(0xFF4A4A52),
      Color(0xFF3A3A42), Color(0xFF4A4A52)),
];

final Map<String, Palette> _paletteMap = {
  for (final p in paletteList) p.id: p
};

Palette paletteById(String id) => _paletteMap[id] ?? paletteList.first;

/// 模板生成时用：底色明暗决定纹样用白还是压深一档的强调色
double backdropLuma(Palette pal) => (luma(pal.bg1) + luma(pal.bg2)) / 2;
