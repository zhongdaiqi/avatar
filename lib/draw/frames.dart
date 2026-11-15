import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/px.dart';
import 'shapes.dart';

/// 边框绘制状态（对应 JS 版的 S 对象）
class FrameState {
  FrameState({
    required this.id,
    required this.shape,
    required this.cx,
    required this.cy,
    required this.r,
    required this.color,
    required this.width,
    required this.gap,
    required this.alpha,
    Map<String, double>? params,
  }) : params = params ?? <String, double>{};

  final String id;
  final String shape;
  final double cx;
  final double cy;
  final double r;
  final Color color;
  final double width;
  final double gap;
  final double alpha;
  final Map<String, double> params;
}

class FrameDef {
  const FrameDef(this.id, this.name, this.group);
  final String id;
  final String name;
  final String group;
}

const List<FrameDef> frameDefs = [
  FrameDef('ring', '单线', 'line'),
  FrameDef('ring2', '双线', 'line'),
  FrameDef('dash', '虚线', 'line'),
  FrameDef('dash2', '错位双虚', 'line'),
  FrameDef('grad', '渐变', 'line'),
  FrameDef('duo', '双色段', 'line'),
  FrameDef('glow', '光晕', 'light'),
  FrameDef('halo', '厚环', 'light'),
  FrameDef('neon', '霓虹', 'light'),
  FrameDef('inner', '内影', 'light'),
  FrameDef('sparkle', '星芒', 'light'),
  FrameDef('vine', '藤蔓', 'plant'),
  FrameDef('laurel', '月桂', 'plant'),
  FrameDef('sakura', '樱花', 'plant'),
  FrameDef('daisy', '雏菊', 'plant'),
  FrameDef('zigzag', '齿环', 'geo'),
  FrameDef('gear', '齿轮', 'geo'),
  FrameDef('film', '胶片', 'geo'),
  FrameDef('pixel', '像素', 'geo'),
  FrameDef('wave', '波纹', 'geo'),
  FrameDef('snow', '雪花', 'festival'),
  FrameDef('moon', '月相', 'festival'),
  FrameDef('candy', '糖果', 'festival'),
  FrameDef('crown', '皇冠', 'topper'),
  FrameDef('catear', '猫耳', 'topper'),
  FrameDef('rabbit', '兔耳', 'topper'),
  FrameDef('bow', '蝴蝶结', 'topper'),
];

const List<FrameDef> frameList = [
  FrameDef('', '无', ''),
  ...frameDefs,
];

FrameDef? frameById(String id) {
  for (final d in frameDefs) {
    if (d.id == id) return d;
  }
  return null;
}

/* ---------------- 基础工具 ---------------- */

Path _sPath(FrameState s, double k) =>
    shapePath(s.shape, s.cx, s.cy, s.r * k, s.params);

/// 计算不越出画布的安全缩放：off = 离形状边缘的距离，w = 线宽
double _kin(FrameState s, double off, double w) =>
    math.max(0.05, 1 - (off + w / 2) / s.r);

void _ring(
  Pc c,
  FrameState s,
  double k,
  double w, [
  double? a,
  List<double>? dash,
  Color? stroke,
]) {
  c.save();
  c.alpha = s.alpha * (a ?? 1);
  c.strokePath(
    _sPath(s, k),
    color: stroke ?? s.color,
    width: w,
    dash: dash,
  );
  c.restore();
}

Offset _at(FrameState s, double deg, double k) =>
    polarAt(s.cx, s.cy, s.r, k, deg);

void _star4(Pc c, double x, double y, double rr, Color fill) {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + (i * math.pi) / 4;
    final rd = i % 2 == 1 ? rr * 0.24 : rr;
    final px = x + math.cos(a) * rd;
    final py = y + math.sin(a) * rd;
    if (i == 0) {
      p.moveTo(px, py);
    } else {
      p.lineTo(px, py);
    }
  }
  p.close();
  c.fillPath(p, color: fill);
}

void _dot(Pc c, double x, double y, double rr, Color fill, [double a = 1]) {
  c.save();
  c.alpha = a * c.alpha;
  c.circle(x, y, rr, color: fill);
  c.restore();
}

void _flower(Pc c, double x, double y, double rr, Color fill, int petals,
    [double a = 1]) {
  c.save();
  c.alpha = a * c.alpha;
  for (var i = 0; i < petals; i++) {
    final ang = (i / petals) * math.pi * 2;
    c.save();
    c.translate(x + math.cos(ang) * rr * 0.46, y + math.sin(ang) * rr * 0.46);
    c.rotate(ang);
    final p = Path()
      ..addOval(Rect.fromCenter(
          center: Offset.zero, width: rr * 0.56 * 2, height: rr * 0.44 * 2));
    c.fillPath(p, color: fill);
    c.restore();
  }
  c.circle(x, y, rr * 0.26, color: fill);
  c.restore();
}

void _snowflake(Pc c, double x, double y, double rr, Color fill, double w,
    [double a = 1]) {
  c.save();
  c.alpha = a * c.alpha;
  c.translate(x, y);
  for (var i = 0; i < 6; i++) {
    c.rotate(math.pi / 3);
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -rr)
      ..moveTo(0, -rr * 0.6)
      ..lineTo(rr * 0.26, -rr * 0.84)
      ..moveTo(0, -rr * 0.6)
      ..lineTo(-rr * 0.26, -rr * 0.84);
    c.strokePath(p, color: fill, width: w, cap: StrokeCap.round);
  }
  c.restore();
}

void _leaf(Pc c, double x, double y, double rr, double ang, Color fill,
    [double a = 1]) {
  c.save();
  c.alpha = a * c.alpha;
  c.translate(x, y);
  c.rotate(ang);
  final p = Path()
    ..moveTo(0, -rr)
    ..cubicTo(rr * 0.62, -rr * 0.42, rr * 0.5, rr * 0.55, 0, rr)
    ..cubicTo(-rr * 0.5, rr * 0.55, -rr * 0.62, -rr * 0.42, 0, -rr)
    ..close();
  c.fillPath(p, color: fill);
  c.restore();
}

void _tri(Pc c, double x, double y, double rr, double rot, Color fill,
    [double a = 1]) {
  c.save();
  c.alpha = a * c.alpha;
  c.translate(x, y);
  c.rotate(rot);
  final p = Path()
    ..moveTo(0, -rr)
    ..lineTo(rr, rr * 0.72)
    ..lineTo(-rr, rr * 0.72)
    ..close();
  c.fillPath(p, color: fill);
  c.restore();
}

Shader _gradStroke(FrameState s) {
  final r = Rect.fromLTWH(
      s.cx - s.r, s.cy - s.r, s.r * 2, s.r * 2);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lighten(s.color, 0.42), s.color, darken(s.color, 0.22)],
    stops: const [0, 0.5, 1],
  ).createShader(r);
}

/* ---------------- 各边框 ---------------- */

void drawFrame(Pc c, FrameState s) {
  final def = frameById(s.id);
  if (def == null) return;

  switch (def.id) {
    case 'ring':
      double w = s.width;
      _ring(c, s, _kin(s, 0, w), w);
      break;

    case 'ring2':
      {
        final w = s.width * 0.7;
        _ring(c, s, _kin(s, 0, w), w);
        final w2 = w * 0.55;
        _ring(c, s, _kin(s, w + s.gap, w2), w2, 0.85);
        break;
      }

    case 'dash':
      {
        final w = s.width;
        _ring(c, s, _kin(s, 0, w), w, 1, [w * 2.2, w * 1.9]);
        break;
      }

    case 'dash2':
      {
        final w = s.width * 0.62;
        _ring(c, s, _kin(s, 0, w), w, 1, [w * 2.6, w * 2.2]);
        c.save();
        c.alpha = s.alpha * 0.8;
        final dash = [w * 2.6, w * 2.2];
        c.strokePath(
          _sPath(s, _kin(s, w + s.gap, w)),
          color: s.color,
          width: w,
          dash: dash,
          dashOffset: dash[0] / 2,
        );
        c.restore();
        break;
      }

    case 'grad':
      {
        final w = s.width;
        c.save();
        c.alpha = s.alpha;
        c.strokePath(_sPath(s, _kin(s, 0, w)),
            width: w, shader: _gradStroke(s));
        c.restore();
        break;
      }

    case 'duo':
      {
        final w = s.width;
        final k = _kin(s, 0, w);
        final seg = s.r * 0.16;
        _ring(c, s, k, w, 1, [seg, seg], s.color);
        c.save();
        c.alpha = s.alpha;
        c.strokePath(_sPath(s, k),
            color: darken(s.color, 0.34),
            width: w,
            dash: [seg, seg],
            dashOffset: seg);
        c.restore();
        break;
      }

    case 'glow':
      {
        final w = s.width;
        _ring(c, s, _kin(s, 0, w), w);
        final w2 = w * 1.5;
        _ring(c, s, _kin(s, w * 0.9, w2), w2, 0.38);
        final w3 = w * 2.2;
        _ring(c, s, _kin(s, w * 2.2, w3), w3, 0.16);
        break;
      }

    case 'halo':
      {
        final w = s.width * 1.8;
        c.save();
        c.alpha = s.alpha * 0.92;
        c.strokePath(
          _sPath(s, _kin(s, 0, w)),
          color: s.color,
          width: w,
          shadowColor: s.color,
          shadowBlur: s.r * 0.12,
        );
        c.restore();
        break;
      }

    case 'neon':
      {
        final w = s.width * 0.55;
        _ring(c, s, _kin(s, 0, w), w);
        _ring(c, s, _kin(s, w * 1.1, w), w, 0.55, null, lighten(s.color, 0.55));
        _ring(c, s, _kin(s, 0, w * 2.4), w * 2.4, 0.14);
        break;
      }

    case 'inner':
      {
        final w = s.width;
        for (var i = 0; i < 3; i++) {
          final off = w * (1 + i * 1.5);
          _ring(c, s, _kin(s, off, w), w, 0.3 * math.pow(0.55, i).toDouble());
        }
        final w2 = w * 0.8;
        _ring(c, s, _kin(s, 0, w2), w2);
        break;
      }

    case 'sparkle':
      {
        final w = s.width;
        _ring(c, s, _kin(s, 0, w), w, 0.9);
        c.save();
        c.alpha = s.alpha;
        const n = 8;
        for (var i = 0; i < n; i++) {
          final p = _at(s, (i / n) * 360 - 90, 0.93);
          _star4(c, p.dx, p.dy, s.r * (i % 2 == 1 ? 0.036 : 0.05), s.color);
        }
        c.restore();
        break;
      }

    case 'vine':
      {
        final w = s.width * 0.5;
        final k = _kin(s, 0, w);
        _ring(c, s, k, w);
        c.save();
        c.alpha = s.alpha;
        for (var i = 0; i < 16; i++) {
          final deg = (i / 16) * 360 - 90;
          final p = _at(s, deg, k - 0.085);
          final ang = ((deg + 90) * math.pi) / 180 + (i % 2 == 1 ? 0.55 : -0.55);
          _leaf(c, p.dx, p.dy, s.r * 0.07, ang, s.color);
        }
        c.restore();
        break;
      }

    case 'laurel':
      {
        final w = s.width * 0.45;
        _ring(c, s, _kin(s, 0, w), w, 0.85);
        c.save();
        c.alpha = s.alpha;
        for (var i = 0; i < 6; i++) {
          final dl = 108.0 + i * 13;
          final dr = 180 - dl;
          final pl = _at(s, dl, 0.9);
          final pr = _at(s, dr, 0.9);
          _leaf(c, pl.dx, pl.dy, s.r * 0.075, ((dl + 90) * math.pi) / 180 + 0.14,
              s.color);
          _leaf(c, pr.dx, pr.dy, s.r * 0.075, ((dr + 90) * math.pi) / 180 - 0.14,
              s.color);
        }
        c.restore();
        break;
      }

    case 'sakura':
      {
        final w = s.width * 0.4;
        _ring(c, s, _kin(s, 0, w), w, 0.75);
        c.save();
        c.alpha = s.alpha;
        const n = 8;
        for (var i = 0; i < n; i++) {
          final p = _at(s, (i / n) * 360 - 90, 0.88);
          _flower(c, p.dx, p.dy, s.r * 0.082, s.color, 5);
        }
        c.restore();
        break;
      }

    case 'daisy':
      {
        final w = s.width * 0.4;
        final k = _kin(s, 0, w);
        _ring(c, s, k, w, 0.7, [1, s.r * 0.09]);
        c.save();
        c.alpha = s.alpha;
        for (var i = 0; i < 18; i++) {
          final p = _at(s, (i / 18) * 360, 0.925);
          _dot(c, p.dx, p.dy, s.width * 0.5, s.color);
        }
        c.restore();
        break;
      }

    case 'zigzag':
      {
        final w = s.width * 0.5;
        _ring(c, s, _kin(s, 0, w), w, 0.85);
        c.save();
        c.alpha = s.alpha;
        const n = 28;
        for (var i = 0; i < n; i++) {
          final deg = (i / n) * 360;
          final p = _at(s, deg, 0.935);
          _tri(c, p.dx, p.dy, s.r * 0.03,
              ((deg + 90) * math.pi) / 180 + math.pi, s.color);
        }
        c.restore();
        break;
      }

    case 'gear':
      {
        final w = s.width * 0.55;
        _ring(c, s, _kin(s, 0, w), w);
        _ring(c, s, _kin(s, w * 2.6, w * 0.5), w * 0.5, 0.7);
        c.save();
        c.alpha = s.alpha;
        const n = 16;
        for (var i = 0; i < n; i++) {
          final deg = (i / n) * 360;
          final p = _at(s, deg, 0.928);
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(((deg + 90) * math.pi) / 180);
          c.fillRect(
            Rect.fromLTWH(-s.r * 0.028, -s.r * 0.045, s.r * 0.056, s.r * 0.09),
            color: s.color,
          );
          c.restore();
        }
        c.restore();
        break;
      }

    case 'film':
      {
        final w = s.width * 0.5;
        _ring(c, s, _kin(s, 0, w), w);
        _ring(c, s, _kin(s, w * 5, w * 0.4), w * 0.4, 0.55);
        c.save();
        c.alpha = s.alpha;
        const n = 20;
        for (var i = 0; i < n; i++) {
          final p = _at(s, (i / n) * 360, 0.918);
          final rw = s.r * 0.038;
          final rh = s.r * 0.062;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(((i / n) * 360 * math.pi) / 180);
          final r = rw * 0.42;
          final path = Path()
            ..moveTo(-rw + r, -rh)
            ..arcToPoint(Offset(rw, rh), radius: Radius.circular(r), clockwise: true)
            ..arcToPoint(Offset(-rw, rh), radius: Radius.circular(r), clockwise: true)
            ..arcToPoint(Offset(-rw, -rh), radius: Radius.circular(r), clockwise: true)
            ..arcToPoint(Offset(rw, -rh), radius: Radius.circular(r), clockwise: true);
          c.fillPath(path, color: s.color);
          c.restore();
        }
        c.restore();
        break;
      }

    case 'pixel':
      {
        c.save();
        c.alpha = s.alpha;
        final w = s.width * 0.55;
        final k = _kin(s, 0, w);
        const n = 32;
        for (var i = 0; i < n; i++) {
          if (i % 3 == 1) continue;
          final p = _at(s, (i / n) * 360, k);
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(((i / n) * 360 * math.pi) / 180);
          final sz = w * 1.35;
          c.fillRect(
            Rect.fromLTWH(-sz / 2, -sz / 2, sz, sz),
            color: s.color,
          );
          c.restore();
        }
        c.restore();
        break;
      }

    case 'wave':
      {
        final w = s.width * 0.55;
        final k = _kin(s, 0, w);
        c.save();
        c.alpha = s.alpha;
        final path = Path();
        const n = 720;
        for (var i = 0; i <= n; i++) {
          final t = (i / n) * math.pi * 2;
          final rr = s.r * k * (1 + 0.022 * math.sin(t * 18));
          final x = s.cx + rr * math.cos(t);
          final y = s.cy + rr * math.sin(t);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        c.strokePath(path, color: s.color, width: w);
        c.restore();
        break;
      }

    case 'snow':
      {
        final w = s.width * 0.4;
        _ring(c, s, _kin(s, 0, w), w, 0.8);
        c.save();
        c.alpha = s.alpha;
        const n = 10;
        for (var i = 0; i < n; i++) {
          final p = _at(s, (i / n) * 360 - 90, 0.885);
          _snowflake(c, p.dx, p.dy, s.r * (i % 2 == 1 ? 0.04 : 0.055),
              s.color, math.max(1, w * 0.4));
        }
        c.restore();
        break;
      }

    case 'moon':
      {
        final w = s.width * 0.4;
        _ring(c, s, _kin(s, 0, w), w, 0.7);
        c.save();
        c.alpha = s.alpha;
        const n = 8;
        for (var i = 0; i < n; i++) {
          final deg = (i / n) * 360 - 90;
          final p = _at(s, deg, 0.895);
          final rr = s.r * 0.055;
          final phase = 0.18 + (i / n) * 0.62;
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(((deg + 90) * math.pi) / 180);
          final path = Path()
            ..arcTo(Rect.fromCircle(center: Offset.zero, radius: rr),
                -math.pi / 2, math.pi, false)
            ..quadraticBezierTo(rr * (1 - 2.1 * phase), 0, 0, -rr)
            ..close();
          c.fillPath(path, color: s.color);
          c.restore();
        }
        c.restore();
        break;
      }

    case 'candy':
      {
        final w = s.width * 1.2;
        final k = _kin(s, 0, w);
        c.save();
        c.alpha = s.alpha;
        c.strokePath(_sPath(s, k), color: s.color, width: w, cap: StrokeCap.butt);
        final seg = s.r * 0.055;
        c.strokePath(_sPath(s, k),
            color: lighten(s.color, 0.6),
            width: w,
            dash: [seg, seg * 1.6],
            cap: StrokeCap.butt);
        c.restore();
        break;
      }

    case 'crown':
      {
        final w = s.width * 0.55;
        _ring(c, s, _kin(s, 0, w), w, 0.55);
        c.save();
        c.alpha = s.alpha;
        final cw = s.r * 0.42;
        final ch = s.r * 0.22;
        final cx = s.cx;
        final cy = s.cy - s.r * 0.68;
        final path = Path()
          ..moveTo(cx - cw, cy)
          ..lineTo(cx - cw, cy - ch * 0.55)
          ..lineTo(cx - cw * 0.55, cy - ch * 0.15)
          ..lineTo(cx - cw * 0.2, cy - ch)
          ..lineTo(cx + cw * 0.1, cy - ch * 0.2)
          ..lineTo(cx + cw * 0.5, cy - ch * 1.05)
          ..lineTo(cx + cw * 0.6, cy - ch * 0.4)
          ..lineTo(cx + cw, cy - ch * 0.6)
          ..lineTo(cx + cw, cy)
          ..close();
        c.fillPath(path, color: s.color);
        c.restore();
        break;
      }

    case 'catear':
      {
        final w = s.width * 0.5;
        _ring(c, s, _kin(s, 0, w), w, 0.6);
        c.save();
        c.alpha = s.alpha;
        final inner = lighten(s.color, 0.62);
        for (var sign = -1; sign <= 1; sign += 2) {
          final ex = s.cx + sign * s.r * 0.33;
          final ey = s.cy - s.r * 0.71;
          _tri(c, ex, ey, s.r * 0.2, sign * 0.24, s.color);
          _tri(c, ex, ey + s.r * 0.016, s.r * 0.125, sign * 0.24, inner);
        }
        c.restore();
        break;
      }

    case 'rabbit':
      {
        final w = s.width * 0.5;
        _ring(c, s, _kin(s, 0, w), w, 0.6);
        c.save();
        c.alpha = s.alpha;
        final earIn = lighten(s.color, 0.58);
        for (var sign = -1; sign <= 1; sign += 2) {
          c.save();
          c.translate(s.cx + sign * s.r * 0.34, s.cy - s.r * 0.74);
          c.rotate(sign * 0.28);
          c.fillPath(
            Path()
              ..addOval(Rect.fromCenter(
                  center: Offset.zero,
                  width: s.r * 0.09 * 2,
                  height: s.r * 0.27 * 2)),
            color: s.color,
          );
          c.fillPath(
            Path()
              ..addOval(Rect.fromCenter(
                  center: Offset(0, s.r * 0.03),
                  width: s.r * 0.045 * 2,
                  height: s.r * 0.17 * 2)),
            color: earIn,
          );
          c.restore();
        }
        c.restore();
        break;
      }

    case 'bow':
      {
        final w = s.width * 0.5;
        _ring(c, s, _kin(s, 0, w), w, 0.6);
        c.save();
        c.alpha = s.alpha;
        final bx = s.cx - s.r * 0.46;
        final by = s.cy - s.r * 0.52;
        final rr = s.r * 0.15;
        c.save();
        c.translate(bx, by);
        c.rotate(-0.42);

        // 飘带：没有它就只是个"横向胶囊"，加上才有礼物的意思
        c.fillPath(
          Path()
            ..moveTo(-rr * 0.18, rr * 0.2)
            ..quadraticBezierTo(-rr * 0.78, rr * 1.02, -rr * 0.34, rr * 1.26)
            ..lineTo(-rr * 0.06, rr * 0.52)
            ..close(),
          color: s.color,
        );
        c.fillPath(
          Path()
            ..moveTo(rr * 0.18, rr * 0.2)
            ..quadraticBezierTo(rr * 0.74, rr * 1.0, rr * 0.3, rr * 1.22)
            ..lineTo(rr * 0.05, rr * 0.52)
            ..close(),
          color: s.color,
        );

        // 左右结耳 + 中心结
        c.save();
        c.translate(-rr * 0.88, 0);
        c.rotate(-0.42);
        c.fillPath(
          Path()
            ..addOval(Rect.fromCenter(
                center: Offset.zero,
                width: rr * 0.84 * 2,
                height: rr * 0.62 * 2)),
          color: s.color,
        );
        c.restore();
        c.save();
        c.translate(rr * 0.88, 0);
        c.rotate(0.42);
        c.fillPath(
          Path()
            ..addOval(Rect.fromCenter(
                center: Offset.zero,
                width: rr * 0.84 * 2,
                height: rr * 0.62 * 2)),
          color: s.color,
        );
        c.restore();
        c.circle(0, 0, rr * 0.42, color: s.color);
        c.restore();
        c.restore();
        break;
      }
  }
}
