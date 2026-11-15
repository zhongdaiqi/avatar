import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// 与小程序 utils/math.js 对齐的一组数值工具。
const double pi = math.pi;

double rad(double deg) => deg * math.pi / 180;

double clampd(double v, double a, double b) {
  if (v < a) return a;
  if (v > b) return b;
  return v;
}

double dist(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return math.sqrt(dx * dx + dy * dy);
}

double angleOf(Offset a, Offset b) {
  return math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
}

Offset centerOf(List<Offset> touches) {
  if (touches.isEmpty) return Offset.zero;
  if (touches.length == 1) return touches[0];
  return Offset(
    (touches[0].dx + touches[1].dx) / 2,
    (touches[0].dy + touches[1].dy) / 2,
  );
}

/// mulberry32：确定性随机，保证缩略图与成品渲染的纹样完全一致。
class Mulberry32 {
  int _a;
  Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = _mul(t ^ (_a >> 15), 1 | _a) & 0xFFFFFFFF;
    t = (t + (_mul(t ^ (t >> 7), 61 | t) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    t = t ^ (t >> 14);
    return (t & 0xFFFFFFFF) / 4294967296.0;
  }

  static int _mul(int a, int b) {
    // Math.imul 语义：32 位有符号乘法
    final ah = (a >> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    final r = (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
    return r >= 0x80000000 ? r - 0x100000000 : r;
  }
}

// ---------------------------------------------------------------------------
// 颜色
// ---------------------------------------------------------------------------

Color hexColor(String s, [Color fallback = const Color(0xFF000000)]) {
  var h = (s).replaceAll('#', '').trim();
  if (h.length == 3) {
    h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
  }
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String colorToHex(Color c) {
  String to(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${to(c.r)}${to(c.g)}${to(c.b)}'.toUpperCase();
}

double luma(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

Color mixColor(Color a, Color b, double t) => Color.from(
      alpha: a.a + (b.a - a.a) * t,
      red: a.r + (b.r - a.r) * t,
      green: a.g + (b.g - a.g) * t,
      blue: a.b + (b.b - a.b) * t,
    );

Color lighten(Color c, double t) => mixColor(c, const Color(0xFFFFFFFF), t);

Color darken(Color c, double t) => mixColor(c, const Color(0xFF000000), t);

Color fade(Color c, double a) => c.withValues(alpha: c.a * clampd(a, 0, 1));

Color readable(Color bg) => luma(bg) > 0.6
    ? const Color(0xFF1A1A1A)
    : const Color(0xFFFFFFFF);

// ---------------------------------------------------------------------------
// 画布包装：替代 CanvasRenderingContext2D 的 globalAlpha / 画笔语义
// ---------------------------------------------------------------------------

/// [Pc] = Paint Context。
///
/// 小程序的绘制代码到处在用 `ctx.globalAlpha = x` 这种"状态式"写法，
/// Flutter 的 Canvas 没有这个概念，所以这里做一层薄包装：每个 fill/stroke
/// 都把当前 [alpha] 乘进颜色里，调用方的写法可以和 JS 版保持一致。
class Pc {
  Pc(this.canvas, this.bounds) : _stack = <double>[];

  final Canvas canvas;
  final Rect bounds;
  final List<double> _stack;

  double alpha = 1;

  void save() {
    canvas.save();
    _stack.add(alpha);
  }

  void restore() {
    canvas.restore();
    if (_stack.isNotEmpty) alpha = _stack.removeLast();
  }

  void translate(double x, double y) => canvas.translate(x, y);
  void rotate(double r) => canvas.rotate(r);
  void scale(double sx, [double? sy]) => canvas.scale(sx, sy ?? sx);

  void clipPath(Path p) => canvas.clipPath(p);
  void clipRect(Rect r) => canvas.clipRect(r);

  /// saveLayer 版 alpha（渐变画笔 + 整体透明时需要）
  void pushAlphaLayer(double a) {
    canvas.saveLayer(
      bounds,
      Paint()..color = const Color(0xFF000000).withValues(alpha: a),
    );
    _stack.add(alpha);
    alpha = 1;
  }

  Color _c(Color c, [double k = 1]) => c.withValues(alpha: c.a * alpha * k);

  Paint _paint(
    Color? color, {
    Shader? shader,
    BlendMode blend = BlendMode.srcOver,
    bool stroke = false,
    double width = 0,
    StrokeCap cap = StrokeCap.butt,
    StrokeJoin join = StrokeJoin.miter,
    MaskFilter? mask,
    ColorFilter? colorFilter,
  }) {
    final p = Paint()..blendMode = blend;
    if (colorFilter != null) p.colorFilter = colorFilter;
    if (shader != null) {
      p.shader = shader;
    } else {
      p.color = _c(color ?? const Color(0xFF000000));
    }
    if (stroke) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = width <= 0 ? 1 : width
        ..strokeCap = cap
        ..strokeJoin = join;
    }
    if (mask != null) p.maskFilter = mask;
    return p;
  }

  void fillPath(
    Path p, {
    Color? color,
    Shader? shader,
    PathFillType? fillType,
    BlendMode blend = BlendMode.srcOver,
  }) {
    if (fillType != null) p.fillType = fillType;
    canvas.drawPath(p, _paint(color, shader: shader, blend: blend));
  }

  void fillRect(Rect r, {Color? color, Shader? shader, BlendMode blend = BlendMode.srcOver}) {
    canvas.drawRect(r, _paint(color, shader: shader, blend: blend));
  }

  void strokePath(
    Path p, {
    Color? color,
    double width = 1,
    Shader? shader,
    List<double>? dash,
    double dashOffset = 0,
    StrokeCap cap = StrokeCap.round,
    StrokeJoin join = StrokeJoin.round,
    Color? shadowColor,
    double shadowBlur = 0,
    ColorFilter? colorFilter,
  }) {
    final target = dash == null || dash.isEmpty
        ? p
        : dashPath(p, dash, dashOffset);
    final paint = _paint(
      color,
      shader: shader,
      stroke: true,
      width: width,
      cap: cap,
      join: join,
      colorFilter: colorFilter,
    );
    if (shadowBlur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur / 2);
    }
    canvas.drawPath(target, paint);
  }

  void circle(double x, double y, double r,
      {Color? color, Shader? shader, bool stroke = false, double width = 1}) {
    final p = Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    if (stroke) {
      strokePath(p, color: color, width: width, shader: shader);
    } else {
      fillPath(p, color: color, shader: shader);
    }
  }

  void drawImage(ui.Image img, Rect dst,
      {ColorFilter? colorFilter, bool fit = true}) {
    final src = Rect.fromLTWH(
        0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(
      img,
      src,
      dst,
      _paint(null, colorFilter: colorFilter),
    );
  }

  /// cover：等比铺满目标矩形，不拉伸
  void drawImageCover(ui.Image img, Rect dst) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    if (iw <= 0 || ih <= 0) return;
    final s = math.max(dst.width / iw, dst.height / ih);
    final w = iw * s;
    final h = ih * s;
    drawImage(
      img,
      Rect.fromLTWH(
        dst.left + (dst.width - w) / 2,
        dst.top + (dst.height - h) / 2,
        w,
        h,
      ),
    );
  }
}

/// 按 [pattern] 指定的虚线段长切分路径（等价于 ctx.setLineDash）。
Path dashPath(Path source, List<double> pattern, [double offset = 0]) {
  final out = Path();
  if (pattern.isEmpty) return source;
  double total = 0;
  for (final v in pattern) {
    if (v > 0) total += v;
  }
  if (total <= 0) return source;

  var phase = offset % total;
  if (phase < 0) phase += total;

  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    var idx = 0;
    // 找到起始相位落在哪个段
    var consumed = 0.0;
    while (consumed + pattern[idx % pattern.length] <= phase) {
      consumed += pattern[idx % pattern.length];
      idx++;
    }
    var remain = pattern[idx % pattern.length] - (phase - consumed);
    var draw = idx.isEven;

    while (d < metric.length) {
      final step = math.min(remain, metric.length - d);
      if (draw) {
        out.addPath(metric.extractPath(d, d + step), Offset.zero);
      }
      d += step;
      remain -= step;
      if (remain <= 0.0001) {
        idx++;
        remain = pattern[idx % pattern.length];
        draw = !draw;
      }
    }
  }
  return out;
}

/// 线性渐变（按角度取端点，等价 backdrops.js 的 gradient()）
Shader linearAngle(double L, List<(Color, double)> stops, double angle) {
  final a = rad(angle);
  final half = L / 2;
  final dx = math.cos(a) * half;
  final dy = math.sin(a) * half;
  return ui.Gradient.linear(
    Offset(half - dx, half - dy),
    Offset(half + dx, half + dy),
    stops.map((e) => e.$1).toList(),
    stops.map((e) => clampd(e.$2, 0, 1)).toList(),
  );
}

/// 双半径径向渐变：像素落在 [from] 处半径为 [r0]，扩散到 [to] 处为 [r1]。
Shader radialShader(
  Offset from,
  double r0,
  Offset to,
  double r1,
  List<(Color, double)> stops,
) {
  return ui.Gradient.radial(
    to,
    r1,
    stops.map((e) => e.$1).toList(),
    stops.map((e) => clampd(e.$2, 0, 1)).toList(),
    TileMode.clamp,
    null,
    from,
    r0,
  );
}
