import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/px.dart';

class PatternDef {
  const PatternDef(this.id, this.name, this.seed);
  final String id;
  final String name;
  final int seed;
}

const List<PatternDef> patternDefs = [
  PatternDef('sparkle', '星光', 11),
  PatternDef('snow', '落雪', 23),
  PatternDef('dots', '网点', 7),
  PatternDef('grain', '颗粒', 41),
  PatternDef('sweep', '扫光', 3),
  PatternDef('rain', '细雨', 17),
  PatternDef('bubbles', '气泡', 29),
  PatternDef('petals', '花瓣', 53),
  PatternDef('hearts', '飘心', 61),
  PatternDef('bokeh', '光斑', 71),
  PatternDef('grid', '网格', 5),
  PatternDef('wave', '水波', 13),
];

const List<PatternDef> patternList = [
  PatternDef('', '无', 0),
  ...patternDefs,
];

PatternDef? patternById(String id) {
  for (final d in patternDefs) {
    if (d.id == id) return d;
  }
  return null;
}

/// 纹样统一用「径向渐变的画笔」来收边，而不是在中心挖一个洞：
/// 中心几乎透明 -> 边缘满色，纹样自然变成"外圈装饰"，不会糊在人脸上。
Shader _fadeShader(
  double L,
  Color color,
  double alpha,
  double R, {
  double fadeFrom = 0.26,
}) {
  final from = math.min(0.82, fadeFrom);
  final mid = math.min(0.96, from + (1 - from) * 0.5);
  final center = Offset(L / 2, L / 2);
  return radialShader(
    center,
    R * 0.26,
    center,
    R * 0.99,
    [
      (fade(color, alpha * 0.02), 0),
      (fade(color, alpha * 0.10), from),
      (fade(color, alpha * 0.55), mid),
      (fade(color, alpha), 1),
    ],
  );
}

/// 单个元素用：给出某点的浓度系数，用于和随机透明度相乘
double _fadeAt(double L, double R, double x, double y) {
  final dx = x - L / 2;
  final dy = y - L / 2;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d >= R) return 1;
  final inner = R * 0.3;
  if (d <= inner) return 0.05;
  final t = (d - inner) / (R - inner);
  return 0.05 + t * 0.95;
}

void _star4(Pc c, double x, double y, double rr, Shader shader) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + (i * math.pi) / 4;
    final rd = i % 2 == 1 ? rr * 0.22 : rr;
    final px = x + math.cos(a) * rd;
    final py = y + math.sin(a) * rd;
    if (i == 0) {
      p.moveTo(px, py);
    } else {
      p.lineTo(px, py);
    }
  }
  p.close();
  c.fillPath(p, shader: shader);
}

void drawPattern(
  Pc c,
  double L, {
  required String id,
  required Color color,
  required double density,
  required double alpha,
  required double r,
}) {
  final def = patternById(id);
  if (def == null) return;

  final R = r > 0 ? r : L * 0.5;
  final fillShader = _fadeShader(L, color, alpha, R);
  final strokeShader = _fadeShader(L, color, alpha, R);
  final rand = Mulberry32(def.seed);
  final full = Rect.fromLTWH(0, 0, L, L);

  c.save();

  switch (def.id) {
    case 'sparkle':
      {
        final n = (40 + density * 80).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final s = (0.006 + rand.next() * 0.018) * L;
          c.alpha = 0.45 + rand.next() * 0.55;
          _star4(c, x, y, s, fillShader);
        }
        break;
      }

    case 'snow':
      {
        final n = (40 + density * 110).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final rr = (0.003 + rand.next() * 0.011) * L;
          c.alpha = 0.3 + rand.next() * 0.7;
          c.circle(x, y, rr, shader: fillShader);
        }
        break;
      }

    case 'dots':
      {
        final step = L / (11 + (density * 8).round());
        final rr = step * 0.13;
        final shader = _fadeShader(L, color, alpha, R, fadeFrom: 0.58);
        final path = Path();
        for (var y = step / 2; y < L; y += step) {
          for (var x = step / 2; x < L; x += step) {
            path.addOval(Rect.fromCircle(center: Offset(x, y), radius: rr));
          }
        }
        c.fillPath(path, shader: shader);
        break;
      }

    case 'grain':
      {
        final n = (600 + density * 1400).round();
        final s = math.max(1.0, L / 540);
        final shader = _fadeShader(L, color, alpha, R);
        final path = Path();
        for (var i = 0; i < n; i++) {
          path.addRect(
              Rect.fromLTWH(rand.next() * L, rand.next() * L, s, s));
        }
        c.save();
        c.alpha = 0.7;
        c.fillPath(path, shader: shader);
        c.restore();
        break;
      }

    case 'sweep':
      {
        final shader = ui.Gradient.linear(
          Offset.zero,
          Offset(L, L),
          [
            fade(color, 0),
            fade(color, alpha * 0.12),
            fade(color, alpha * 0.55),
            fade(color, alpha * 0.12),
            fade(color, 0),
          ],
          const [0, 0.42, 0.5, 0.58, 1],
        );
        c.fillRect(full, shader: shader);
        break;
      }

    case 'rain':
      {
        final n = (30 + density * 70).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L * 1.2 - L * 0.1;
          final y = rand.next() * L;
          final len = (0.02 + rand.next() * 0.06) * L;
          c.alpha = 0.45 + rand.next() * 0.55;
          final seg = Path()
            ..moveTo(x, y)
            ..lineTo(x - len * 0.45, y + len);
          c.strokePath(seg,
              shader: strokeShader,
              width: math.max(1, L * 0.0022),
              cap: StrokeCap.round);
        }
        break;
      }

    case 'bubbles':
      {
        final n = (14 + density * 30).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final rr = (0.012 + rand.next() * 0.05) * L;
          c.alpha = 0.35 + rand.next() * 0.5;
          c.circle(x, y, rr,
              shader: strokeShader,
              stroke: true,
              width: math.max(1, L * 0.0022));
        }
        break;
      }

    case 'petals':
      {
        final n = (14 + density * 34).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final rr = (0.008 + rand.next() * 0.022) * L;
          final k = _fadeAt(L, R, x, y);
          c.save();
          c.alpha = alpha * (0.4 + rand.next() * 0.6) * k;
          c.translate(x, y);
          c.rotate(rand.next() * math.pi * 2);
          c.fillPath(
            Path()
              ..addOval(Rect.fromCenter(
                  center: Offset.zero, width: rr * 2, height: rr * 0.52 * 2)),
            color: color,
          );
          c.restore();
        }
        break;
      }

    case 'hearts':
      {
        final n = (10 + density * 22).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final rr = (0.01 + rand.next() * 0.026) * L;
          final k = _fadeAt(L, R, x, y);
          c.save();
          c.alpha = alpha * (0.45 + rand.next() * 0.55) * k;
          c.translate(x, y);
          c.rotate((rand.next() - 0.5) * 0.9);
          final hk = rr / 16;
          final path = Path();
          for (var j = 0; j <= 40; j++) {
            final t = (j / 40) * math.pi * 2;
            final hx = 16 * math.pow(math.sin(t), 3);
            final hy = 13 * math.cos(t) -
                5 * math.cos(2 * t) -
                2 * math.cos(3 * t) -
                math.cos(4 * t);
            final px = hx * hk;
            final py = -(hy + 2.5) * hk;
            if (j == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          c.fillPath(path, color: color);
          c.restore();
        }
        break;
      }

    case 'bokeh':
      {
        final n = (8 + density * 16).round();
        for (var i = 0; i < n; i++) {
          final x = rand.next() * L;
          final y = rand.next() * L;
          final rr = (0.06 + rand.next() * 0.14) * L;
          final k = _fadeAt(L, R, x, y);
          if (k < 0.05) continue;
          final shader = radialShader(
            Offset(x, y),
            0,
            Offset(x, y),
            rr,
            [
              (fade(color, alpha * 0.5 * k), 0),
              (fade(color, 0), 1),
            ],
          );
          c.circle(x, y, rr, shader: shader);
        }
        break;
      }

    case 'grid':
      {
        final step = L / (6 + (density * 8).round());
        final shader = _fadeShader(L, color, alpha, R, fadeFrom: 0.46);
        final path = Path();
        for (var x = step; x < L; x += step) {
          path
            ..moveTo(x, 0)
            ..lineTo(x, L);
        }
        for (var y = step; y < L; y += step) {
          path
            ..moveTo(0, y)
            ..lineTo(L, y);
        }
        c.strokePath(path, shader: shader, width: math.max(1, L * 0.0018));
        break;
      }

    case 'wave':
      {
        final rows = 7 + (density * 6).round();
        for (var row = 0; row < rows; row++) {
          final baseY = (L / rows) * (row + 0.5);
          final path = Path();
          for (var i = 0; i <= 80; i++) {
            final x = (i / 80) * L;
            final y = baseY + math.sin((i / 80) * math.pi * 4 + row) * L * 0.012;
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          c.strokePath(path, shader: strokeShader, width: math.max(1, L * 0.0022));
        }
        break;
      }
  }

  c.restore();
}
