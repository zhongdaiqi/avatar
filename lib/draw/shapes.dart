import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/px.dart';

class ShapeDef {
  const ShapeDef(this.id, this.name);
  final String id;
  final String name;
}

const List<ShapeDef> shapeList = [
  ShapeDef('square', '方形'),
  ShapeDef('circle', '圆形'),
  ShapeDef('rounded', '圆角'),
  ShapeDef('squircle', '超椭'),
  ShapeDef('heart', '心形'),
  ShapeDef('hexagon', '六边'),
  ShapeDef('flower', '花瓣'),
  ShapeDef('star', '星形'),
  ShapeDef('drop', '水滴'),
];

/// 把形状追加进已有路径（等价 shapes.js 的 pathTo：不 beginPath）。
/// 需要"矩形 + 形状"合成 evenodd 路径时必须用它。
Path shapePathTo(
  Path path,
  String type,
  double cx,
  double cy,
  double r,
  Map<String, double> params,
) {
  final p = params;

  switch (type) {
    case 'rounded':
      {
        final k = math.min(0.5, p['radius'] ?? 0.22) * 2 * r;
        final x = cx - r;
        final y = cy - r;
        final w = 2 * r;
        path.moveTo(x + k, y);
        path.lineTo(x + w - k, y);
        path.arcToPoint(Offset(x + w, y + k),
            radius: Radius.circular(k), clockwise: true);
        path.lineTo(x + w, y + w - k);
        path.arcToPoint(Offset(x + w - k, y + w),
            radius: Radius.circular(k), clockwise: true);
        path.lineTo(x + k, y + w);
        path.arcToPoint(Offset(x, y + w - k),
            radius: Radius.circular(k), clockwise: true);
        path.lineTo(x, y + k);
        path.arcToPoint(Offset(x + k, y), radius: Radius.circular(k), clockwise: true);
        break;
      }

    case 'squircle':
      {
        final n = p['n'] ?? 4;
        final e = 2 / n;
        const steps = 140;
        for (var i = 0; i <= steps; i++) {
          final t = (i / steps) * math.pi * 2;
          final c = math.cos(t);
          final s = math.sin(t);
          final px = cx + r * c.sign * math.pow(c.abs(), e).toDouble();
          final py = cy + r * s.sign * math.pow(s.abs(), e).toDouble();
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        break;
      }

    case 'heart':
      {
        const steps = 160;
        final k = r / 16;
        for (var i = 0; i <= steps; i++) {
          final t = (i / steps) * math.pi * 2;
          final hx = 16 * math.pow(math.sin(t), 3);
          final hy = 13 * math.cos(t) -
              5 * math.cos(2 * t) -
              2 * math.cos(3 * t) -
              math.cos(4 * t);
          final px = cx + hx * k;
          final py = cy - (hy + 2.5) * k;
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        break;
      }

    case 'hexagon':
      {
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + (i * math.pi) / 3;
          final px = cx + r * math.cos(a);
          final py = cy + r * math.sin(a);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        break;
      }

    case 'flower':
      {
        final lobes = p['lobes'] ?? 8;
        const steps = 200;
        for (var i = 0; i <= steps; i++) {
          final t = (i / steps) * math.pi * 2;
          final rr = r * (0.8 + 0.2 * math.cos(lobes * t));
          final px = cx + rr * math.cos(t - math.pi / 2);
          final py = cy + rr * math.sin(t - math.pi / 2);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        break;
      }

    case 'star':
      {
        final inner = p['inner'] ?? 0.46;
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + (i * math.pi) / 5;
          final rr = i % 2 == 0 ? r : r * inner;
          final px = cx + rr * math.cos(a);
          final py = cy + rr * math.sin(a);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        break;
      }

    case 'drop':
      {
        final rr = r * 0.78;
        final cyc = cy + (r - rr);
        path.moveTo(cx, cy - r);
        path.cubicTo(cx + rr * 0.55, cy - r * 0.62, cx + rr, cyc - rr * 0.72,
            cx + rr, cyc);
        path.arcTo(Rect.fromCircle(center: Offset(cx, cyc), radius: rr), 0,
            math.pi, false);
        path.cubicTo(cx - rr, cyc - rr * 0.72, cx - rr * 0.55, cy - r * 0.62,
            cx, cy - r);
        break;
      }

    case 'square':
      path.addRect(Rect.fromLTWH(cx - r, cy - r, 2 * r, 2 * r));
      break;

    case 'circle':
    default:
      path.addArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r), 0, math.pi * 2);
      break;
  }
  return path;
}

/// 独立形状路径（beginPath + closePath 的版本）
Path shapePath(
  String type,
  double cx,
  double cy,
  double r,
  Map<String, double> params,
) {
  final p = shapePathTo(Path(), type, cx, cy, r, params);
  p.close();
  return p;
}

/// 把"形状之外"的区域合成一条 evenodd 路径（画遮罩用）
Path outsideShapePath(
  String type,
  double cx,
  double cy,
  double r,
  Map<String, double> params,
  Rect box,
) {
  final p = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(box);
  shapePathTo(p, type, cx, cy, r, params);
  p.close();
  return p;
}

Offset polarAt(double cx, double cy, double r, double k, double deg) {
  final a = rad(deg);
  return Offset(cx + r * k * math.cos(a), cy + r * k * math.sin(a));
}
