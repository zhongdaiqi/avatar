import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../data/models.dart';

class HitResult {
  const HitResult(this.type, this.index);
  final String type; // 'text' | 'sticker'
  final int index;
}

class _Box {
  const _Box(this.w, this.h);
  final double w;
  final double h;
}

/// 文字是居中对齐、上下按行高展开的，盒子直接从文本测量推出来
_Box _textBox(TextCfg t, double L) {
  final u = L / 540;
  final size = t.size * u;
  final lines = t.text.split('\n').take(2).toList();
  final weight = t.weight == 'bold'
      ? FontWeight.w600
      : (t.weight == 'light' ? FontWeight.w300 : FontWeight.w400);

  var w = 0.0;
  for (final line in lines) {
    final tp = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    w = math.max(w, tp.width);
  }

  final pad = t.arc.abs() > 0 ? size * 0.35 : 0.0;
  return _Box(w + pad, size * 1.24 * lines.length + pad);
}

/// [px],[py] 是触点相对画布的坐标（画布边长 [box]）
HitResult? hitTest(Recipe rec, double box, Offset point) {
  if (box <= 0) return null;
  final nx = point.dx / box;
  final ny = point.dy / box;
  if (nx < -0.1 || nx > 1.1 || ny < -0.1 || ny > 1.1) return null;

  // 文字画在最上层，优先命中；同层里后加的在上，所以倒序找
  for (var i = rec.texts.length - 1; i >= 0; i--) {
    final t = rec.texts[i];
    if (t.text.trim().isEmpty) continue;
    final m = _textBox(t, box);
    final hw = m.w / 2 / box + 0.015;
    final hh = m.h / 2 / box + 0.015;
    if ((nx - t.x).abs() <= hw && (ny - t.y).abs() <= hh) {
      return HitResult('text', i);
    }
  }

  // 贴纸按外接圆判定：旋转过的方块用圆近似，手感比精确包围盒更稳
  for (var i = rec.stickers.length - 1; i >= 0; i--) {
    final st = rec.stickers[i];
    final r = st.scale * 0.15 * 1.12;
    final dx = nx - st.x;
    final dy = ny - st.y;
    if (dx * dx + dy * dy <= r * r) return HitResult('sticker', i);
  }

  return null;
}
