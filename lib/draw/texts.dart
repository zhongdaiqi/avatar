import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/px.dart';
import '../data/models.dart';

double _contrastOf(double a, double b) =>
    (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

TextStyle _style({
  required double size,
  FontWeight weight = FontWeight.w600,
  Color? color,
  Shader? shader,
  Color? strokeColor,
  double strokeWidth = 0,
  TextShadow? shadow,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    height: 1.16,
    color: strokeColor == null ? color : null,
    foreground: strokeColor != null
        ? (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor)
        : (shader != null ? (Paint()..shader = shader) : null),
    shadows: shadow != null && shadow.blur > 0
        ? [
            Shadow(
              offset: Offset(shadow.dx, shadow.dy),
              blurRadius: shadow.blur,
              color: shadow.color,
            )
          ]
        : null,
  );
}

double _measure(String txt, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: txt, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}

/// 画一条文字。halo 用粗描边垫底，strokeWidth 是用户选的描边。
void _paintLine(
  Pc c, {
  required String txt,
  required double x,
  required double y,
  required double size,
  required Color fill,
  required TextCfg t,
  required double strokeWidth,
  Color? haloColor,
  double haloWidth = 0,
  Shader? shader,
}) {
  final weight = t.weight == 'bold'
      ? FontWeight.w600
      : (t.weight == 'light' ? FontWeight.w300 : FontWeight.w400);

  // 等价 JS 版的 ctx.translate(cx, y)：三个图层（光晕/描边/填充）都画在
  // 以 (x, y) 为中心的位置
  c.save();
  c.translate(x, y);

  if (haloColor != null && haloWidth > 0) {
    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: _style(
            size: size,
            weight: weight,
            strokeColor: haloColor,
            strokeWidth: haloWidth),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  if (strokeWidth > 0) {
    final tp = TextPainter(
      text: TextSpan(
        text: txt,
        style: _style(
            size: size,
            weight: weight,
            strokeColor: t.stroke,
            strokeWidth: strokeWidth),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  final tp = TextPainter(
    text: TextSpan(
      text: txt,
      style: _style(
          size: size,
          weight: weight,
          color: fill,
          shader: t.gradient ? shader : null,
          shadow: t.shadow),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));

  c.restore();
}

/// [bgLuma] 是文字落点的底色亮度（<0 表示未知，跳过对比度判断）
void drawTextCfg(Pc c, double L, TextCfg t, {double bgLuma = -1}) {
  final txt = t.text;
  if (txt.trim().isEmpty) return;

  final u = L / 540;
  final size = t.size * u;
  final cx = t.x * L;
  final cy = t.y * L;

  final lines = txt.split('\n').take(2).toList();
  final lh = size * 1.24;
  final totalH = lh * (lines.length - 1);

  final weight = t.weight == 'bold'
      ? FontWeight.w600
      : (t.weight == 'light' ? FontWeight.w300 : FontWeight.w400);
  final measureStyle = _style(size: size, weight: weight, color: t.color);

  var widest = 0.0;
  for (final line in lines) {
    final w = _measure(line, measureStyle);
    if (w > widest) widest = w;
  }

  // 白字压在白底上，加光晕也救不回来 —— 这种直接换深色。
  var fill = t.color;
  var txtLuma = luma(t.color);
  if (bgLuma >= 0 && _contrastOf(txtLuma, bgLuma) < 2.4) {
    fill = bgLuma > 0.5 ? const Color(0xFF26252B) : const Color(0xFFFFFFFF);
    txtLuma = luma(fill);
  }

  Color? haloColor;
  var haloWidth = 0.0;
  if (bgLuma >= 0 && _contrastOf(txtLuma, bgLuma) < 2.6) {
    haloColor = txtLuma > bgLuma
        ? const Color(0x4D000000)
        : const Color(0x8CFFFFFF);
    haloWidth = size * 0.12;
  }

  Shader? shader;
  if (t.gradient) {
    shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lighten(fill, 0.45), fill],
    ).createShader(Rect.fromLTWH(-widest / 2, -size * 0.6, widest, size * 1.2));
  }

  final strokeWidth = t.strokeWidth * u;
  final shadow = TextShadow(
    dx: t.shadow.dx * u,
    dy: t.shadow.dy * u,
    blur: t.shadow.blur * u,
    color: t.shadow.color,
  );

  for (var i = 0; i < lines.length; i++) {
    final y = cy - totalH / 2 + i * lh;
    final line = lines[i];
    final arc = t.arc;

    if (arc.abs() < 3) {
      _paintLine(
        c,
        txt: line,
        x: cx,
        y: y,
        size: size,
        fill: fill,
        t: TextCfg(
          text: line,
          color: fill,
          stroke: t.stroke,
          strokeWidth: strokeWidth,
          weight: t.weight,
          gradient: t.gradient,
          shadow: shadow,
        ),
        strokeWidth: strokeWidth,
        haloColor: haloColor,
        haloWidth: haloWidth,
        shader: shader,
      );
      continue;
    }

    // 弧形文字：逐字按弧长定位并旋转
    final chars = line.runes.map(String.fromCharCode).toList();
    if (chars.isEmpty) continue;
    final sweep = (clampd(arc, -100, 100) / 100) * 1.5;
    var total = 0.0;
    final widths = <double>[];
    for (final ch in chars) {
      final w = _measure(ch, measureStyle);
      widths.add(w);
      total += w;
    }
    final r = total / math.max(0.02, sweep.abs());
    final up = arc > 0;

    var acc = -total / 2;
    for (var j = 0; j < chars.length; j++) {
      final w = widths[j];
      final mid = acc + w / 2;
      final theta = mid / r;
      double px;
      double py;
      double rot;
      if (up) {
        px = cx + r * math.sin(theta);
        py = y + r - r * math.cos(theta);
        rot = theta;
      } else {
        px = cx + r * math.sin(theta);
        py = y - r + r * math.cos(theta);
        rot = -theta;
      }
      c.save();
      c.translate(px, py);
      c.rotate(rot);
      if (haloColor != null && haloWidth > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: chars[j],
            style: _style(
                size: size,
                weight: weight,
                strokeColor: haloColor,
                strokeWidth: haloWidth),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      if (strokeWidth > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: chars[j],
            style: _style(
                size: size,
                weight: weight,
                strokeColor: t.stroke,
                strokeWidth: strokeWidth),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      final tp = TextPainter(
        text: TextSpan(
          text: chars[j],
          style: _style(
              size: size,
              weight: weight,
              color: fill,
              shader: t.gradient ? shader : null,
              shadow: shadow),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
      acc += w;
    }
  }
}
