import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/px.dart';

/// 占位头像：干净的剪影，一眼看出"这里放你的照片"。
///
/// 关键约束：不能铺满整块画布。铺满的话模板自己的背景与配色全被盖住，
/// 首页 60 张卡片会长得一模一样。所以只画半透明剪影 + 中性细描边。
const List<Color> _tints = [
  Color(0x9EFFFFFF),
  Color(0xA8FFFFF7),
  Color(0xA8F7FCFF),
  Color(0xA3FAFFF9),
  Color(0xA8FDFAFF),
  Color(0xA3F7FEFF),
];

const List<Color> _darkTints = [
  Color(0x2B5A5650),
  Color(0x2E60584E),
  Color(0x2B545860),
  Color(0x2E5C5A52),
  Color(0x2B5E565E),
  Color(0x2E545C5C),
];

/// 一条连续外轮廓：左肩 → 左颈 → 绕头（不过下巴）→ 右颈 → 右肩。
Path _silhouette(double L) {
  final cx = L / 2;
  final headR = L * 0.118;
  final headY = L * 0.415;
  final neckHalf = L * 0.052;
  final neckY = headY + math.sqrt(headR * headR - neckHalf * neckHalf);
  final halfW = L * 0.265;
  final topY = L * 0.625;
  final corner = L * 0.15;

  final dy = neckY - headY;
  final a1 = math.atan2(dy, -neckHalf);
  final a2 = math.atan2(dy, neckHalf) + math.pi * 2;

  final p = Path()
    ..moveTo(cx - halfW, L * 1.04)
    ..lineTo(cx - halfW, topY + corner)
    ..quadraticBezierTo(cx - halfW, topY, cx - halfW + corner, topY)
    ..lineTo(cx - neckHalf, topY)
    ..lineTo(cx - neckHalf, neckY);
  p.arcTo(Rect.fromCircle(center: Offset(cx, headY), radius: headR), a1,
      a2 - a1, false);
  p
    ..lineTo(cx + neckHalf, topY)
    ..lineTo(cx + halfW - corner, topY)
    ..quadraticBezierTo(cx + halfW, topY, cx + halfW, topY + corner)
    ..lineTo(cx + halfW, L * 1.04)
    ..close();
  return p;
}

void drawPlaceholder(Pc c, double L, int idx, bool dark, double scale) {
  final i = idx % _tints.length;
  final tint = dark ? _tints[i] : _darkTints[i];
  final edge =
      dark ? const Color(0x1F000000) : const Color(0x8CFFFFFF);
  final k = scale;

  c.save();

  // 心形、星形这类形状的可用区域比圆小一圈，剪影按原尺寸画会被切掉头顶
  if ((k - 1).abs() > 0.0001) {
    c.translate(L / 2, L * 0.5);
    c.scale(k);
    c.translate(-L / 2, -L * 0.5);
  }

  // 头部区域一层很淡的高光，让剪影在花纹底上也能看清
  c.fillRect(
    Rect.fromLTWH(0, 0, L, L),
    shader: radialShader(
      Offset(L / 2, L * 0.44),
      0,
      Offset(L / 2, L * 0.44),
      L * 0.34,
      [
        (dark ? const Color(0x29FFFFFF) : const Color(0x1AFFFFFF), 0),
        (const Color(0x00FFFFFF), 1),
      ],
    ),
  );

  final path = _silhouette(L);
  c.fillPath(path, color: tint);
  c.strokePath(path,
      color: edge, width: math.max(1, L * 0.0028), cap: StrokeCap.butt);

  c.restore();
}
