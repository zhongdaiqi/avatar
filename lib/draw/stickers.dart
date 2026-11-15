import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/px.dart';

class StickerDef {
  const StickerDef(this.id, this.name);
  final String id;
  final String name;
}

const List<StickerDef> stickerList = [
  StickerDef('heart', '爱心'),
  StickerDef('heart2', '双心'),
  StickerDef('star', '星星'),
  StickerDef('bolt', '闪电'),
  StickerDef('cloud', '云朵'),
  StickerDef('moon', '月亮'),
  StickerDef('sun', '太阳'),
  StickerDef('flame', '火焰'),
  StickerDef('note', '音符'),
  StickerDef('coffee', '咖啡'),
  StickerDef('paw', '爪印'),
  StickerDef('crown', '皇冠'),
  StickerDef('tear', '水滴'),
  StickerDef('bubble', '气泡'),
  StickerDef('exclaim', '感叹'),
  StickerDef('check', '对勾'),
  StickerDef('butterfly', '蝴蝶'),
  StickerDef('diamond', '钻石'),
  StickerDef('flower', '花朵'),
  StickerDef('feather', '羽毛'),
  StickerDef('gift', '礼物'),
  StickerDef('umbrella', '雨伞'),
  StickerDef('clock', '时钟'),
  StickerDef('smiley', '笑脸'),
];

const List<String> emojiList = [
  '😎', '🥳', '😴', '🤯', '😭', '🥺', '💰',
  '🔥', '💯', '✨', '🎉', '🌙', '⭐', '🍀', '🎂', '❤️',
];

StickerDef? stickerById(String id) {
  for (final d in stickerList) {
    if (d.id == id) return d;
  }
  return null;
}

Path _heartPath({double k = 1 / 15}) {
  final p = Path();
  for (var i = 0; i <= 90; i++) {
    final t = (i / 90) * math.pi * 2;
    final hx = 16 * math.pow(math.sin(t), 3);
    final hy = 13 * math.cos(t) -
        5 * math.cos(2 * t) -
        2 * math.cos(3 * t) -
        math.cos(4 * t);
    final px = hx * k;
    final py = -(hy + 2.5) * k;
    if (i == 0) {
      p.moveTo(px, py);
    } else {
      p.lineTo(px, py);
    }
  }
  p.close();
  return p;
}

Path _starPath(int points, double outer, double inner) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + (i * math.pi) / points;
    final r = i % 2 == 1 ? inner : outer;
    final x = math.cos(a) * r;
    final y = math.sin(a) * r;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  p.close();
  return p;
}

Path _ellipse(double cx, double cy, double rx, double ry, [double rot = 0]) {
  const kk = 0.5522847498;
  final co = math.cos(rot);
  final si = math.sin(rot);
  Offset pt(double x, double y) =>
      Offset(cx + x * co - y * si, cy + x * si + y * co);

  final a = pt(rx, 0);
  final p = Path()..moveTo(a.dx, a.dy);
  void cubic(Offset c1, Offset c2, Offset end) =>
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

  cubic(pt(rx, ry * kk), pt(rx * kk, ry), pt(0, ry));
  cubic(pt(-rx * kk, ry), pt(-rx, ry * kk), pt(-rx, 0));
  cubic(pt(-rx, -ry * kk), pt(-rx * kk, -ry), pt(0, -ry));
  cubic(pt(rx * kk, -ry), pt(rx, -ry * kk), pt(rx, 0));
  p.close();
  return p;
}

/// 所有图形在 -1 ~ 1 的单位空间内绘制，由调用方负责平移/旋转/缩放
void drawSticker(
  Pc c, {
  required String id,
  required String kind,
  required double size,
  required Color color,
}) {
  if (kind == 'emoji') {
    final tp = TextPainter(
      text: TextSpan(
        text: id,
        style: TextStyle(fontSize: size * 0.92, color: color),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c.canvas, Offset(-tp.width / 2, -tp.height / 2));
    return;
  }

  final def = stickerById(id);
  if (def == null) return;

  c.save();
  c.scale(size / 2);

  switch (def.id) {
    case 'heart':
      c.fillPath(_heartPath(), color: color);
      break;

    case 'heart2':
      c.save();
      c.translate(-0.42, 0.18);
      c.scale(0.66);
      c.fillPath(_heartPath(), color: color);
      c.restore();
      c.save();
      c.translate(0.42, -0.08);
      c.scale(0.86);
      c.alpha = 0.85;
      c.fillPath(_heartPath(), color: color);
      c.restore();
      break;

    case 'star':
      c.fillPath(_starPath(5, 1, 0.44), color: color);
      break;

    case 'bolt':
      c.fillPath(
        Path()
          ..moveTo(0.18, -1)
          ..lineTo(-0.6, 0.14)
          ..lineTo(-0.06, 0.14)
          ..lineTo(-0.2, 1)
          ..lineTo(0.6, -0.18)
          ..lineTo(0.04, -0.18)
          ..close(),
        color: color,
      );
      break;

    case 'cloud':
      {
        final p = Path()
          ..addArc(
              Rect.fromCircle(center: Offset(-0.42, 0.16), radius: 0.42),
              math.pi,
              math.pi)
          ..addArc(
              Rect.fromCircle(center: Offset(0, -0.16), radius: 0.56),
              math.pi * 1.05,
              math.pi * 0.90)
          ..addArc(
              Rect.fromCircle(center: Offset(0.46, 0.14), radius: 0.44),
              math.pi * 1.15,
              math.pi * 0.90)
          ..lineTo(0.46, 0.6)
          ..lineTo(-0.42, 0.6)
          ..close();
        c.fillPath(p, color: color);
        break;
      }

    case 'moon':
      {
        final p = Path()
          ..moveTo(0.22, -0.98)
          ..arcTo(Rect.fromCircle(center: Offset(0.22, 0), radius: 0.98),
              -math.pi / 2, math.pi, true)
          ..quadraticBezierTo(0.68, 0, 0.22, -0.98)
          ..close();
        c.fillPath(p, color: color);
        break;
      }

    case 'sun':
      {
        c.circle(0, 0, 0.54, color: color);
        for (var i = 0; i < 8; i++) {
          c.save();
          c.rotate((i / 8) * math.pi * 2);
          c.fillPath(
            Path()
              ..moveTo(-0.1, -0.68)
              ..lineTo(0, -1)
              ..lineTo(0.1, -0.68)
              ..close(),
            color: color,
          );
          c.restore();
        }
        break;
      }

    case 'flame':
      c.fillPath(
        Path()
          ..moveTo(0, -1)
          ..cubicTo(0.62, -0.36, 0.72, 0.36, 0.3, 0.86)
          ..cubicTo(0.12, 1, -0.12, 1, -0.3, 0.86)
          ..cubicTo(-0.72, 0.36, -0.42, -0.2, -0.16, -0.56)
          ..cubicTo(-0.06, -0.32, 0.02, -0.56, 0, -1)
          ..close(),
        color: color,
      );
      break;

    case 'note':
      {
        c.save();
        c.translate(-0.34, 0.5);
        c.rotate(-0.35);
        c.fillPath(_ellipse(0, 0, 0.36, 0.27), color: color);
        c.restore();
        c.fillRect(const Rect.fromLTWH(0.02, -0.72, 0.16, 1.24), color: color);
        c.fillPath(
          Path()
            ..moveTo(0.18, -0.72)
            ..quadraticBezierTo(0.7, -0.56, 0.62, -0.06)
            ..quadraticBezierTo(0.52, -0.42, 0.18, -0.36)
            ..close(),
          color: color,
        );
        break;
      }

    case 'coffee':
      {
        c.fillPath(
          Path()
            ..moveTo(-0.62, -0.28)
            ..lineTo(0.46, -0.28)
            ..lineTo(0.38, 0.66)
            ..lineTo(-0.54, 0.66)
            ..close(),
          color: color,
        );
        c.strokePath(
          Path()
            ..addArc(Rect.fromCircle(center: Offset(0.5, 0.1), radius: 0.26),
                -math.pi / 2, math.pi),
          color: color,
          width: 0.16,
        );
        for (var i = -1; i <= 1; i++) {
          c.strokePath(
            Path()
              ..moveTo(i * 0.26, -0.48)
              ..quadraticBezierTo(i * 0.26 + 0.16, -0.66, i * 0.26, -0.86),
            color: color,
            width: 0.1,
            cap: StrokeCap.butt,
          );
        }
        break;
      }

    case 'paw':
      {
        c.fillPath(_ellipse(0, 0.34, 0.52, 0.42), color: color);
        const toes = [
          [-0.56, -0.16, 0.24, 0.3, -0.5],
          [-0.2, -0.52, 0.22, 0.28, -0.2],
          [0.2, -0.52, 0.22, 0.28, 0.2],
          [0.56, -0.16, 0.24, 0.3, 0.5],
        ];
        for (final t in toes) {
          c.fillPath(_ellipse(t[0], t[1], t[2], t[3], t[4]), color: color);
        }
        break;
      }

    case 'crown':
      c.fillPath(
        Path()
          ..moveTo(-0.9, 0.56)
          ..lineTo(-0.9, -0.24)
          ..lineTo(-0.46, 0.1)
          ..lineTo(-0.14, -0.72)
          ..lineTo(0.2, 0.06)
          ..lineTo(0.52, -0.62)
          ..lineTo(0.9, 0.14)
          ..lineTo(0.9, 0.56)
          ..close(),
        color: color,
      );
      break;

    case 'tear':
      c.fillPath(
        Path()
          ..moveTo(0, -1)
          ..cubicTo(0.6, -0.3, 0.72, 0.2, 0.5, 0.6)
          ..cubicTo(0.24, 1.02, -0.24, 1.02, -0.5, 0.6)
          ..cubicTo(-0.72, 0.2, -0.6, -0.3, 0, -1)
          ..close(),
        color: color,
      );
      break;

    case 'bubble':
      {
        const r = 0.34;
        final p = Path()
          ..moveTo(-0.78 + r, -0.72)
          ..arcToPoint(const Offset(0.8, 0.72),
              radius: const Radius.circular(r), clockwise: true)
          ..arcToPoint(const Offset(0.8, 0.24),
              radius: const Radius.circular(r), clockwise: true)
          ..lineTo(-0.78, 0.24)
          ..arcToPoint(const Offset(-0.78, -0.72),
              radius: const Radius.circular(r), clockwise: true)
          ..close();
        final tail = Path()
          ..moveTo(-0.2, 0.24)
          ..lineTo(-0.36, 0.92)
          ..lineTo(-0.02, 0.24)
          ..close();
        c.fillPath(p, color: color);
        c.fillPath(tail, color: color);
        break;
      }

    case 'exclaim':
      c.fillPath(
        Path()
          ..moveTo(-0.2, -0.96)
          ..lineTo(0.2, -0.96)
          ..lineTo(0.1, 0.24)
          ..lineTo(-0.1, 0.24)
          ..close(),
        color: color,
      );
      c.circle(0, 0.66, 0.19, color: color);
      break;

    case 'check':
      c.strokePath(
        Path()
          ..moveTo(-0.62, 0.04)
          ..lineTo(-0.14, 0.54)
          ..lineTo(0.64, -0.56),
        color: color,
        width: 0.24,
      );
      break;

    case 'butterfly':
      {
        for (var sign = -1.0; sign <= 1; sign += 2) {
          c.fillPath(_ellipse(sign * 0.42, -0.28, 0.44, 0.36, sign * 0.5),
              color: color);
          c.alpha = 0.8;
          c.fillPath(_ellipse(sign * 0.36, 0.42, 0.32, 0.3, sign * -0.4),
              color: color);
          c.alpha = 1;
        }
        c.fillRect(const Rect.fromLTWH(-0.055, -0.72, 0.11, 1.4),
            color: color);
        c.strokePath(
          Path()
            ..moveTo(0, -0.7)
            ..quadraticBezierTo(-0.2, -0.94, -0.32, -0.98)
            ..moveTo(0, -0.7)
            ..quadraticBezierTo(0.2, -0.94, 0.32, -0.98),
          color: color,
          width: 0.06,
        );
        break;
      }

    case 'diamond':
      {
        c.fillPath(
          Path()
            ..moveTo(0, -0.86)
            ..lineTo(0.72, -0.2)
            ..lineTo(0, 0.92)
            ..lineTo(-0.72, -0.2)
            ..close(),
          color: color,
        );
        c.alpha = 0.55;
        c.fillPath(
          Path()
            ..moveTo(0, -0.86)
            ..lineTo(0.72, -0.2)
            ..lineTo(0, -0.2)
            ..close(),
          color: const Color(0xFFFFFFFF),
        );
        c.alpha = 1;
        break;
      }

    case 'flower':
      {
        for (var i = 0; i < 5; i++) {
          c.save();
          c.rotate((i / 5) * math.pi * 2);
          c.fillPath(_ellipse(0, -0.6, 0.3, 0.44), color: color);
          c.restore();
        }
        c.alpha = 0.45;
        c.circle(0, 0, 0.22, color: const Color(0xFFFFFFFF));
        c.alpha = 1;
        break;
      }

    case 'feather':
      {
        c.fillPath(
          Path()
            ..moveTo(0.1, -1)
            ..cubicTo(0.78, -0.42, 0.6, 0.42, -0.1, 0.98)
            ..cubicTo(-0.5, 0.4, -0.5, -0.4, 0.1, -1)
            ..close(),
          color: color,
        );
        c.alpha = 0.5;
        c.strokePath(
          Path()
            ..moveTo(0.06, -0.92)
            ..lineTo(-0.12, 0.72),
          color: const Color(0xFFFFFFFF),
          width: 0.07,
        );
        c.alpha = 1;
        break;
      }

    case 'gift':
      {
        c.fillRect(const Rect.fromLTWH(-0.8, -0.36, 1.6, 1.24), color: color);
        c.fillRect(const Rect.fromLTWH(-0.92, -0.62, 1.84, 0.3), color: color);
        c.alpha = 0.55;
        c.fillRect(const Rect.fromLTWH(-0.12, -0.62, 0.24, 1.5),
            color: const Color(0xFFFFFFFF));
        c.alpha = 1;
        c.fillPath(_ellipse(-0.28, -0.86, 0.26, 0.2, 0.4), color: color);
        c.fillPath(_ellipse(0.28, -0.86, 0.26, 0.2, -0.4), color: color);
        break;
      }

    case 'umbrella':
      {
        c.fillPath(
          Path()
            ..moveTo(-1, 0.1)
            ..quadraticBezierTo(-1, -0.86, 0, -0.86)
            ..quadraticBezierTo(1, -0.86, 1, 0.1)
            ..quadraticBezierTo(0.66, -0.16, 0.33, 0.1)
            ..quadraticBezierTo(0, -0.16, -0.33, 0.1)
            ..quadraticBezierTo(-0.66, -0.16, -1, 0.1)
            ..close(),
          color: color,
        );
        c.strokePath(
          Path()
            ..moveTo(0, 0.1)
            ..lineTo(0, 0.72)
            ..quadraticBezierTo(0, 0.96, -0.24, 0.96),
          color: color,
          width: 0.12,
        );
        break;
      }

    case 'clock':
      {
        c.strokePath(
          Path()
            ..addArc(Rect.fromCircle(center: Offset.zero, radius: 0.88), 0,
                math.pi * 2),
          color: color,
          width: 0.16,
        );
        c.strokePath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(0, -0.56)
            ..moveTo(0, 0)
            ..lineTo(0.42, 0.2),
          color: color,
          width: 0.14,
        );
        break;
      }

    case 'smiley':
      {
        c.strokePath(
          Path()
            ..addArc(Rect.fromCircle(center: Offset.zero, radius: 0.88), 0,
                math.pi * 2),
          color: color,
          width: 0.16,
        );
        c.circle(-0.3, -0.2, 0.11, color: color);
        c.circle(0.3, -0.2, 0.11, color: color);
        c.strokePath(
          Path()
            ..addArc(Rect.fromCircle(center: Offset.zero, radius: 0.46),
                0.28 * math.pi, 0.44 * math.pi),
          color: color,
          width: 0.16,
        );
        break;
      }
  }

  c.restore();
}
