import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/px.dart';
import '../data/models.dart';

/// 逐像素调色在 Flutter 里用颜色矩阵完成（等价 filters.js 的 applyPixels）。
/// 顺序与 JS 版一致：hue → saturate → temperature → brightness/contrast。
List<double>? photoMatrix(FilterCfg f) {
  if (f.isNeutral) return null;

  final br = f.brightness;
  final ct = f.contrast;
  final sa = f.saturate;
  final hu = f.hue;
  final tp = f.temperature;

  // 色相旋转矩阵（3×3）
  var m = <List<double>>[
    [1, 0, 0],
    [0, 1, 0],
    [0, 0, 1],
  ];
  if (hu.abs() > 0.5) {
    final a = hu * math.pi / 180;
    final c = math.cos(a);
    final s = math.sin(a);
    m = [
      [0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928],
      [0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.14, 0.072 - c * 0.072 - s * 0.283],
      [0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072],
    ];
  }

  // 3×3 → 4×5
  List<double> to45(List<List<double>> m3, [List<double> offset = const [0, 0, 0]]) => [
        m3[0][0], m3[0][1], m3[0][2], 0, offset[0],
        m3[1][0], m3[1][1], m3[1][2], 0, offset[1],
        m3[2][0], m3[2][1], m3[2][2], 0, offset[2],
        0, 0, 0, 1, 0,
      ];

  var cur = to45(m);

  if ((sa - 1).abs() > 0.001) {
    final l = 0.299;
    final sat = <List<double>>[
      [l + (1 - l) * sa, 0.587 * (1 - sa), 0.114 * (1 - sa)],
      [0.299 * (1 - sa), 0.587 + (1 - 0.587) * sa, 0.114 * (1 - sa)],
      [0.299 * (1 - sa), 0.587 * (1 - sa), 0.114 + (1 - 0.114) * sa],
    ];
    cur = _mul45(to45(sat), cur);
  }

  if (tp.abs() > 0.5) {
    final warm = tp * 0.6;
    cur = _mul45(to45([
      [1, 0, 0],
      [0, 1, 0],
      [0, 0, 1],
    ], [warm, 0, -warm * 0.85]), cur);
  }

  if ((br - 1).abs() > 0.001 || (ct - 1).abs() > 0.001) {
    final s = br * ct;
    final off = 128 * (1 - ct);
    cur = _mul45(to45([
      [s, 0, 0],
      [0, s, 0],
      [0, 0, s],
    ], [off, off, off]), cur);
  }

  return cur;
}

/// a ∘ b（先把 b 作用在像素上，再作用 a）
List<double> _mul45(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      if (col == 4) v += a[row * 5 + 4];
      out[row * 5 + col] = v;
    }
  }
  return out;
}

class FilterStyle {
  const FilterStyle(this.id, this.name, this.blend, this.color, this.alpha);
  final String id;
  final String name;
  final BlendMode? blend;
  final Color color;
  final double alpha;
}

const List<FilterStyle> filterStyles = [
  FilterStyle('', '原图', null, Color(0xFFFFFFFF), 0),
  FilterStyle('film', '胶片', BlendMode.softLight, Color(0xFFF2C78E), 0.42),
  FilterStyle('mono', '黑白', BlendMode.saturation, Color(0xFF808080), 1),
  FilterStyle('warm', '暖阳', BlendMode.softLight, Color(0xFFFFB37B), 0.46),
  FilterStyle('cool', '冷调', BlendMode.softLight, Color(0xFF7BA9FF), 0.46),
  FilterStyle('morandi', '莫兰迪', BlendMode.softLight, Color(0xFFB9AE9E), 0.5),
  FilterStyle('cyber', '赛博', BlendMode.overlay, Color(0xFF7A3BFF), 0.34),
  FilterStyle('japan', '日系', BlendMode.softLight, Color(0xFFFFFFFF), 0.32),
  FilterStyle('vintage', '复古', BlendMode.multiply, Color(0xFFEBD9BC), 0.5),
  FilterStyle('cream', '奶油', BlendMode.softLight, Color(0xFFFFF1DC), 0.55),
];

FilterStyle? styleById(String id) {
  for (final s in filterStyles) {
    if (s.id == id) return s;
  }
  return null;
}

/// 在已经画好的照片上叠加风格色（调用方负责先 clip）
void applyStyle(Pc c, double L, String styleId, double opacity) {
  final st = styleById(styleId);
  if (st == null || st.blend == null) return;
  final rect = Rect.fromLTWH(0, 0, L, L);
  c.canvas.drawRect(
    rect,
    Paint()
      ..blendMode = st.blend!
      ..color = st.color.withValues(alpha: st.alpha * opacity),
  );
}

/// 照片画笔：颜色矩阵 + 可选透明度
Paint photoPaint(FilterCfg f, {double opacity = 1}) {
  final m = photoMatrix(f);
  final p = Paint();
  if (m != null) p.colorFilter = ui.ColorFilter.matrix(m);
  if (opacity < 1) p.color = Color.fromRGBO(0, 0, 0, opacity);
  return p;
}
